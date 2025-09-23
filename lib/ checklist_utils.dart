import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ChecklistUtils {
  static const String _listsKey = 'checklist_lists_v1';
  static const String _itemsKey = 'checklist_items_v1';
  static const String _reportsKey = 'checklist_reports_v1';
  static const String baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';

  static Future<ChecklistData?> getChecklistDataById(String checklistId, String username) async {
    try {
      // Try to load from local storage first
      final localData = await _loadLocalChecklistData(checklistId);
      if (localData != null) return localData;

      // If not found locally, fetch from server
      return await _fetchChecklistDataFromServer(checklistId, username);
    } catch (e) {
      print('Error getting checklist data: $e');
      return null;
    }
  }

  static Future<ChecklistData?> _loadLocalChecklistData(String checklistId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load checklists
      final listsJson = prefs.getStringList(_listsKey) ?? [];
      final checklists = listsJson.map((s) {
        final map = json.decode(s) as Map<String, dynamic>;
        return ChecklistListModel.fromMap(map);
      }).toList();

      final checklist = checklists.where((c) => c.checklistId == checklistId).firstOrNull;
      if (checklist == null) return null;

      // Load items
      final itemsJson = prefs.getStringList(_itemsKey) ?? [];
      final allItems = itemsJson.map((s) {
        final map = json.decode(s) as Map<String, dynamic>;
        return ChecklistItemModel.fromMap(map);
      }).toList();

      // Filter items for this checklist
      final items = _getItemsForChecklist(checklist, allItems);

      // Load reports
      final reportsJson = prefs.getStringList(_reportsKey) ?? [];
      final allReports = reportsJson.map((s) {
        final map = json.decode(s) as Map<String, dynamic>;
        return ChecklistReportModel.fromMap(map);
      }).toList();

      // Filter reports for this checklist
      final reports = allReports.where((r) => r.checklistId == checklistId).toList();

      return ChecklistData(
        checklist: checklist,
        items: items,
        reports: reports,
      );
    } catch (e) {
      print('Error loading local checklist data: $e');
      return null;
    }
  }

  static Future<ChecklistData?> _fetchChecklistDataFromServer(String checklistId, String username) async {
    try {
      // Fetch checklist
      final checklistResponse = await http.get(
        Uri.parse('$baseUrl/checklistlist/$username'),
      );
      if (checklistResponse.statusCode != 200) return null;

      final checklistsJson = json.decode(checklistResponse.body) as List<dynamic>;
      final checklists = checklistsJson.map((e) => ChecklistListModel.fromMap(e)).toList();
      final checklist = checklists.where((c) => c.checklistId == checklistId).firstOrNull;
      if (checklist == null) return null;

      // Fetch items
      final itemsResponse = await http.get(
        Uri.parse('$baseUrl/checklistitem/$username'),
      );
      if (itemsResponse.statusCode != 200) return null;

      final itemsJson = json.decode(itemsResponse.body) as List<dynamic>;
      final allItems = itemsJson.map((e) => ChecklistItemModel.fromMap(e)).toList();
      final items = _getItemsForChecklist(checklist, allItems);

      // Fetch reports
      final reportsResponse = await http.get(
        Uri.parse('$baseUrl/checklistreport/$username'),
      );
      if (reportsResponse.statusCode != 200) return null;

      final reportsJson = json.decode(reportsResponse.body) as List<dynamic>;
      final allReports = reportsJson.map((e) => ChecklistReportModel.fromMap(e)).toList();
      final reports = allReports.where((r) => r.checklistId == checklistId).toList();

      return ChecklistData(
        checklist: checklist,
        items: items,
        reports: reports,
      );
    } catch (e) {
      print('Error fetching checklist data from server: $e');
      return null;
    }
  }

  static List<ChecklistItemModel> _getItemsForChecklist(
    ChecklistListModel checklist,
    List<ChecklistItemModel> allItems,
  ) {
    if (checklist.checklistTaskList == null || checklist.checklistTaskList!.isEmpty) {
      return [];
    }
    
    final itemIds = checklist.checklistTaskList!.split('/');
    return allItems.where((item) => itemIds.contains(item.itemId)).toList();
  }

  // Convenience methods for quick access
  static Future<void> showChecklistPreview(
    BuildContext context,
    String checklistId,
    String username, {
    DateTime? selectedStartDate,
    DateTime? selectedEndDate,
    bool useBlankDate = false,
  }) async {
    final data = await getChecklistDataById(checklistId, username);
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy checklist'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChecklistPreviewScreen(
          checklist: data.checklist,
          items: data.items,
          reports: data.reports,
          username: username,
          selectedStartDate: selectedStartDate,
          selectedEndDate: selectedEndDate,
          useBlankDate: useBlankDate,
        ),
      ),
    );
  }

  static Future<void> generatePDFById(
    String checklistId,
    String username, {
    DateTime? selectedStartDate,
    DateTime? selectedEndDate,
    bool useBlankDate = false,
  }) async {
    final data = await getChecklistDataById(checklistId, username);
    if (data == null) {
      throw Exception('Không tìm thấy checklist với ID: $checklistId');
    }

    await ChecklistService.generateAndSharePDF(
      checklist: data.checklist,
      items: data.items,
      reports: data.reports,
      username: username,
      selectedStartDate: selectedStartDate,
      selectedEndDate: selectedEndDate,
      useBlankDate: useBlankDate,
    );
  }
}

class ChecklistData {
  final ChecklistListModel checklist;
  final List<ChecklistItemModel> items;
  final List<ChecklistReportModel> reports;

  ChecklistData({
    required this.checklist,
    required this.items,
    required this.reports,
  });
}

extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}