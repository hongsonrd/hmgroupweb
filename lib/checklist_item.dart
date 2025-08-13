import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChecklistItemScreen extends StatefulWidget {
 final String username;

 const ChecklistItemScreen({
   Key? key,
   required this.username,
 }) : super(key: key);

 @override
 _ChecklistItemScreenState createState() => _ChecklistItemScreenState();
}

class _ChecklistItemScreenState extends State<ChecklistItemScreen> {
 bool _isLoading = false;
 String _syncStatus = '';
 bool _isGridView = false;
 
 List<ChecklistItemModel> _items = [];
 List<ChecklistItemModel> _filteredItems = [];
 
 final TextEditingController _searchController = TextEditingController();
 final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
 
 static const String _itemsKey = 'checklist_items_v1';
 static const String _lastSyncKey = 'checklist_items_last_sync';

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
   _searchController.addListener(_filterItems);
 }

 @override
 void dispose() {
   _searchController.dispose();
   super.dispose();
 }

 Future<void> _initializeData() async {
   await _checkAndSyncItems();
 }

 Future<void> _checkAndSyncItems() async {
   final prefs = await SharedPreferences.getInstance();
   final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
   final now = DateTime.now().millisecondsSinceEpoch;
   
   final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSync);
   final today = DateTime.now();
   final isNewDay = lastSyncDate.day != today.day || 
                    lastSyncDate.month != today.month || 
                    lastSyncDate.year != today.year;
   
   if (lastSync == 0 || isNewDay) {
     await _syncItems();
   } else {
     await _loadLocalItems();
   }
 }

 Future<void> _syncItems() async {
   if (_isLoading) return;

   setState(() {
     _isLoading = true;
     _syncStatus = 'Đang đồng bộ danh sách items...';
   });

   try {
     final response = await http.get(
       Uri.parse('$baseUrl/checklistitem/${widget.username}'),
     );

     if (response.statusCode == 200) {
       final List<dynamic> data = json.decode(response.body);
       final items = data.map((item) => ChecklistItemModel.fromMap(item)).toList();
       
       await _saveItemsLocally(items);
       
       final prefs = await SharedPreferences.getInstance();
       await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
       
       setState(() {
         _items = items;
         _filteredItems = items;
       });
       
       _showSuccess('Đồng bộ thành công - ${items.length} items');
     } else {
       throw Exception('Failed to sync items: ${response.statusCode}');
     }
   } catch (e) {
     print('Error syncing items: $e');
     _showError('Không thể đồng bộ items: ${e.toString()}');
     await _loadLocalItems();
   } finally {
     setState(() {
       _isLoading = false;
       _syncStatus = '';
     });
   }
 }

 Future<void> _saveItemsLocally(List<ChecklistItemModel> items) async {
   try {
     final prefs = await SharedPreferences.getInstance();
     final jsonList = items.map((item) => json.encode(item.toMap())).toList();
     await prefs.setStringList(_itemsKey, jsonList);
   } catch (e) {
     print('Error saving items locally: $e');
   }
 }

 Future<void> _loadLocalItems() async {
   try {
     final prefs = await SharedPreferences.getInstance();
     final jsonList = prefs.getStringList(_itemsKey) ?? [];
     
     final items = jsonList.map((jsonStr) {
       final map = json.decode(jsonStr) as Map<String, dynamic>;
       return ChecklistItemModel.fromMap(map);
     }).toList();

     setState(() {
       _items = items;
       _filteredItems = items;
     });
   } catch (e) {
     print('Error loading local items: $e');
     setState(() {
       _items = [];
       _filteredItems = [];
     });
   }
 }

 void _filterItems() {
   final query = _searchController.text.toLowerCase();
   setState(() {
     if (query.isEmpty) {
       _filteredItems = _items;
     } else {
       _filteredItems = _items.where((item) {
         return item.itemName?.toLowerCase().contains(query) ?? false;
       }).toList();
     }
   });
 }

 void _toggleViewMode() {
   setState(() {
     _isGridView = !_isGridView;
   });
 }

 Widget _getItemIcon(ChecklistItemModel item) {
   if (item.itemImage != null && item.itemImage!.isNotEmpty) {
     return ClipRRect(
       borderRadius: BorderRadius.circular(8),
       child: Image.asset(
         'assets/checklist/${item.itemImage}',
         width: 40,
         height: 40,
         fit: BoxFit.cover,
         errorBuilder: (context, error, stackTrace) {
           return _getIconFromString(item.itemIcon);
         },
       ),
     );
   } else {
     return _getIconFromString(item.itemIcon);
   }
 }

 Widget _getIconFromString(String? iconString) {
   if (iconString == null || iconString.isEmpty) {
     return Container(
       width: 40,
       height: 40,
       decoration: BoxDecoration(
         color: Colors.grey[200],
         borderRadius: BorderRadius.circular(8),
       ),
       child: Icon(
         Icons.check_box_outlined,
         color: Colors.grey[600],
         size: 24,
       ),
     );
   }

   IconData iconData = _iconMap[iconString] ?? Icons.help_outline;
   
   return Container(
     width: 40,
     height: 40,
     decoration: BoxDecoration(
       color: Colors.blue[100],
       borderRadius: BorderRadius.circular(8),
     ),
     child: Icon(
       iconData,
       color: Colors.blue[600],
       size: 24,
     ),
   );
 }

 void _showSuccess(String message) {
   if (mounted) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text(message),
         backgroundColor: Colors.green,
         duration: Duration(seconds: 2),
       ),
     );
   }
 }

 void _showError(String message) {
   if (mounted) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text(message),
         backgroundColor: Colors.red,
         duration: Duration(seconds: 3),
       ),
     );
   }
 }

 Widget _buildHeader() {
   final isMobile = MediaQuery.of(context).size.width < 600;
   
   return Container(
     padding: EdgeInsets.symmetric(
       horizontal: isMobile ? 16 : 24, 
       vertical: isMobile ? 12 : 16
     ),
     decoration: BoxDecoration(
       gradient: LinearGradient(
         begin: Alignment.topLeft,
         end: Alignment.bottomRight,
         colors: [
           Color.fromARGB(255, 33, 150, 243),
           Color.fromARGB(255, 100, 181, 246),
           Color.fromARGB(255, 66, 165, 245),
           Color.fromARGB(255, 144, 202, 249),
         ],
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
               constraints: BoxConstraints(),
             ),
             SizedBox(width: isMobile ? 12 : 16),
             Expanded(
               child: Text(
                 'Checklist Items',
                 style: TextStyle(
                   fontSize: isMobile ? 20 : 24,
                   fontWeight: FontWeight.bold,
                   color: Colors.white,
                 ),
               ),
             ),
             if (_isLoading)
               SizedBox(
                 width: 20,
                 height: 20,
                 child: CircularProgressIndicator(
                   strokeWidth: 2,
                   valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                 ),
               ),
           ],
         ),
         if (!_isLoading)
           Container(
             margin: EdgeInsets.only(top: isMobile ? 12 : 16),
             height: isMobile ? 36 : 40,
             child: Row(
               children: [
                 Expanded(
                   child: ElevatedButton.icon(
                     onPressed: () => _syncItems(),
                     icon: Icon(Icons.sync, size: isMobile ? 16 : 18),
                     label: Text(
                       'Đồng bộ',
                       style: TextStyle(fontSize: isMobile ? 12 : 14),
                     ),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.white,
                       foregroundColor: Colors.blue[700],
                       elevation: 2,
                       padding: EdgeInsets.symmetric(
                         horizontal: isMobile ? 12 : 16,
                         vertical: isMobile ? 8 : 12,
                       ),
                     ),
                   ),
                 ),
                 SizedBox(width: 8),
                 ElevatedButton.icon(
                   onPressed: _toggleViewMode,
                   icon: Icon(
                     _isGridView ? Icons.view_list : Icons.grid_view,
                     size: isMobile ? 16 : 18,
                   ),
                   label: Text(
                     _isGridView ? 'List' : 'Grid',
                     style: TextStyle(fontSize: isMobile ? 12 : 14),
                   ),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.white,
                     foregroundColor: Colors.blue[700],
                     elevation: 2,
                     padding: EdgeInsets.symmetric(
                       horizontal: isMobile ? 8 : 12,
                       vertical: isMobile ? 8 : 12,
                     ),
                   ),
                 ),
               ],
             ),
           ),
         if (_isLoading && _syncStatus.isNotEmpty)
           Container(
             margin: EdgeInsets.only(top: 8),
             child: Text(
               _syncStatus,
               style: TextStyle(
                 color: Colors.white,
                 fontWeight: FontWeight.w500,
                 fontSize: isMobile ? 12 : 14,
               ),
               textAlign: TextAlign.center,
             ),
           ),
       ],
     ),
   );
 }

 Widget _buildSearchBar() {
   final isMobile = MediaQuery.of(context).size.width < 600;
   
   return Container(
     padding: EdgeInsets.all(isMobile ? 12 : 16),
     decoration: BoxDecoration(
       color: Colors.white,
       boxShadow: [
         BoxShadow(
           color: Colors.grey.withOpacity(0.1),
           spreadRadius: 1,
           blurRadius: 3,
           offset: Offset(0, 2),
         ),
       ],
     ),
     child: Row(
       children: [
         Expanded(
           child: TextField(
             controller: _searchController,
             decoration: InputDecoration(
               hintText: 'Tìm kiếm items...',
               prefixIcon: Icon(Icons.search),
               border: OutlineInputBorder(
                 borderRadius: BorderRadius.circular(8),
               ),
               contentPadding: EdgeInsets.symmetric(
                 horizontal: 12,
                 vertical: isMobile ? 12 : 8,
               ),
             ),
           ),
         ),
         SizedBox(width: 12),
         Container(
           padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
           decoration: BoxDecoration(
             color: Colors.blue[50],
             borderRadius: BorderRadius.circular(8),
             border: Border.all(color: Colors.blue[200]!),
           ),
           child: Text(
             '${_filteredItems.length} items',
             style: TextStyle(
               fontSize: isMobile ? 12 : 14,
               fontWeight: FontWeight.w500,
               color: Colors.blue[700],
             ),
           ),
         ),
       ],
     ),
   );
 }

 Widget _buildListView() {
   final isMobile = MediaQuery.of(context).size.width < 600;
   
   return ListView.builder(
     padding: EdgeInsets.all(isMobile ? 12 : 16),
     itemCount: _filteredItems.length,
     itemBuilder: (context, index) {
       final item = _filteredItems[index];
       
       return Card(
         margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
         elevation: 2,
         child: ListTile(
           contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
           leading: _getItemIcon(item),
           title: Text(
             item.itemName ?? 'Unnamed Item',
             style: TextStyle(
               fontSize: isMobile ? 14 : 16,
               fontWeight: FontWeight.w500,
             ),
           ),
           subtitle: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               SizedBox(height: 4),
               Text(
                 'ID: ${item.itemId}',
                 style: TextStyle(
                   fontSize: isMobile ? 11 : 12,
                   color: Colors.grey[600],
                 ),
               ),
               if (item.itemImage != null && item.itemImage!.isNotEmpty)
                 Text(
                   'Image: ${item.itemImage}',
                   style: TextStyle(
                     fontSize: isMobile ? 10 : 11,
                     color: Colors.blue[600],
                     fontStyle: FontStyle.italic,
                   ),
                 ),
               if (item.itemIcon != null && item.itemIcon!.isNotEmpty)
                 Text(
                   'Icon: ${item.itemIcon}',
                   style: TextStyle(
                     fontSize: isMobile ? 10 : 11,
                     color: Colors.green[600],
                     fontStyle: FontStyle.italic,
                   ),
                 ),
             ],
           ),
           trailing: Icon(
             Icons.chevron_right,
             color: Colors.grey[400],
           ),
           onTap: () {
             _showItemDetails(item);
           },
         ),
       );
     },
   );
 }

 Widget _buildGridView() {
   final isMobile = MediaQuery.of(context).size.width < 600;
   final crossAxisCount = isMobile ? 2 : 4;
   
   return GridView.builder(
     padding: EdgeInsets.all(isMobile ? 12 : 16),
     gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
       crossAxisCount: crossAxisCount,
       crossAxisSpacing: isMobile ? 8 : 12,
       mainAxisSpacing: isMobile ? 8 : 12,
       childAspectRatio: isMobile ? 0.8 : 0.9,
     ),
     itemCount: _filteredItems.length,
     itemBuilder: (context, index) {
       final item = _filteredItems[index];
       
       return Card(
         elevation: 2,
         child: InkWell(
           onTap: () => _showItemDetails(item),
           borderRadius: BorderRadius.circular(8),
           child: Padding(
             padding: EdgeInsets.all(isMobile ? 8 : 12),
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Container(
                   width: isMobile ? 50 : 60,
                   height: isMobile ? 50 : 60,
                   child: item.itemImage != null && item.itemImage!.isNotEmpty
                       ? ClipRRect(
                           borderRadius: BorderRadius.circular(8),
                           child: Image.asset(
                             'assets/checklist/${item.itemImage}',
                             fit: BoxFit.cover,
                             errorBuilder: (context, error, stackTrace) {
                               return _getIconFromString(item.itemIcon);
                             },
                           ),
                         )
                       : _getIconFromString(item.itemIcon),
                 ),
                 SizedBox(height: 8),
                 Text(
                   item.itemName ?? 'Unnamed',
                   style: TextStyle(
                     fontSize: isMobile ? 12 : 14,
                     fontWeight: FontWeight.w500,
                   ),
                   textAlign: TextAlign.center,
                   maxLines: 2,
                   overflow: TextOverflow.ellipsis,
                 ),
                 SizedBox(height: 4),
                 Text(
                   item.itemId,
                   style: TextStyle(
                     fontSize: isMobile ? 10 : 11,
                     color: Colors.grey[600],
                   ),
                   textAlign: TextAlign.center,
                   maxLines: 1,
                   overflow: TextOverflow.ellipsis,
                 ),
               ],
             ),
           ),
         ),
       );
     },
   );
 }

 void _showItemDetails(ChecklistItemModel item) {
   final isMobile = MediaQuery.of(context).size.width < 600;
   
   showDialog(
     context: context,
     builder: (context) => Dialog(
       child: Container(
         width: isMobile ? MediaQuery.of(context).size.width * 0.9 : 400,
         padding: EdgeInsets.all(isMobile ? 16 : 20),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             Row(
               children: [
                 Container(
                   width: 40,
                   height: 40,
                   child: item.itemImage != null && item.itemImage!.isNotEmpty
                       ? ClipRRect(
                           borderRadius: BorderRadius.circular(8),
                           child: Image.asset(
                             'assets/checklist/${item.itemImage}',
                             fit: BoxFit.cover,
                             errorBuilder: (context, error, stackTrace) {
                               return Container(
                                 decoration: BoxDecoration(
                                   color: Colors.blue[100],
                                   borderRadius: BorderRadius.circular(8),
                                 ),
                                 child: Icon(
                                   _iconMap[item.itemIcon ?? ''] ?? Icons.help_outline,
                                   color: Colors.blue[600],
                                   size: 24,
                                 ),
                               );
                             },
                           ),
                         )
                       : Container(
                           decoration: BoxDecoration(
                             color: Colors.blue[100],
                             borderRadius: BorderRadius.circular(8),
                           ),
                           child: Icon(
                             _iconMap[item.itemIcon ?? ''] ?? Icons.help_outline,
                             color: Colors.blue[600],
                             size: 24,
                           ),
                         ),
                 ),
                 SizedBox(width: 12),
                 Expanded(
                   child: Text(
                     item.itemName ?? 'Unnamed Item',
                     style: TextStyle(
                       fontSize: isMobile ? 16 : 18,
                       fontWeight: FontWeight.bold,
                     ),
                   ),
                 ),
                 IconButton(
                   icon: Icon(Icons.close),
                   onPressed: () => Navigator.of(context).pop(),
                 ),
               ],
             ),
             SizedBox(height: 16),
             if (item.itemImage != null && item.itemImage!.isNotEmpty)
               Container(
                 margin: EdgeInsets.only(bottom: 16),
                 child: ClipRRect(
                   borderRadius: BorderRadius.circular(8),
                   child: Image.asset(
                     'assets/checklist/${item.itemImage}',
                     width: 80,
                     height: 80,
                     fit: BoxFit.cover,
                     errorBuilder: (context, error, stackTrace) {
                       return Container(
                         width: 80,
                         height: 80,
                         decoration: BoxDecoration(
                           color: Colors.grey[200],
                           borderRadius: BorderRadius.circular(8),
                         ),
                         child: Icon(
                           Icons.broken_image,
                           color: Colors.grey[600],
                           size: 40,
                         ),
                       );
                     },
                   ),
                 ),
               ),
             _buildDetailRow('Item ID', item.itemId, isMobile),
             _buildDetailRow('Item Name', item.itemName ?? 'N/A', isMobile),
             _buildDetailRow('Image File', item.itemImage ?? 'N/A', isMobile),
             _buildDetailRow('Icon', item.itemIcon ?? 'N/A', isMobile),
             SizedBox(height: 16),
             SizedBox(
               width: double.infinity,
               child: ElevatedButton(
                 onPressed: () => Navigator.of(context).pop(),
                 child: Text('Đóng'),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.blue[600],
                   foregroundColor: Colors.white,
                   padding: EdgeInsets.symmetric(vertical: 12),
                 ),
               ),
             ),
           ],
         ),
       ),
     ),
   );
 }

 Widget _buildDetailRow(String label, String value, bool isMobile) {
   return Padding(
     padding: EdgeInsets.only(bottom: 8),
     child: Row(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         SizedBox(
           width: isMobile ? 80 : 100,
           child: Text(
             '$label:',
             style: TextStyle(
               fontSize: isMobile ? 12 : 14,
               fontWeight: FontWeight.w500,
               color: Colors.grey[700],
             ),
           ),
         ),
         Expanded(
           child: Text(
             value,
             style: TextStyle(
               fontSize: isMobile ? 12 : 14,
               color: Colors.grey[800],
             ),
           ),
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
           _buildSearchBar(),
           Expanded(
             child: _filteredItems.isEmpty
                 ? Center(
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Icon(
                           Icons.check_box_outlined,
                           size: 64,
                           color: Colors.grey[400],
                         ),
                         SizedBox(height: 16),
                         Text(
                           _isLoading ? 'Đang tải...' : 'Không có items nào',
                           style: TextStyle(
                             fontSize: 16,
                             color: Colors.grey[600],
                           ),
                         ),
                       ],
                     ),
                   )
                 : _isGridView
                     ? _buildGridView()
                     : _buildListView(),
           ),
         ],
       ),
     ),
   );
 }
}

class ChecklistItemModel {
 final String itemId;
 final String? itemName;
 final String? itemImage;
 final String? itemIcon;

 ChecklistItemModel({
   required this.itemId,
   this.itemName,
   this.itemImage,
   this.itemIcon,
 });

 Map<String, dynamic> toMap() {
   return {
     'itemId': itemId,
     'itemName': itemName,
     'itemImage': itemImage,
     'itemIcon': itemIcon,
   };
 }

 factory ChecklistItemModel.fromMap(Map<String, dynamic> map) {
   return ChecklistItemModel(
     itemId: map['itemId'] ?? '',
     itemName: map['itemName'],
     itemImage: map['itemImage'],
     itemIcon: map['itemIcon'],
   );
 }
}