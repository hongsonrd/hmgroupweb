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

class ProjectWorker extends StatefulWidget {
 final String selectedBoPhan;
 const ProjectWorker({Key? key, required this.selectedBoPhan}) : super(key: key);
 @override
 _ProjectWorkerState createState() => _ProjectWorkerState();
}

class _ProjectWorkerState extends State<ProjectWorker> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _attendanceData = [];
  List<String> _departments = [];
  List<String> _availableMonths = [];
  String? _selectedDepartment;
  String? _selectedMonth;
  Map<String, Map<String, dynamic>> _modifiedRecords = {};
  Map<String, Map<String, dynamic>> _newRecords = {};
  final List<String> _congThuongChoices = ['2X', '3X', 'X', 'HT', 'P', 'Ro'];
  late String _username;
  Map<String, String> _staffNames = {};

  @override
  void initState() {
    super.initState();
    _selectedDepartment = widget.selectedBoPhan;
    _username = Provider.of<UserCredentials>(context, listen: false).username;
    _initializeData();
  }
  Future<void> _loadStaffNames(List<String> employeeIds) async {
  final dbHelper = DBHelper();
  final placeholders = List.filled(employeeIds.length, '?').join(',');
  final result = await dbHelper.rawQuery(
    'SELECT MaNV, Ho_ten FROM staffbio WHERE MaNV IN ($placeholders)',
    employeeIds,
  );

  // Convert database results to a Map
  final Map<String, String> fetchedNames = {
    for (var row in result) row['MaNV'] as String: row['Ho_ten'] as String
  };

  // Assign "???" to unmatched IDs
  final Map<String, String> staffNames = {
    for (var id in employeeIds) id: fetchedNames[id] ?? "???"
  };

  setState(() {
    _staffNames = staffNames;
  });

  print('Loaded staff names: $_staffNames'); // Debug log
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
   try {
     final response = await AuthenticatedHttpClient.get(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/projectgs/$_username'),
        headers: {'Content-Type': 'application/json'},
      );
     print('Project API Response: ${response.statusCode} - ${response.body}');
     if (response.statusCode == 200) {
       final List<dynamic> apiDepts = json.decode(response.body);
       setState(() {
         _departments = apiDepts.map((e) => e.toString()).toList();
       });
     }
   } catch (e) {
     print('Project API error: $e');
   }

   final dbHelper = DBHelper();
   final existingDepts = await dbHelper.rawQuery(
     'SELECT DISTINCT BoPhan FROM chamcongcn ORDER BY BoPhan'
   );
   _departments.addAll(existingDepts.map((e) => e['BoPhan'] as String));
   _departments = _departments.toSet().toList()..sort();
   print('Final departments: $_departments');

   final months = await dbHelper.rawQuery(
     'SELECT DISTINCT strftime("%Y-%m", Ngay) as month FROM chamcongcn ORDER BY month DESC'
   );
   _availableMonths = months.map((e) => e['month'] as String).toList();
   
   String currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
   if (!_availableMonths.contains(currentMonth)) {
     _availableMonths.insert(0, currentMonth);
   }
   _selectedMonth = _availableMonths.first;
   print('Months: $_availableMonths, Selected: $_selectedMonth');
   
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
    
    // Process modified records
    for (var entry in _modifiedRecords.entries) {
      final record = entry.value;
      final uid = record['UID'] as String;
      
      // Remove UID from the record before sending
      final updates = Map<String, dynamic>.from(record);
      updates.remove('UID');
      
      print('Sending modified record: ${json.encode(updates)} for UID: $uid');
      
      final response = await http.put(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongsua/$uid'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updates)
      );
      
      print('Update response: ${response.statusCode} - ${response.body}');
      
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

      // Immediately sync new record
      try {
        final response = await http.post(
          Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamconggui'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(newRecord)
        );

        if (response.statusCode == 200) {
          // Add to local database
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
          
          // Reload data
          await _loadAttendanceData();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã thêm nhân viên mới thành công'))
          );
        } else {
          throw Exception('Failed to add new employee');
        }
      } catch (e) {
        print('Error adding new employee: $e');
        _showError('Không thể thêm nhân viên mới: ${e.toString()}');
      }
    }
  } catch (e) {
    _showError('Không thể thêm nhân viên mới');
  }
}
 void _showError(String message) {
   if (mounted) {
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
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

@override
Widget build(BuildContext context) {
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
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              ...days.map((day) {
                final attendance = _getAttendanceForDay(empId, day, columnType);
                final defaultValue = columnType == 'CongThuongChu' ? 'Ro' : '0';
                final value = attendance ?? defaultValue;
                final canEdit = _canEditDay(day);
                
                return DataCell(
                  columnType == 'CongThuongChu'
                    ? DropdownButton<String>(
                        value: _congThuongChoices.contains(value) ? value : defaultValue,
                        items: _congThuongChoices.map((choice) =>
                          DropdownMenuItem(
                            value: choice,
                            child: Text(choice),
                          )
                        ).toList(),
                        onChanged: canEdit ? (newValue) {
                          if (newValue != null) {
                            _updateAttendance(empId, day, columnType, newValue);
                          }
                        } : null,
                      )
                    : TextField(
                        controller: TextEditingController(text: value),
                        keyboardType: TextInputType.number,
                        enabled: canEdit,
                        onChanged: (value) => _updateAttendance(empId, day, columnType, value),
                      ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    ),
  );
}

Future<String> _getStaffName(String maNV) async {
  final dbHelper = DBHelper();
  final result = await dbHelper.rawQuery(
    'SELECT HoTen FROM staffbio WHERE MaNV = ?',
    [maNV]
  );
  return result.isNotEmpty ? result.first['HoTen'] as String : '';
}
void _updateAttendance(String empId, int day, String columnType, String? value) {
  if (value == null) return;
  
  final dateStr = '$_selectedMonth-${day.toString().padLeft(2, '0')}';
  print('Updating attendance for date: $dateStr');

  // Find existing record using date without time part
  var record = _attendanceData.firstWhere(
    (r) => r['MaNV'] == empId && r['Ngay'].split('T')[0] == dateStr,
    orElse: () {
      // Create new record if none exists
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
String? _getAttendanceForDay(String empId, int day, String columnType) {
  final dateStr = '$_selectedMonth-${day.toString().padLeft(2, '0')}';
  final record = _attendanceData.firstWhere(
    (record) => 
      record['MaNV'] == empId && 
      record['Ngay'].split('T')[0] == dateStr,  // Compare just the date part
    orElse: () => {},
  );
  return record[columnType]?.toString() ?? (columnType == 'CongThuongChu' ? 'Ro' : '0');
}
bool _canEditDay(int day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(Duration(days: 1));
  final checkDate = DateTime.parse('$_selectedMonth-${day.toString().padLeft(2, '0')}');
  // Allow editing current date
  if (checkDate.isAtSameMomentAs(today)) return true;
  // Allow editing yesterday if before 9am
  if (checkDate.isAtSameMomentAs(yesterday) && now.hour < 9) return true;
  
  return false;
}
Future<void> _loadAttendanceData() async {
  if (_selectedMonth == null || _selectedDepartment == null) return;
  try {
    final dbHelper = DBHelper();
    final data = await dbHelper.rawQuery('''
      SELECT * FROM chamcongcn 
      WHERE BoPhan = ? AND strftime('%Y-%m', Ngay) = ?
      ORDER BY MaNV, Ngay
    ''', [_selectedDepartment, _selectedMonth]);
    
    setState(() {
      _attendanceData = List<Map<String, dynamic>>.from(data.map((record) => {
        'UID': record['UID'] ?? '',
        'Ngay': record['Ngay'] ?? '',  // Keep the original date format
        'Gio': record['Gio'] ?? DateFormat('HH:mm:ss').format(DateTime.now()),
        'NguoiDung': record['NguoiDung'] ?? _username,
        'BoPhan': record['BoPhan'] ?? _selectedDepartment,
        'MaBP': record['MaBP'] ?? _selectedDepartment,
        'PhanLoai': record['PhanLoai'] ?? '',
        'MaNV': record['MaNV'] ?? '',
        'CongThuongChu': record['CongThuongChu'] ?? '',
        'NgoaiGioThuong': record['NgoaiGioThuong']?.toString() ?? '0',
        'NgoaiGioKhac': record['NgoaiGioKhac']?.toString() ?? '0',
        'NgoaiGiox15': record['NgoaiGiox15']?.toString() ?? '0',
        'NgoaiGiox2': record['NgoaiGiox2']?.toString() ?? '0',
        'HoTro': record['HoTro']?.toString() ?? '0',
        'PartTime': record['PartTime']?.toString() ?? '0',
        'PartTimeSang': record['PartTimeSang']?.toString() ?? '0',
        'PartTimeChieu': record['PartTimeChieu']?.toString() ?? '0',
        'CongLe': record['CongLe']?.toString() ?? '0',
      }));
    });
  final employeeIds = _getUniqueEmployees();
    await _loadStaffNames(employeeIds);
  } catch (e) {
    print('Error loading attendance data: $e');
    _showError('Không thể tải dữ liệu chấm công');
  }
}
}