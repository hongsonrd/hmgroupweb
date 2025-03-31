import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';
import 'http_client.dart';

class CurrencyInputFormatter extends TextInputFormatter {
 @override
 TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
   if (newValue.text.isEmpty) {
     return newValue;
   }
   
   String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d\-]'), '');
   
   if (digitsOnly.startsWith('-')) {
     digitsOnly = '-' + digitsOnly.substring(1).replaceAll('-', '');
   }
   
   if (digitsOnly.isNotEmpty) {
     int? value = int.tryParse(digitsOnly);
     if (value != null) {
       final formatter = NumberFormat('#,###', 'vi_VN');
       digitsOnly = formatter.format(value);
     }
   }
   
   return TextEditingValue(
     text: digitsOnly,
     selection: TextSelection.collapsed(offset: digitsOnly.length),
   );
 }
}

class ProjectWorkerPC extends StatefulWidget {
 final String username;
 
 const ProjectWorkerPC({
   Key? key, 
   required this.username,
 }) : super(key: key);
 
 @override
 _ProjectWorkerPCState createState() => _ProjectWorkerPCState();
}

class _ProjectWorkerPCState extends State<ProjectWorkerPC> {
 bool _isLoading = false;
 List<String> _projects = [];
 String? _selectedProject;
 String? _selectedPeriod;
 List<String> _availablePeriods = [];
 List<Map<String, dynamic>> _allowanceData = [];
 Map<String, String> _staffNames = {};
 DateTime? _lastSyncTime;
 bool _hasUnsavedChanges = false;
 List<Map<String, dynamic>> _modifiedRecords = [];
 Map<String, TextEditingController> _controllers = {};
 
 @override
 void initState() {
   super.initState();
   _initializeData();
 }
 
 @override
 void dispose() {
   _controllers.values.forEach((controller) => controller.dispose());
   super.dispose();
 }

 void safeSetState(VoidCallback fn) {
   if (mounted) setState(fn);
 }
 
 Future<void> _initializeData() async {
   safeSetState(() => _isLoading = true);
   try {
     try {
       final response = await AuthenticatedHttpClient.get(
         Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/projectgs/${widget.username}'),
         headers: {'Content-Type': 'application/json'},
       );
       
       if (response.statusCode == 200) {
         final List<dynamic> apiProjects = json.decode(response.body);
         safeSetState(() {
           _projects = apiProjects.map((e) => e.toString()).toList();
           if (_projects.isNotEmpty) {
             _selectedProject = _projects.first;
           }
         });
       }
     } catch (e) {
       print('Project API error: $e');
       _showError('Không thể tải dữ liệu dự án');
     }
     
     final now = DateTime.now();
     List<String> periods = [];
     for (int i = 0; i < 12; i++) {
       final date = DateTime(now.year, now.month - i, 1);
       periods.add(DateFormat('yyyy-MM').format(date));
     }
     
     safeSetState(() {
       _availablePeriods = periods;
       _selectedPeriod = periods.first;
     });
     
     await _loadAllowanceData();
     
   } catch (e) {
     print('Init error: $e');
     _showError('Không thể tải dữ liệu');
   }
   safeSetState(() => _isLoading = false);
 }
 
 TextEditingController _getController(String uid, String field, dynamic value) {
   final key = "$uid-$field";
   if (!_controllers.containsKey(key)) {
     String initialValue = '0';
     if (value != null) {
       initialValue = value.toString();
     }
     
     final controller = TextEditingController(text: initialValue);
     _controllers[key] = controller;
   }
   
   return _controllers[key]!;
 }
 
 void _clearControllers() {
   _controllers.values.forEach((controller) => controller.dispose());
   _controllers.clear();
 }
 
 Future<void> _loadAllowanceData() async {
  if (_selectedProject == null || _selectedPeriod == null) return;
  
  safeSetState(() => _isLoading = true);
  
  try {
    final dbHelper = DBHelper();
    
    // First check if the table exists
    final tableExists = await dbHelper.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='ChamCongCNThang'"
    );
    
    if (tableExists.isEmpty) {
      print('Table ChamCongCNThang does not exist!');
      _showError('Bảng dữ liệu ChamCongCNThang không tồn tại');
      safeSetState(() => _isLoading = false);
      return;
    }
    
    // Query data for selected project and period
    final query = '''
      SELECT * 
      FROM ChamCongCNThang 
      WHERE BoPhan = ? AND strftime('%Y-%m', GiaiDoan) = ?
      ORDER BY MaNV
    ''';
    
    final queryResult = await dbHelper.rawQuery(query, [_selectedProject, _selectedPeriod]);
    
    // Convert query results to mutable maps
    final mutableData = queryResult.map((row) => Map<String, dynamic>.from(row)).toList();
    
    print('Query returned ${mutableData.length} rows');
    
    // Load staff names
    await _loadStaffNames(mutableData.map((e) => e['MaNV'] as String).toSet().toList());
    
    _clearControllers();
    
    safeSetState(() {
      _allowanceData = mutableData;
      _modifiedRecords = [];
      _hasUnsavedChanges = false;
    });
  } catch (e) {
    print('Error loading allowance data: $e');
    _showError('Không thể tải dữ liệu phụ cấp: $e');
  }
  
  safeSetState(() => _isLoading = false);
}

 Future<void> _loadStaffNames(List<String> employeeIds) async {
   if (employeeIds.isEmpty) return;
   
   final dbHelper = DBHelper();
   final placeholders = List.filled(employeeIds.length, '?').join(',');
   final result = await dbHelper.rawQuery(
     'SELECT MaNV, Ho_ten FROM staffbio WHERE MaNV IN ($placeholders)',
     employeeIds,
   );

   final Map<String, String> fetchedNames = {
     for (var row in result) row['MaNV'] as String: row['Ho_ten'] as String
   };

   final Map<String, String> staffNames = {
     for (var id in employeeIds) id: fetchedNames[id] ?? "???"
   };

   safeSetState(() {
     _staffNames = staffNames;
   });
 }
 
 Future<void> _syncData({bool silent = false}) async {
   bool proceed = silent;
   
   if (!silent) {
     proceed = await showDialog<bool>(
       context: context,
       builder: (BuildContext context) {
         return AlertDialog(
           title: Text('Đồng bộ dữ liệu'),
           content: Text(
             'Quá trình này sẽ đồng bộ toàn bộ dữ liệu tổng hợp chấm công từ máy chủ. '
             'Tiếp tục?'
           ),
           actions: [
             TextButton(
               onPressed: () => Navigator.of(context).pop(false),
               child: Text('Hủy'),
             ),
             TextButton(
               onPressed: () => Navigator.of(context).pop(true),
               child: Text('Tiếp tục'),
             ),
           ],
         );
       },
     ) ?? false;
   }
   
   if (!proceed) return;
   
   if (!silent) {
     safeSetState(() => _isLoading = true);
   }
   
   try {
     final response = await AuthenticatedHttpClient.get(
       Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongcnthangfull'),
       headers: {'Content-Type': 'application/json'},
     );
     
     if (response.statusCode == 200) {
       final data = json.decode(response.body);
       
       final dbHelper = DBHelper();
       
       final db = await dbHelper.database;
       await db.transaction((txn) async {
         final batch = txn.batch();
         
         batch.execute('DELETE FROM ChamCongCNThang');
         
         for (var item in data) {
           final modifiedItem = Map<String, dynamic>.from(item);
           
           if (modifiedItem.containsKey('Tuan_1va2')) modifiedItem['Tuan1va2'] = modifiedItem.remove('Tuan_1va2');
           if (modifiedItem.containsKey('Phep_1va2')) modifiedItem['Phep1va2'] = modifiedItem.remove('Phep_1va2');
           if (modifiedItem.containsKey('HT_1va2')) modifiedItem['HT1va2'] = modifiedItem.remove('HT_1va2');
           if (modifiedItem.containsKey('Tuan_3va4')) modifiedItem['Tuan3va4'] = modifiedItem.remove('Tuan_3va4');
           if (modifiedItem.containsKey('Phep_3va4')) modifiedItem['Phep3va4'] = modifiedItem.remove('Phep_3va4');
           if (modifiedItem.containsKey('HT_3va4')) modifiedItem['HT3va4'] = modifiedItem.remove('HT_3va4');
           
           final model = ChamCongCNThangModel.fromMap(modifiedItem);
           batch.insert(
             'ChamCongCNThang', 
             model.toMap(),
             conflictAlgorithm: ConflictAlgorithm.replace
           );
         }
         
         await batch.commit(noResult: true);
       });
       
       if (!silent) {
         safeSetState(() {
           _lastSyncTime = DateTime.now();
           _hasUnsavedChanges = false;
           _modifiedRecords = [];
         });
         
         await _loadAllowanceData();
       } else {
         _lastSyncTime = DateTime.now();
       }
       
       if (!silent) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Đồng bộ dữ liệu thành công'), backgroundColor: Colors.green)
         );
       }
     } else {
       if (!silent) {
         _showError('Lỗi khi đồng bộ dữ liệu: ${response.statusCode}');
       }
     }
   } catch (e) {
     print('Error syncing data: $e');
     if (!silent) {
       _showError('Lỗi khi đồng bộ dữ liệu: $e');
     }
   } finally {
     if (!silent) {
       safeSetState(() => _isLoading = false);
     }
   }
 }

 Future<void> _saveChanges() async {
   FocusScope.of(context).unfocus();
   
   if (_modifiedRecords.isEmpty) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('Không có thay đổi để lưu'))
     );
     return;
   }

   safeSetState(() => _isLoading = true);

   try {
     final dbHelper = DBHelper();
     final db = await dbHelper.database;
     
     await db.transaction((txn) async {
       for (var record in _modifiedRecords) {
         await txn.update(
           'ChamCongCNThang',
           {
             'TruyLinh': record['TruyLinh'],
             'TruyThu': record['TruyThu'],
             'PhanLoaiDacBiet': record['PhanLoaiDacBiet'],
             'NgayCapNhat': DateFormat('yyyy-MM-dd').format(DateTime.now()),
           },
           where: 'UID = ?',
           whereArgs: [record['UID']],
         );
       }
     });

     await _syncUpdatedRecordsWithServer(_modifiedRecords);

     safeSetState(() {
       _hasUnsavedChanges = false;
       _modifiedRecords = [];
     });

     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('Lưu thay đổi thành công'), backgroundColor: Colors.green)
     );
   } catch (e) {
     print('Error saving changes: $e');
     _showError('Lỗi khi lưu thay đổi: $e');
   } finally {
     safeSetState(() => _isLoading = false);
   }
 }

 Future<void> _syncUpdatedRecordsWithServer(List<Map<String, dynamic>> records) async {
   try {
     List<Map<String, dynamic>> serverRecords = records.map((record) {
       Map<String, dynamic> serverRecord = {
         'UID': record['UID'],
         'GiaiDoan': record['GiaiDoan'],
         'MaNV': record['MaNV'],
         'BoPhan': record['BoPhan'],
         'MaBP': record['MaBP'],
         'PhanLoaiDacBiet': record['PhanLoaiDacBiet'],
         'TruyLinh': record['TruyLinh'],
         'TruyThu': record['TruyThu'],
       };
       return serverRecord;
     }).toList();

     final response = await http.post(
       Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongcnthangsua'),
       headers: {'Content-Type': 'application/json'},
       body: json.encode(serverRecords),
     );
     
     if (response.statusCode != 200) {
       print('Server sync error: ${response.statusCode} - ${response.body}');
       _showError('Lỗi khi đồng bộ với máy chủ: ${response.statusCode}');
     }
   } catch (e) {
     print('Error syncing with server: $e');
     _showError('Lỗi khi đồng bộ với máy chủ: $e');
   }
 }
 
 void _showError(String message) {
   if (mounted) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text(message), backgroundColor: Colors.red)
     );
   }
 }

 void _updateRecordValue(int index, String field, dynamic value) {
  if (index < 0 || index >= _allowanceData.length) {
    print('Invalid index: $index');
    return;
  }
  
  // Create a true deep copy of the record
  final originalRecord = _allowanceData[index];
  final record = Map<String, dynamic>.from({});
  
  // Copy all fields from the original record
  originalRecord.forEach((key, val) {
    record[key] = val;
  });
  
  final oldValue = record[field];
  
  bool isEqual;
  if ((oldValue is int || oldValue is double) && (value is int || value is double)) {
    isEqual = oldValue.toString() == value.toString();
  } else {
    isEqual = oldValue == value;
  }
  
  if (isEqual) {
    return;
  }
  
  // Update the value in the copy
  record[field] = value;
  
  setState(() {
    // Replace the record in the data list with the new copy
    _allowanceData[index] = record;
    
    int existingIndex = _modifiedRecords.indexWhere((r) => r['UID'] == record['UID']);
    if (existingIndex >= 0) {
      _modifiedRecords[existingIndex] = record;
    } else {
      _modifiedRecords.add(record);
    }
    
    _hasUnsavedChanges = true;
  });
  
  print('Updated record: field=$field, value=$value, _hasUnsavedChanges=$_hasUnsavedChanges, modified records=${_modifiedRecords.length}');
}
 
 void _handleValueChange(int index, String field, String valueText) {
   try {
     if (field == 'TruyLinh' || field == 'TruyThu') {
       String cleanValue = valueText.replaceAll(RegExp(r'[^\d\-]'), '');
       int parsedValue = cleanValue.isEmpty ? 0 : int.tryParse(cleanValue) ?? 0;
       _updateRecordValue(index, field, parsedValue);
     } else {
       _updateRecordValue(index, field, valueText);
     }
   } catch (e) {
     print('Error parsing value for $field: $e');
   }
 }
 
 @override
 Widget build(BuildContext context) {
   print('Building widget. _hasUnsavedChanges = $_hasUnsavedChanges, _modifiedRecords.length = ${_modifiedRecords.length}');
   return Scaffold(
     appBar: AppBar(
       backgroundColor: Colors.green.shade100,
       title: Text('Phụ cấp công nhân dự án'),
       leading: IconButton(
         icon: Icon(Icons.arrow_back, color: Colors.white),
         onPressed: () {
           if (_hasUnsavedChanges) {
             showDialog(
               context: context,
               builder: (context) => AlertDialog(
                 title: Text('Thay đổi chưa lưu'),
                 content: Text('Bạn có thay đổi chưa lưu. Bạn có muốn lưu lại không?'),
                 actions: [
                   TextButton(
                     onPressed: () {
                       Navigator.of(context).pop();
                       Navigator.of(context).pop();
                     },
                     child: Text('Không lưu'),
                   ),
                   TextButton(
                     onPressed: () async {
                       Navigator.of(context).pop();
                       await _saveChanges();
                       Navigator.of(context).pop();
                     },
                     child: Text('Lưu'),
                   ),
                 ],
               ),
             );
           } else {
             Navigator.of(context).pop();
           }
         },
       ),
       actions: [
         if (_hasUnsavedChanges)
           IconButton(
             icon: Icon(Icons.save),
             tooltip: 'Lưu thay đổi',
             onPressed: _saveChanges,
           ),
       ],
     ),
     body: Stack(
       children: [
         _isLoading 
             ? const Center(child: CircularProgressIndicator()) 
             : Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       children: [
                         Expanded(
                           flex: 3,
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(
                                 'Dự án',
                                 style: TextStyle(
                                   fontSize: 16,
                                   fontWeight: FontWeight.bold,
                                 ),
                               ),
                               SizedBox(height: 8),
                               Container(
                                 decoration: BoxDecoration(
                                   border: Border.all(color: Colors.grey),
                                   borderRadius: BorderRadius.circular(8),
                                 ),
                                 child: DropdownSearch<String>(
                                   items: _projects,
                                   selectedItem: _selectedProject,
                                   onChanged: (value) {
                                     if (_hasUnsavedChanges) {
                                       showDialog(
                                         context: context,
                                         builder: (context) => AlertDialog(
                                           title: Text('Thay đổi chưa lưu'),
                                           content: Text('Bạn có thay đổi chưa lưu. Thay đổi dự án sẽ mất các thay đổi này.'),
                                           actions: [
                                             TextButton(
                                               onPressed: () {
                                                 Navigator.of(context).pop();
                                               },
                                               child: Text('Hủy'),
                                             ),
                                             TextButton(
                                               onPressed: () {
                                                 Navigator.of(context).pop();
                                                 safeSetState(() {
                                                   _selectedProject = value;
                                                   _modifiedRecords = [];
                                                   _hasUnsavedChanges = false;
                                                 });
                                                 _loadAllowanceData();
                                               },
                                               child: Text('Tiếp tục'),
                                             ),
                                           ],
                                         ),
                                       );
                                     } else {
                                       safeSetState(() {
                                         _selectedProject = value;
                                       });
                                       _loadAllowanceData();
                                     }
                                   },
                                   dropdownDecoratorProps: DropDownDecoratorProps(
                                     dropdownSearchDecoration: InputDecoration(
                                       hintText: "Chọn dự án",
                                       border: InputBorder.none,
                                       contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                     ),
                                   ),
                                   popupProps: PopupProps.dialog(
                                     showSearchBox: true,
                                     searchFieldProps: TextFieldProps(
                                       decoration: InputDecoration(
                                         hintText: "Tìm kiếm dự án...",
                                         prefixIcon: Icon(Icons.search),
                                         border: OutlineInputBorder(),
                                       ),
                                     ),
                                     title: Container(
                                       height: 50,
                                       decoration: BoxDecoration(
                                         color: Theme.of(context).primaryColor,
                                         borderRadius: BorderRadius.only(
                                           topLeft: Radius.circular(8),
                                           topRight: Radius.circular(8),
                                         ),
                                       ),
                                       child: Center(
                                         child: Text(
                                           'Chọn dự án',
                                           style: TextStyle(
                                             fontSize: 18,
                                             fontWeight: FontWeight.bold,
                                             color: Colors.white,
                                           ),
                                         ),
                                       ),
                                     ),
                                   ),
                                 ),
                               ),
                             ],
                           ),
                         ),
                         
                         SizedBox(width: 16),
                         
                         Expanded(
                           flex: 2,
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(
                                 'Kỳ',
                                 style: TextStyle(
                                   fontSize: 16,
                                   fontWeight: FontWeight.bold,
                                 ),
                               ),
                               SizedBox(height: 8),
                               Container(
                                 decoration: BoxDecoration(
                                   border: Border.all(color: Colors.grey),
                                   borderRadius: BorderRadius.circular(8),
                                 ),
                                 padding: EdgeInsets.symmetric(horizontal: 16),
                                 child: DropdownButton<String>(
                                   value: _selectedPeriod,
                                   items: _availablePeriods.map((period) => DropdownMenuItem(
                                     value: period,
                                     child: Text(DateFormat('MM/yyyy').format(DateTime.parse('$period-01')))
                                   )).toList(),
                                   onChanged: (value) {
                                     if (_hasUnsavedChanges) {
                                       showDialog(
                                         context: context,
                                         builder: (context) => AlertDialog(
                                           title: Text('Thay đổi chưa lưu'),
                                           content: Text('Bạn có thay đổi chưa lưu. Thay đổi kỳ sẽ mất các thay đổi này.'),
                                           actions: [
                                             TextButton(
                                               onPressed: () {
                                                 Navigator.of(context).pop();
                                               },
                                               child: Text('Hủy'),
                                             ),
                                             TextButton(
                                               onPressed: () {
                                                 Navigator.of(context).pop();
                                                 safeSetState(() {
                                                   _selectedPeriod = value;
                                                   _modifiedRecords = [];
                                                   _hasUnsavedChanges = false;
                                                 });
                                                 _loadAllowanceData();
                                               },
                                               child: Text('Tiếp tục'),
                                             ),
                                           ],
                                         ),
                                       );
                                     } else {
                                       safeSetState(() {
                                         _selectedPeriod = value;
                                       });
                                       _loadAllowanceData();
                                     }
                                   },
                                   isExpanded: true,
                                   underline: SizedBox(),
                                 ),
                               ),
                             ],
                           ),
                         ),
                       ],
                     ),
                     
                     SizedBox(height: 16),
                     
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                       children: [
                         ElevatedButton.icon(
                           onPressed: _syncData,
                           icon: Icon(Icons.sync),
                           label: Text('Đồng bộ dữ liệu'),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.green.shade100,
                             padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                           ),
                         ),
                         
                         ElevatedButton.icon(
                           onPressed: _saveChanges, 
                           icon: Icon(Icons.save),
                           label: Text('Lưu thay đổi'),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.yellow,
                             padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                           ),
                         ),
                       ],
                     ),

                     if (_lastSyncTime != null)
                       Padding(
                         padding: const EdgeInsets.only(top: 8.0),
                         child: Center(
                           child: Text(
                             'Đồng bộ lần cuối: ${DateFormat('dd/MM/yyyy HH:mm').format(_lastSyncTime!)}',
                             style: TextStyle(
                               fontSize: 12,
                               color: Colors.grey[600],
                             ),
                           ),
                         ),
                       ),           
                     SizedBox(height: 24),
                     
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text(
                           'Dữ liệu phụ cấp',
                           style: TextStyle(
                             fontSize: 18,
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                         if (_hasUnsavedChanges)
                           Container(
                             padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                             decoration: BoxDecoration(
                               color: Colors.yellow,
                               borderRadius: BorderRadius.circular(4),
                             ),
                             child: Text(
                               'Có thay đổi chưa lưu',
                               style: TextStyle(
                                 fontWeight: FontWeight.bold,
                                 color: Colors.black87,
                               ),
                             ),
                           ),
                       ],
                     ),
                     
                     SizedBox(height: 8),
                     
                     Container(
                       decoration: BoxDecoration(
                         color: Colors.green.shade100,
                         border: Border.all(color: Colors.grey.shade300),
                       ),
                       child: Row(
                         children: [
                           Expanded(
                             flex: 3,
                             child: Padding(
                               padding: const EdgeInsets.all(8.0),
                               child: Text(
                                 'Mã NV / Tên',
                                 style: TextStyle(fontWeight: FontWeight.bold),
                               ),
                             ),
                           ),
                           Expanded(
                             flex: 2,
                             child: Padding(
                               padding: const EdgeInsets.all(8.0),
                               child: Text(
                                 'Phân loại',
                                 style: TextStyle(fontWeight: FontWeight.bold),
                               ),
                             ),
                           ),
                           Expanded(
                             flex: 2,
                             child: Padding(
                               padding: const EdgeInsets.all(8.0),
                               child: Text(
                                 'Phụ cấp',
                                 style: TextStyle(fontWeight: FontWeight.bold),
                               ),
                             ),
                           ),
                           Expanded(
                             flex: 2,
                             child: Padding(
                               padding: const EdgeInsets.all(8.0),
                               child: Text(
                                 'Trừ',
                                 style: TextStyle(fontWeight: FontWeight.bold),
                               ),
                             ),
                           ),
                         ],
                       ),
                     ),
                     
                     Expanded(
                       child: _allowanceData.isEmpty
                           ? Center(
                               child: Text(
                                 'Không có dữ liệu',
                                 style: TextStyle(
                                   fontSize: 16,
                                   color: Colors.grey[600],
                                 ),
                               ),
                             )
                           : ListView.builder(
                               itemCount: _allowanceData.length,
                               itemBuilder: (context, index) {
                                 final item = _allowanceData[index];
                                 final isModified = _modifiedRecords.any((r) => r['UID'] == item['UID']);
                                 
                                 return Container(
                                   decoration: BoxDecoration(
                                     border: Border(
                                       bottom: BorderSide(color: Colors.grey.shade300),
                                       left: BorderSide(color: Colors.grey.shade300),
                                       right: BorderSide(color: Colors.grey.shade300),
                                     ),
                                     color: isModified 
                                       ? Colors.yellow.withOpacity(0.2): (index % 2 == 0 ? Colors.white : Colors.grey.shade50),
                                   ),
                                   child: Row(
                                     children: [
                                       Expanded(
                                         flex: 3,
                                         child: Padding(
                                           padding: const EdgeInsets.all(8.0),
                                           child: Column(
                                             crossAxisAlignment: CrossAxisAlignment.start,
                                             children: [
                                               Text(
                                                 item['MaNV'] ?? '',
                                                 style: TextStyle(fontWeight: FontWeight.bold),
                                               ),
                                               Text(
                                                 _staffNames[item['MaNV']] ?? '',
                                                 style: TextStyle(
                                                   fontSize: 12,
                                                   color: Colors.grey[600],
                                                   fontStyle: FontStyle.italic,
                                                 ),
                                               ),
                                             ],
                                           ),
                                         ),
                                       ),
                                       Expanded(
                                         flex: 2,
                                         child: Padding(
                                           padding: const EdgeInsets.all(8.0),
                                           child: DropdownButtonFormField<String>(
                                             value: (item['PhanLoaiDacBiet'] as String?) ?? '',
                                             items: const [
                                               DropdownMenuItem(value: '', child: Text('Không')),
                                               DropdownMenuItem(value: 'A', child: Text('A')),
                                               DropdownMenuItem(value: 'B', child: Text('B')),
                                               DropdownMenuItem(value: 'C', child: Text('C')),
                                             ],
                                             decoration: InputDecoration(
                                               contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                               border: OutlineInputBorder(),
                                               enabledBorder: OutlineInputBorder(
                                                 borderSide: BorderSide(
                                                   color: isModified ? Colors.yellow.shade700 : Colors.grey.shade400,
                                                 ),
                                               ),
                                               focusedBorder: const OutlineInputBorder(
                                                 borderSide: BorderSide(
                                                   color: Colors.blue,
                                                   width: 2,
                                                 ),
                                               ),
                                             ),
                                             onChanged: (String? value) {
                                               _updateRecordValue(index, 'PhanLoaiDacBiet', value ?? '');
                                             },
                                           ),
                                         ),
                                       ),
                                       Expanded(
                                         flex: 2,
                                         child: Padding(
                                           padding: const EdgeInsets.all(8.0),
                                           child: TextField(
                                             controller: _getController(item['UID'], 'TruyLinh', item['TruyLinh']),
                                             keyboardType: TextInputType.number,
                                             style: TextStyle(
                                               color: _getCurrencyColor(item['TruyLinh']),
                                               fontWeight: FontWeight.bold,
                                             ),
                                             decoration: InputDecoration(
                                               contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                               border: OutlineInputBorder(),
                                               enabledBorder: OutlineInputBorder(
                                                 borderSide: BorderSide(
                                                   color: isModified ? Colors.yellow.shade700 : Colors.grey.shade400,
                                                 ),
                                               ),
                                               focusedBorder: const OutlineInputBorder(
                                                 borderSide: BorderSide(
                                                   color: Colors.blue,
                                                   width: 2,
                                                 ),
                                               ),
                                             ),
                                             inputFormatters: [
                                               CurrencyInputFormatter(),
                                             ],
                                             onChanged: (value) {
                                               _handleValueChange(index, 'TruyLinh', value);
                                             },
                                             onEditingComplete: () {
                                               FocusScope.of(context).nextFocus();
                                             },
                                           ),
                                         ),
                                       ),
                                       Expanded(
                                         flex: 2,
                                         child: Padding(
                                           padding: const EdgeInsets.all(8.0),
                                           child: TextField(
                                             controller: _getController(item['UID'], 'TruyThu', item['TruyThu']),
                                             keyboardType: TextInputType.number,
                                             style: TextStyle(
                                               color: _getCurrencyColor(item['TruyThu']),
                                               fontWeight: FontWeight.bold,
                                             ),
                                             decoration: InputDecoration(
                                               contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                               border: OutlineInputBorder(),
                                               enabledBorder: OutlineInputBorder(
                                                 borderSide: BorderSide(
                                                   color: isModified ? Colors.yellow.shade700 : Colors.grey.shade400,
                                                 ),
                                               ),
                                               focusedBorder: OutlineInputBorder(
                                                 borderSide: BorderSide(
                                                   color: Colors.blue,
                                                   width: 2,
                                                 ),
                                               ),
                                             ),
                                             inputFormatters: [
                                               CurrencyInputFormatter(),
                                             ],
                                             onChanged: (value) {
                                               _handleValueChange(index, 'TruyThu', value);
                                             },
                                             onEditingComplete: () {
                                               FocusScope.of(context).nextFocus();
                                             },
                                           ),
                                         ),
                                       ),
                                     ],
                                   ),
                                 );
                               },
                             ),
                     ),
                   ],
                 ),
               ),
         if (_isLoading)
           Container(
             color: Colors.black.withOpacity(0.3),
             child: Center(
               child: Card(
                 child: Padding(
                   padding: const EdgeInsets.all(20.0),
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       CircularProgressIndicator(),
                       SizedBox(height: 16),
                       Text('Đang xử lý...'),
                     ],
                   ),
                 ),
               ),
             ),
           ),
       ],
     ),
   );
 }
 
 String _formatCurrencyValue(dynamic value) {
   if (value == null) return '0';
   
   double numValue;
   if (value is int) {
     numValue = value.toDouble();
   } else if (value is double) {
     numValue = value;
   } else {
     numValue = double.tryParse(value.toString()) ?? 0.0;
   }
   
   final formatter = NumberFormat('#,###', 'vi_VN');
   return formatter.format(numValue);
 }
 
 Color _getCurrencyColor(dynamic value) {
   if (value == null) return Colors.black;
   
   double numValue;
   if (value is int) {
     numValue = value.toDouble();
   } else if (value is double) {
     numValue = value;
   } else {
     numValue = double.tryParse(value.toString()) ?? 0.0;
   }
   
   if (numValue > 0) {
     return Colors.green;
   } else if (numValue < 0) {
     return Colors.red;
   } else {
     return Colors.black;
   }
 }
}