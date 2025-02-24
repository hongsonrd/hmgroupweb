
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'http_client.dart';

class ProjectWorker2 extends StatefulWidget {
  final String selectedBoPhan;
  const ProjectWorker2({Key? key, required this.selectedBoPhan}) : super(key: key);
  @override
  _ProjectWorkerState createState() => _ProjectWorkerState();
}

class _ProjectWorkerState extends State<ProjectWorker2> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _attendanceData = [];
  List<String> _departments = [];
  List<String> _availableMonths = [];
  String? _selectedDepartment;
  String? _selectedMonth;
  Map<String, Map<String, dynamic>> _modifiedRecords = {};
  Map<String, Map<String, dynamic>> _newRecords = {};
  final List<String> _congThuongChoices = ['X', 'P', 'XĐ', 'Ro', 'P', 'HT', 'NT', 'CĐ', 'NL', 'Ô', 'TS', '2X', '3X', 'HV', '2HV', '3HV', '2XĐ', 'QLDV'];  late String _username;
  Map<String, String> _staffNames = {};
  bool _isDropdownDataLoaded = false;
  late Future<void> _initFuture;

  bool get canEdit {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day+2);
    final yesterday = today.subtract(Duration(days: 1));
    return now.hour < 9;
  }

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeWithCredentials();
  }

  Future<void> _initializeWithCredentials() async {
    final credentials = Provider.of<UserCredentials>(context, listen: false);
    _username = credentials.username;
    if (_username.isEmpty) {
      throw Exception('No username found');
    }
    await _initializeData();
  }

  Future<void> _loadStaffNames(List<String> employeeIds) async {
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
    setState(() {
      _staffNames = staffNames;
    });
  }

  Future<void> _loadProjects() async {
    try {
      final response = await AuthenticatedHttpClient.get(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/projectgs/$_username'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _departments = data.map((e) => e.toString()).toList();
        });
      }
    } catch (e) {
      print('Error loading projects: $e');
    }
  }
Future<void> _initializeData() async {
  setState(() => _isLoading = true);
  try {
    final dbHelper = DBHelper();
    try {
      final response = await AuthenticatedHttpClient.get(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/projectgs/$_username'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> apiDepts = json.decode(response.body);
        setState(() {
          _departments = apiDepts.map((e) => e.toString()).toList();
        });
      }
    } catch (e) {
      print('Project API error: $e');
    }

    final existingDepts = await dbHelper.rawQuery(
      'SELECT DISTINCT BoPhan FROM chamcongcn ORDER BY BoPhan'
    );
    _departments.addAll(existingDepts.map((e) => e['BoPhan'] as String));
    _departments = _departments.toSet().toList()..sort();

    // Handle department selection after we have the list
    setState(() {
      if (_departments.contains(widget.selectedBoPhan)) {
        _selectedDepartment = widget.selectedBoPhan;
      } else if (_departments.isNotEmpty) {
        _selectedDepartment = _departments[0];
      }
    });

    final months = await dbHelper.rawQuery(
      'SELECT DISTINCT strftime("%Y-%m", Ngay) as month FROM chamcongcn ORDER BY month DESC'
    );
    _availableMonths = months.map((e) => e['month'] as String).toList();
    String currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    if (!_availableMonths.contains(currentMonth)) {
      _availableMonths.insert(0, currentMonth);
    }
    _selectedMonth = _availableMonths.first;
    await _loadAttendanceData();
  } catch (e) {
    print('Init error: $e');
    _showError('Không thể tải dữ liệu');
  }
  setState(() => _isLoading = false);
}

  Future<void> _saveChanges() async {
    try {
      final dbHelper = DBHelper();
      for (var entry in _modifiedRecords.entries) {
        final record = entry.value;
        final uid = record['UID'] as String;
        final updates = Map<String, dynamic>.from(record);
        updates.remove('UID');
        final response = await http.put(
          Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongsua/$uid'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(updates)
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to update record: ${response.body}');
        }
        await dbHelper.updateChamCongCN(uid, updates);
      }
      setState(() {
        _modifiedRecords.clear();
      });
      await _loadAttendanceData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu thay đổi thành công'))
        );
      }
    } catch (e) {
      print('Error in _saveChanges: $e');
      _showError('Lỗi khi lưu dữ liệu: ${e.toString()}');
    }
  }

  Future<void> _addNewEmployee() async {
    try {
      String? maNV;
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Thêm nhân viên mới'),
          content: TextField(
            decoration: InputDecoration(labelText: 'Mã nhân viên'),
            textCapitalization: TextCapitalization.characters,
            onChanged: (value) => maNV = value.toUpperCase(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                if (maNV?.isNotEmpty == true) {
                  Navigator.of(context).pop({'MaNV': maNV!});
                }
              },
              child: Text('Thêm'),
            ),
          ],
        ),
      );

      if (result != null) {
        final now = DateTime.now();
        final uid = Uuid().v4();
        final newRecord = {
          'UID': uid,
          'Ngay': now.toIso8601String().split('T')[0],
          'Gio': DateFormat('HH:mm:ss').format(now),
          'NguoiDung': _username,
          'BoPhan': _selectedDepartment,
          'MaBP': _selectedDepartment,
          'PhanLoai': '',
          'MaNV': result['MaNV'],
          'CongThuongChu': '',
          'NgoaiGioThuong': '0',
          'NgoaiGioKhac': '0',
          'NgoaiGiox15': '0',
          'NgoaiGiox2': '0',
          'HoTro': '0',
          'PartTime': '0',
          'PartTimeSang': '0',
          'PartTimeChieu': '0',
          'CongLe': '0',
        };
        
        final response = await http.post(
          Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamconggui'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(newRecord)
        );

        if (response.statusCode == 200) {
          final chamCongModel = ChamCongCNModel(
            uid: newRecord['UID'] as String,
            maNV: newRecord['MaNV'] as String,
            ngay: DateTime.parse(newRecord['Ngay'] as String),
            boPhan: newRecord['BoPhan'] as String,
            nguoiDung: newRecord['NguoiDung'] as String,
            congThuongChu: newRecord['CongThuongChu'] as String,
            ngoaiGioThuong: double.tryParse(newRecord['NgoaiGioThuong'].toString()) ?? 0,
            ngoaiGioKhac: double.tryParse(newRecord['NgoaiGioKhac'].toString()) ?? 0,
            ngoaiGiox15: double.tryParse(newRecord['NgoaiGiox15'].toString()) ?? 0,
            ngoaiGiox2: double.tryParse(newRecord['NgoaiGiox2'].toString()) ?? 0,
            hoTro: int.tryParse(newRecord['HoTro'].toString()) ?? 0,
            partTime: int.tryParse(newRecord['PartTime'].toString()) ?? 0,
            partTimeSang: int.tryParse(newRecord['PartTimeSang'].toString()) ?? 0,
            partTimeChieu: int.tryParse(newRecord['PartTimeChieu'].toString()) ?? 0,
            congLe: double.tryParse(newRecord['CongLe'].toString()) ?? 0,
          );
          final dbHelper = DBHelper();
          await dbHelper.insertChamCongCN(chamCongModel);
          await _loadAttendanceData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã thêm nhân viên mới thành công'))
          );
        } else {
          throw Exception('Failed to add new employee');
        }
      }
    } catch (e) {
      print('Error adding new employee: $e');
      _showError('Không thể thêm nhân viên mới: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red)
      );
    }
  }

  List<int> _getDaysInMonth() {
    if (_selectedMonth == null) return [];
    final parts = _selectedMonth!.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    if (_selectedMonth == DateFormat('yyyy-MM').format(DateTime.now())) {
      final today = DateTime.now().day;
      return List.generate(today, (i) => today - i);
    } else {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      return List.generate(daysInMonth, (i) => i + 1);
    }
  }

  DataCell _buildAttendanceCell(String empId, int day, String columnType) {
    if (!_isDropdownDataLoaded) {
      return const DataCell(CircularProgressIndicator());
    }
    final attendance = _getAttendanceForDay(empId, day, columnType);
    return DataCell(
      columnType == 'CongThuongChu'
        ? DropdownButton<String>(
            value: attendance,
            items: _congThuongChoices.map((choice) =>
              DropdownMenuItem(value: choice, child: Text(choice))
            ).toList(),
            onChanged: canEdit ? (value) => _updateAttendance(empId, day, columnType, value) : null,
          )
        : TextField(
            controller: TextEditingController(text: attendance),
            keyboardType: TextInputType.number,
            enabled: canEdit,
            onChanged: (value) => _updateAttendance(empId, day, columnType, value),
          ),
    );
  }

  Widget _buildAttendanceTable(String columnType) {
    final days = _getDaysInMonth();
    final employees = _getUniqueEmployees();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            DataColumn(label: Text('Mã NV')),
            ...days.map((day) => DataColumn(label: Text(day.toString()))),
          ],
          rows: employees.map((empId) {
            return DataRow(
              cells: [
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(empId),
                      Text(
                        _staffNames[empId] ?? '',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                ...days.map((day) => _buildAttendanceCell(empId, day, columnType)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _updateAttendance(String empId, int day, String columnType, String? value) {
    if (value == null) return;
    final dateStr = '$_selectedMonth-${day.toString().padLeft(2, '0')}';
    var record = _attendanceData.firstWhere(
      (r) => r['MaNV'] == empId && r['Ngay'].split('T')[0] == dateStr,
      orElse: () {
        final newUid = Uuid().v4();
        final newRecord = {
          'UID': newUid,
          'MaNV': empId,
          'Ngay': dateStr,
          'Gio': DateFormat('HH:mm:ss').format(DateTime.now()),
          'NguoiDung': _username,
          'BoPhan': _selectedDepartment,
          'MaBP': _selectedDepartment,
          'PhanLoai': '',
          'CongThuongChu': '',
          'NgoaiGioThuong': '0',
          'NgoaiGioKhac': '0',
          'NgoaiGiox15': '0',
          'NgoaiGiox2': '0',
          'HoTro': '0',
          'PartTime': '0',
'PartTimeSang': '0',
         'PartTimeChieu': '0',
         'CongLe': '0',
       };
       _newRecords[newUid] = newRecord;
       _attendanceData.add(newRecord);
       return newRecord;
     }
   );
   setState(() {
     record[columnType] = value;
     final uid = record['UID'] as String;
     if (!_newRecords.containsKey(uid)) {
       _modifiedRecords[uid] = Map<String, dynamic>.from(record);
     }
   });
 }

 List<String> _getUniqueEmployees() {
   return _attendanceData.map((record) => record['MaNV'] as String).toSet().toList()..sort();
 }

 String _getAttendanceForDay(String empId, int day, String columnType) {
   final dateStr = '$_selectedMonth-${day.toString().padLeft(2, '0')}';
   final record = _attendanceData.firstWhere(
     (record) => 
       record['MaNV'] == empId && 
       record['Ngay'].split('T')[0] == dateStr,
     orElse: () => {},
   );

   if (columnType == 'CongThuongChu') {
     final value = record[columnType]?.toString() ?? '';
     return _congThuongChoices.contains(value) ? value : _congThuongChoices[0];
   }
   
   return record[columnType]?.toString() ?? '0';
 }

 Future<void> _loadAttendanceData() async {
   if (_selectedMonth == null || _selectedDepartment == null) return;
   setState(() {
     _isDropdownDataLoaded = false;
   });
   try {
     final dbHelper = DBHelper();
     final data = await dbHelper.rawQuery('''
       SELECT * FROM chamcongcn 
       WHERE BoPhan = ? AND strftime('%Y-%m', Ngay) = ?
       ORDER BY MaNV, Ngay
     ''', [_selectedDepartment, _selectedMonth]);
     setState(() {
       _attendanceData = List<Map<String, dynamic>>.from(data);
       _isDropdownDataLoaded = true;
     });
     final employeeIds = _getUniqueEmployees();
     await _loadStaffNames(employeeIds);
   } catch (e) {
     print('Error loading attendance data: $e');
     _showError('Không thể tải dữ liệu chấm công');
   }
 }

 @override
 Widget build(BuildContext context) {
   return FutureBuilder(
     future: _initFuture,
     builder: (context, snapshot) {
       if (snapshot.connectionState == ConnectionState.waiting) {
         return const Center(child: CircularProgressIndicator());
       }
       
       if (snapshot.hasError) {
         return Center(child: Text('Error: ${snapshot.error}'));
       }

       return Scaffold(
         appBar: AppBar(
           backgroundColor: Colors.purple,
           title: Row(
             children: [
               Expanded(
                 child: DropdownButton<String>(
                   value: _selectedDepartment,
                   items: _departments.map((dept) => 
                     DropdownMenuItem(value: dept, child: Text(dept))
                   ).toList(),
                   onChanged: (value) {
                     setState(() {
                       _selectedDepartment = value;
                       _loadAttendanceData();
                     });
                   },
                   style: TextStyle(color: Colors.white),
                   dropdownColor: Theme.of(context).primaryColor,
                   isExpanded: true,
                 ),
               ),
               SizedBox(width: 16),
               Expanded(
                 child: DropdownButton<String>(
                   value: _selectedMonth,
                   items: _availableMonths.map((month) => DropdownMenuItem(
                     value: month,
                     child: Text(DateFormat('MM/yyyy').format(DateTime.parse('$month-01')))
                   )).toList(),
                   onChanged: (value) {
                     setState(() {
                       _selectedMonth = value;
                       _loadAttendanceData();
                     });
                   },
                   style: TextStyle(color: Colors.white),
                   dropdownColor: Theme.of(context).primaryColor,
                   isExpanded: true,
                 ),
               ),
             ],
           ),
           leading: IconButton(
             icon: Icon(Icons.arrow_back, color: Colors.white),
             onPressed: () => Navigator.of(context).pop(),
           ),
         ),
         body: _isLoading 
           ? const Center(child: CircularProgressIndicator()) 
           : Column(
             children: [
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 16.0),
                 child: Row(
                   children: [
                     ElevatedButton(
                       onPressed: _addNewEmployee, 
                       child: Text('Thêm nhân viên mới')
                     ),
                     const SizedBox(width: 16),
                     ElevatedButton(
                       onPressed: (_modifiedRecords.isNotEmpty || _newRecords.isNotEmpty) 
                         ? _saveChanges 
                         : null,
                       child: Text('Lưu thay đổi'),
                     ),
                   ],
                 ),
               ),
               Expanded(
                 child: DefaultTabController(
                   length: 10,
                   child: Column(
                     children: [
                       TabBar(
                         isScrollable: true,
                         tabs: [
                           Tab(text: 'Công chữ'),
                           Tab(text: 'NG thường'),
                           Tab(text: 'Hỗ trợ'),
                           Tab(text: 'Part time'),
                           Tab(text: 'PT sáng'),
                           Tab(text: 'PT chiều'),
                           Tab(text: 'NG khác'),
                           Tab(text: 'NG x1.5'),
                           Tab(text: 'NG x2'),
                           Tab(text: 'Công lễ'),
                         ],
                       ),
                       Expanded(
                         child: TabBarView(
                           children: [
                             _buildAttendanceTable('CongThuongChu'),
                             _buildAttendanceTable('NgoaiGioThuong'),
                             _buildAttendanceTable('HoTro'),
                             _buildAttendanceTable('PartTime'),
                             _buildAttendanceTable('PartTimeSang'),
                             _buildAttendanceTable('PartTimeChieu'),
                             _buildAttendanceTable('NgoaiGioKhac'),
                             _buildAttendanceTable('NgoaiGiox15'),
                             _buildAttendanceTable('NgoaiGiox2'),
                             _buildAttendanceTable('CongLe'),
                           ],
                         ),
                       ),
                     ],
                   ),
                 ),
               ),
             ],
           ),
       );
     }
   );
 }
}