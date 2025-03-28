import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';
import 'projectplan2.dart';
import 'http_client.dart';
import 'projectworker.dart';
import 'projectorder.dart';
import 'projectimage.dart';
import 'projectmachineorder.dart';
class ProjectUpdateScreen extends StatefulWidget {
  final String boPhan;

  const ProjectUpdateScreen({
    Key? key,
    required this.boPhan,
  }) : super(key: key);

  @override
  _ProjectUpdateScreenState createState() => _ProjectUpdateScreenState();
}

class _ProjectUpdateScreenState extends State<ProjectUpdateScreen> {
  @override
  Widget build(BuildContext context) {
    final userCredentials = Provider.of<UserCredentials>(context);
   
    return Scaffold(
      appBar: AppBar(
        title: Text('Cập nhật ${widget.boPhan}'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = constraints.maxWidth > 1200 ? 6 :
                              constraints.maxWidth > 800 ? 4 : 2;
   
          return GridView.count(
            crossAxisCount: crossAxisCount,
            padding: EdgeInsets.all(16.0),
            mainAxisSpacing: 16.0,
            crossAxisSpacing: 16.0,
            childAspectRatio: 1.5,
          children: [
            MenuCard(
  title: 'Chấm công\nCN',
  icon: Icons.assignment_turned_in,
  color: Colors.brown,
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ProjectWorker(
        selectedBoPhan: widget.boPhan,
      ),
    ),
  ),
),
MenuCard(
              title: 'Kế hoạch\nLàm việc',
              icon: Icons.calendar_today,
              color: Colors.indigo,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectPlan2(
                    selectedBoPhan: widget.boPhan,
                    userType: 'HM-DV',
                  ),
                ),
              ),
            ),
            MenuCard(
              title: 'Danh sách\ncông nhân',
              icon: Icons.people,
              color: Colors.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StaffListTab(
                    boPhan: widget.boPhan,
                  ),
                ),
              ),
            ),
            MenuCard(
              title: 'Danh sách\nvị trí',
              icon: Icons.place,
              color: Colors.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PositionListTab(
                    boPhan: widget.boPhan,
                  ),
                ),
              ),
            ),
            MenuCard(
              title: 'Lịch sử\nbáo cáo',
              icon: Icons.history,
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TaskHistoryTab(
                    boPhan: widget.boPhan,
                  ),
                ),
              ),
            ),
            MenuCard(
              title: 'Cập nhật TT\nNhân sự',
              icon: Icons.update,
              color: Colors.purple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StaffStatusTab(
                    boPhan: widget.boPhan,
                    username: userCredentials.username,
                  ),
                ),
              ),
            ),
            MenuCard(
              title: 'Đặt\nđồng phục',
              icon: Icons.checkroom,
              color: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UniformOrderScreen(
                    boPhan: widget.boPhan,
                  ),
                ),
              ),
            ),
             MenuCard(
      title: 'Đặt\nvật tư',
      icon: Icons.inventory,
      color: Colors.amber,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProjectOrder(
            selectedBoPhan: widget.boPhan,
          ),
        ),
      ),
    ),
    MenuCard(
      title: 'Kiểm tra\nảnh',
      icon: Icons.photo,
      color: Colors.red,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProjectImageScreen(
            boPhan: 'Tất cả',
            username: userCredentials.username,
          ),
        ),
      ),
    ),
    MenuCard(
      title: 'Đặt máy\nmóc',
      icon: Icons.beach_access,
      color: Colors.pink,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProjectMachineOrder(
            boPhan: 'Tất cả',
            username: userCredentials.username,
          ),
        ),
      ),
    ),   
         ],
          );
        },
      ),
    );
  }
}

class StaffListTab extends StatefulWidget {
  final String boPhan;

  const StaffListTab({
    Key? key,
    required this.boPhan,
  }) : super(key: key);

  @override
  _StaffListTabState createState() => _StaffListTabState();
}

class _StaffListTabState extends State<StaffListTab> {
  final TextEditingController _maNVController = TextEditingController();
  List<Map<String, dynamic>> _staffList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStaffList();
  }

  @override
  void dispose() {
    _maNVController.dispose();
    super.dispose();
  }

  Future<void> _loadStaffList() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DBHelper();
      final staffList = await dbHelper.query(
        DatabaseTables.staffListTable,
        where: 'BoPhan = ?',
        whereArgs: [widget.boPhan],
      );

      setState(() {
        _staffList = staffList;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading staff list: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tải danh sách nhân viên'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addNewStaff() async {
  if (_maNVController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vui lòng nhập mã nhân viên')),
    );
    return;
  }

  final userCredentials = Provider.of<UserCredentials>(context, listen: false);
  final newStaff = StaffListModel(
    uid: const Uuid().v4(),
    manv: _maNVController.text.toUpperCase(), // Force uppercase before saving
    nguoiDung: userCredentials.username.toLowerCase(),
    vt: '',
    boPhan: widget.boPhan,
  );

    try {
      final response = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/newstaff'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(newStaff.toMap()),
      );

      if (response.statusCode == 200) {
        final dbHelper = DBHelper();
        await dbHelper.insertStaffList(newStaff);
        
        _maNVController.clear();
        await _loadStaffList();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thêm nhân viên thành công'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('Error adding staff: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể thêm nhân viên: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteStaff(String uid, String manv) async {
    try {
      final response = await AuthenticatedHttpClient.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/deletestaff'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'UID': uid}),
      );

      if (response.statusCode == 200) {
        final dbHelper = DBHelper();
        await dbHelper.delete(
          DatabaseTables.staffListTable,
          where: 'UID = ?',
          whereArgs: [uid],
        );
        
        await _loadStaffList();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa nhân viên $manv'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting staff: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể xóa nhân viên: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Danh sách công nhân'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
  controller: _maNVController,
  textCapitalization: TextCapitalization.characters,
  onChanged: (value) {
    // Force uppercase while typing
    _maNVController.value = _maNVController.value.copyWith(
      text: value.toUpperCase(),
      selection: TextSelection.collapsed(offset: value.toUpperCase().length),
    );
  },
  decoration: const InputDecoration(
    labelText: 'Mã nhân viên mới',
    border: OutlineInputBorder(),
  ),
),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 0, 204, 34),
                  foregroundColor: Colors.white,
                ),
                onPressed: _addNewStaff,
                child: const Text('Thêm'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _staffList.length,
                    itemBuilder: (context, index) {
                      final staff = _staffList[index];
                      return Card(
                        child: ListTile(
                          title: Text(staff['MaNV'] ?? ''),
                          subtitle: Text(staff['VT'] ?? 'Chưa có vị trí'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            color: Colors.red,
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Xác nhận'),
                                    content: Text(
                                        'Bạn có chắc muốn xóa nhân viên ${staff['MaNV']}?'),
                                    actions: [
                                      TextButton(
                                        child: const Text('Hủy'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      TextButton(
                                        child: const Text('Xóa'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          _deleteStaff(
                                              staff['UID'], staff['MaNV']);
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ), ),
    );
  }
}

class PositionListTab extends StatefulWidget {
  final String boPhan;

  const PositionListTab({
    Key? key,
    required this.boPhan,
  }) : super(key: key);

  @override
  _PositionListTabState createState() => _PositionListTabState();
}

class _PositionListTabState extends State<PositionListTab> {
  final TextEditingController _vtController = TextEditingController();
  final TextEditingController _khuVucController = TextEditingController();
  final TextEditingController _caBatdauController = TextEditingController();
  final TextEditingController _caKetthucController = TextEditingController();
  List<Map<String, dynamic>> _positionList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPositionList();
  }

  @override
  void dispose() {
    _vtController.dispose();
    _khuVucController.dispose();
    _caBatdauController.dispose();
    _caKetthucController.dispose();
    super.dispose();
  }

  Future<void> _loadPositionList() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DBHelper();
      final positions = await dbHelper.query(
        DatabaseTables.positionListTable,
        where: 'BoPhan = ?',
        whereArgs: [widget.boPhan],
      );

      setState(() {
        _positionList = positions;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading positions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tải danh sách vị trí'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addNewPosition() async {
  if (_vtController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vui lòng nhập vị trí')),
    );
    return;
  }

  final userCredentials = Provider.of<UserCredentials>(context, listen: false);
  final newPosition = PositionListModel(
    uid: const Uuid().v4(),
    boPhan: widget.boPhan,
    nguoiDung: userCredentials.username.toLowerCase(),
    vt: _vtController.text.toUpperCase(), // Force uppercase before saving
    khuVuc: _khuVucController.text,
    caBatdau: _caBatdauController.text,
    caKetthuc: _caKetthucController.text,
  );

    try {
      final response = await AuthenticatedHttpClient.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/newposition'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(newPosition.toMap()),
      );

      if (response.statusCode == 200) {
        final dbHelper = DBHelper();
        await dbHelper.insertPositionList(newPosition);
        
        _vtController.clear();
        _khuVucController.clear();
        _caBatdauController.clear();
        _caKetthucController.clear();
        await _loadPositionList();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thêm vị trí thành công'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('Error adding position: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể thêm vị trí: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deletePosition(String uid, String vt) async {
    try {
      final response = await AuthenticatedHttpClient.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/deleteposition'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'UID': uid}),
      );

      if (response.statusCode == 200) {
        final dbHelper = DBHelper();
        await dbHelper.delete(
          DatabaseTables.positionListTable,
          where: 'UID = ?',
          whereArgs: [uid],
        );
        
        await _loadPositionList();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa vị trí $vt'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting position: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể xóa vị trí: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Danh sách vị trí'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
  controller: _vtController,
  textCapitalization: TextCapitalization.characters,
  onChanged: (value) {
    // Force uppercase while typing
    _vtController.value = _vtController.value.copyWith(
      text: value.toUpperCase(),
      selection: TextSelection.collapsed(offset: value.toUpperCase().length),
    );
  },
  decoration: const InputDecoration(
    labelText: 'Vị trí',
    border: OutlineInputBorder(),
  ),
),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _khuVucController,
                    decoration: const InputDecoration(
                      labelText: 'Khu vực',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _caBatdauController,
                          decoration: const InputDecoration(
                            labelText: 'Ca bắt đầu',
                            hintText: '08:00',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _caKetthucController,
                          decoration: const InputDecoration(
                            labelText: 'Ca kết thúc',
                            hintText: '17:00',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 0, 204, 34),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _addNewPosition,
                      child: const Text('Thêm vị trí'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _positionList.length,
                    itemBuilder: (context, index) {
                      final position = _positionList[index];
                      return Card(
                        child: ListTile(
                          title: Text(position['VT'] ?? ''),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(position['KhuVuc'] ?? ''),
                              if (position['Ca_batdau'] != null || position['Ca_ketthuc'] != null)
                                Text('Ca: ${position['Ca_batdau'] ?? ''} - ${position['Ca_ketthuc'] ?? ''}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            color: Colors.red,
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Xác nhận'),
                                    content: Text(
                                        'Bạn có chắc muốn xóa vị trí ${position['VT']}?'),
                                    actions: [
                                      TextButton(
                                        child: const Text('Hủy'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      TextButton(
                                        child: const Text('Xóa'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          _deletePosition(
                                              position['UID'], position['VT']);
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      ),
    );
  }
}

class TaskHistoryTab extends StatefulWidget {
  final String boPhan;

  const TaskHistoryTab({
    Key? key,
    required this.boPhan,
  }) : super(key: key);

  @override
  _TaskHistoryTabState createState() => _TaskHistoryTabState();
}

class _TaskHistoryTabState extends State<TaskHistoryTab> {
  List<Map<String, dynamic>> _taskHistory = [];
  bool _isLoading = false;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadTaskHistory();
  }

  Future<void> _loadTaskHistory() async {
  setState(() {
    _isLoading = true;
  });

  try {
    final userCredentials = Provider.of<UserCredentials>(context, listen: false);
    final dbHelper = DBHelper();
    
    // Debug: First try to get ALL records without any WHERE clause
    final allRecords = await dbHelper.query(DatabaseTables.taskHistoryTable);
    print('Total records in taskhistory: ${allRecords.length}');
    
    // Debug: Print the first record if it exists
    if (allRecords.isNotEmpty) {
      print('Sample record: ${allRecords.first}');
    }
    
    // Now try the filtered query
    print('Querying for BoPhan: ${widget.boPhan}, User: ${userCredentials.username.toLowerCase()}');
    final history = await dbHelper.query(
      DatabaseTables.taskHistoryTable,
      where: 'BoPhan = ? AND NguoiDung = ?',
      whereArgs: [widget.boPhan, userCredentials.username.toLowerCase()],
    );

    print('Found ${history.length} records after filtering');

    setState(() {
      _taskHistory = history;
      _isLoading = false;
    });
  } catch (e) {
    print('Error loading task history: $e');
    // Let's also get database path for debugging
    try {
      final dbHelper = DBHelper();
      final db = await dbHelper.database;
      print('Database path: ${db.path}');
    } catch (e2) {
      print('Could not get database path: $e2');
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể tải lịch sử báo cáo'),
          backgroundColor: Colors.red,
        ),
      );
    }
    setState(() {
      _isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lịch sử báo cáo'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
            itemCount: _taskHistory.length,
            itemBuilder: (context, index) {
              final task = _taskHistory[index];
              final date = DateTime.parse(task['Ngay']);
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Row(
                        children: [
                          // Status emoji
                          Text(task['KetQua'] ?? ''),
                          const SizedBox(width: 8),
                          // Main content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (task['ChiTiet']?.isNotEmpty == true)
                                  Text(
                                    task['ChiTiet']!,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                if (task['ChiTiet2']?.isNotEmpty == true && task['ChiTiet2'] != 'null')
                                  Text(
                                    task['ChiTiet2']!,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text('${_dateFormat.format(date)} ${task['Gio']}'),
                          Text('Vị trí: ${task['ViTri']}'),
                          if (task['PhanLoai']?.isNotEmpty == true)
                            Text('Phân loại: ${task['PhanLoai']}'),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                    // Image section
                    if (task['HinhAnh']?.isNotEmpty == true && task['HinhAnh'] != 'null')
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            task['HinhAnh']!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return SizedBox(
                                height: 200,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(Icons.error_outline),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
            ),
          );
  }
}
class StaffStatusTab extends StatefulWidget {
  final String boPhan;
  final String username;

  const StaffStatusTab({
    required this.boPhan,
    required this.username,
  });

  @override
  _StaffStatusTabState createState() => _StaffStatusTabState();
}

class _StaffStatusTabState extends State<StaffStatusTab> {
  List<Map<String, dynamic>> _staffList = [];
  List<String> _staffVTList = [];
  bool _isLoading = true;
  Set<String> _modifiedRows = {};
  final List<String> _statusOptions = [
    'Đang làm việc',
    'Nghỉ',
    'Đi hỗ trợ',
    'Thiếu'
  ];
  Map<String, String> _selectedStatuses = {};
  Map<String, List<String>> _selectedSupports = {};
  Map<String, String> _phuongAnValues = {};
  final Map<String, TextEditingController> _phuongAnControllers = {};
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  @override
  void dispose() {
  _phuongAnControllers.values.forEach((controller) => controller.dispose());
  super.dispose();
}
  Future<void> _loadData() async {
    print('Starting _loadData');
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DBHelper();
      
      print('Getting staff list...');
      final rawStaffList = await dbHelper.getStaffListByDepartment(widget.boPhan);
      print('Staff list loaded: ${rawStaffList.length} staff members');

      print('Getting staffbio list...');
      final staffbioList = await dbHelper.getAllStaffbio();
      print('Staffbio list loaded: ${staffbioList.length} records');

      print('Getting VT history...');
      final allVTHistory = await dbHelper.getVTHistoryByDepartment(widget.boPhan);
      print('VT history loaded: ${allVTHistory.length} records');
      
      // Create maps for quick lookup
      final Map<String, Map<String, dynamic>> staffbioMap = {};
      for (var staff in staffbioList) {
        if (staff['MaNV'] != null) {
          staffbioMap[staff['MaNV'].toString()] = staff;
        }
      }

      // Group VT history by staff member
      final Map<String, List<Map<String, dynamic>>> vtHistoryMap = {};
      for (var history in allVTHistory) {
        final maNV = history['NhanVien'] as String?;
        if (maNV != null) {
          vtHistoryMap[maNV] ??= [];
          vtHistoryMap[maNV]!.add(history);
        }
      }

      // Get unique VT list
      _staffVTList = rawStaffList
          .map((staff) => staff['VT'] as String?)
          .where((vt) => vt != null && vt.isNotEmpty)
          .toSet()
          .toList()
          .cast<String>();

      // Create new list with enriched staff data
      final enrichedStaffList = rawStaffList.map((staff) {
        final maNV = staff['MaNV']?.toString();
        
        // Create a new map instead of modifying the original
        final enrichedStaff = Map<String, dynamic>.from(staff);
        
        if (maNV != null) {
          // Add staffbio info to new map
          enrichedStaff['Ho_ten'] = staffbioMap[maNV]?['Ho_ten'] ?? 'Unknown';
          
          // Initialize empty values for new staff
          _selectedStatuses[maNV] = '';
          _selectedSupports[maNV] = [];
          _phuongAnValues[maNV] = '';
          
          // Get VT history if exists
          final vtHistories = vtHistoryMap[maNV] ?? [];
          if (vtHistories.isNotEmpty) {
            // Find latest record
            final latest = vtHistories.reduce((a, b) {
              final dateA = DateTime.parse(a['Ngay'] as String);
              final dateB = DateTime.parse(b['Ngay'] as String);
              if (dateA.isAtSameMomentAs(dateB)) {
                return (a['Gio'] as String).compareTo(b['Gio'] as String) > 0 ? a : b;
              }
              return dateA.compareTo(dateB) > 0 ? a : b;
            });

            // Update with existing values
            _selectedStatuses[maNV] = latest['TrangThai'] as String? ?? '';
            _selectedSupports[maNV] = (latest['HoTro'] as String? ?? '')
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            _phuongAnValues[maNV] = latest['PhuongAn'] as String? ?? '';
          }
        }
        return enrichedStaff;
      }).toList();
      for (var staff in enrichedStaffList) {
    final maNV = staff['MaNV']?.toString();
    if (maNV != null) {
      _phuongAnControllers[maNV] = TextEditingController(text: _phuongAnValues[maNV] ?? '');
    }
  }
      setState(() {
        _staffList = enrichedStaffList;
        _isLoading = false;
      });
      print('_loadData completed successfully');

    } catch (e, stackTrace) {
      print('Error loading data: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải dữ liệu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
}
  Future<void> _saveChanges() async {
  try {
    final dbHelper = DBHelper();
    final now = DateTime.now();
    final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (String maNV in _modifiedRows) {
      final staff = _staffList.firstWhere((s) => s['MaNV'] == maNV);
      
      final vtHistory = VTHistoryModel(
        uid: const Uuid().v4(),
        ngay: now,
        gio: timeString,
        nguoiDung: widget.username.toLowerCase(),
        boPhan: widget.boPhan,
        viTri: staff['VT'] ?? '',
        nhanVien: maNV,
        trangThai: _selectedStatuses[maNV] ?? '',
        hoTro: _selectedSupports[maNV]?.join(', ') ?? '',
        phuongAn: _phuongAnValues[maNV] ?? '',
      );

      // Send to server
      final response = await AuthenticatedHttpClient.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/vthistory'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(vtHistory.toMap()),
      );

      if (response.statusCode == 200) {
        await dbHelper.insertVTHistory(vtHistory);
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    }

    setState(() {
      _modifiedRows.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu thành công'),
          backgroundColor: Colors.green,
        ),
      );
    }

  } catch (e) {
    print('Error saving changes: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi lưu thay đổi: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cập nhật TT Nhân sự'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
      children: [
        if (_modifiedRows.isNotEmpty)
          Padding(
            padding: EdgeInsets.all(8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 0, 204, 34),
                foregroundColor: Colors.white,
              ),
              onPressed: _saveChanges,
              child: Text('Lưu (${_modifiedRows.length} thay đổi)'),
            ),
          ),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: [
                        DataColumn(label: Text('MaNV')),
                        DataColumn(label: Text('Họ tên')),
                        DataColumn(label: Text('Trạng thái')),
                        DataColumn(label: Text('Hỗ trợ')),
                        DataColumn(label: Text('Phương án')),
                      ],
                      rows: _staffList.map((staff) {
                        final maNV = staff['MaNV'].toString();
                        return DataRow(
                          cells: [
                            DataCell(Text(maNV)),
                            DataCell(Text(staff['Ho_ten'] ?? '')),
                            DataCell(
                              DropdownButton<String>(
                                value: _selectedStatuses[maNV] ?? '',
                                items: ['', ..._statusOptions].map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value.isEmpty ? 'Chọn trạng thái' : value),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  setState(() {
                                    _selectedStatuses[maNV] = newValue ?? '';
                                    _modifiedRows.add(maNV);
                                  });
                                },
                              ),
                            ),
                            DataCell(
  InkWell(
    onTap: () {
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Chọn hỗ trợ'),
            content: Container(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _staffVTList.length,
                itemBuilder: (context, index) {
                  final vt = _staffVTList[index];
                  return CheckboxListTile(
                    title: Text(vt),
                    value: _selectedSupports[maNV]?.contains(vt) ?? false,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        setState(() {
                          _selectedSupports[maNV] ??= [];
                          if (value == true) {
                            _selectedSupports[maNV]!.add(vt);
                          } else {
                            _selectedSupports[maNV]!.remove(vt);
                          }
                          _modifiedRows.add(maNV);
                        });
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                child: Text('Đóng'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    },
    child: Container(
      padding: EdgeInsets.all(8.0),
      child: Text(
        _selectedSupports[maNV]?.isNotEmpty == true 
            ? _selectedSupports[maNV]!.join(', ')
            : 'Chọn vị trí hỗ trợ...',
        style: TextStyle(
          color: _selectedSupports[maNV]?.isNotEmpty == true 
              ? Colors.black 
              : Colors.grey,
          fontStyle: _selectedSupports[maNV]?.isNotEmpty == true 
              ? FontStyle.normal 
              : FontStyle.italic,
        ),
      ),
    ),
  ),
),
                            DataCell(
  Container(
    width: 200,
    child: TextField(
      controller: _phuongAnControllers[maNV],
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: 'Nhập phương án...',
      ),
      onChanged: (value) {
        setState(() {
          // Update both the controller and the values map
          _phuongAnValues[maNV] = value;
          _phuongAnControllers[maNV]?.text = value;
          // Update cursor position to end
          _phuongAnControllers[maNV]?.selection = TextSelection.fromPosition(
            TextPosition(offset: value.length)
          );
          _modifiedRows.add(maNV);
        });
      },
    ),
  ),
),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    ),
    );
  }
}
class MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const MenuCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: color,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class UniformOrderScreen extends StatefulWidget {
  final String boPhan;

  const UniformOrderScreen({
    Key? key,
    required this.boPhan,
  }) : super(key: key);

  @override
  _UniformOrderScreenState createState() => _UniformOrderScreenState();
}

class _UniformOrderScreenState extends State<UniformOrderScreen> {
  List<Map<String, List<DongPhucModel>>> _groupedOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DBHelper();
      final orders = await dbHelper.query(
        DatabaseTables.dongPhucTable,
        where: 'BoPhan = ?',
        whereArgs: [widget.boPhan],
      );

      // Convert to DongPhucModel list
      final orderModels = orders.map((o) => DongPhucModel.fromMap(o)).toList();

      // Group by month
      final grouped = <String, List<DongPhucModel>>{};
      for (var order in orderModels) {
        if (order.thang != null) {
          final key = DateFormat('MM/yyyy').format(order.thang!);
          grouped[key] ??= [];
          grouped[key]!.add(order);
        }
      }

      // Sort months in descending order
      final sortedGroups = grouped.entries.toList()
        ..sort((a, b) {
          final dateA = DateFormat('MM/yyyy').parse(a.key);
          final dateB = DateFormat('MM/yyyy').parse(b.key);
          return dateB.compareTo(dateA);
        });

      setState(() {
        _groupedOrders = sortedGroups.map((e) => {e.key: e.value}).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải danh sách đơn hàng')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }
  Future<void> _showOrderDetails(DongPhucModel order) async {
  try {
    final dbHelper = DBHelper();
    print('Loading details for OrderUID: ${order.uid}');
    
    // First get all records without filter to check total count
    final allRecords = await dbHelper.query(DatabaseTables.chiTietDPTable);
    print('Total records in ChiTietDP table: ${allRecords.length}');
    
    // Then get filtered records
    final allDetails = await dbHelper.query(
      DatabaseTables.chiTietDPTable,
      where: 'OrderUID = ?',
      whereArgs: [order.uid],
    );
    print('Found ${allDetails.length} items for order ${order.uid}');
    print('Sample record: ${allDetails.isNotEmpty ? allDetails.first : "no records"}');

    if (mounted) {
  showDialog(
    context: context,
    builder: (context) => OrderDetailsDialog(
      order: order,
      initialDetails: allDetails.map((d) => ChiTietDPModel.fromMap(d)).toList(),
      onRefresh: () {
        _loadOrders();
      },
    ),
  );
}
  } catch (e, stackTrace) {
    print('Error loading order details: $e');
    print('Stack trace: $stackTrace');
  }
}
Color _getStatusColor(String status) {
  switch (status?.toLowerCase() ?? '') {
    case 'nháp':
      return Colors.grey[200]!;
    case 'gửi':
      return Colors.blue[50]!;
    case 'duyệt':
      return Colors.green[50]!;
    case 'từ chối':
      return Colors.red[50]!;
    case 'hoàn thành':
      return Colors.purple[50]!;
    default:
      return Colors.white;
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Đặt đồng phục'),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
  icon: Icon(Icons.add),
  label: Text('Tạo đơn mới'),
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color.fromARGB(255, 0, 204, 34),
    foregroundColor: Colors.white,
    minimumSize: Size(double.infinity, 48),
  ),
  onPressed: () async {
    final userCredentials = Provider.of<UserCredentials>(context, listen: false);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewUniformOrderScreen(
          boPhan: widget.boPhan,
          username: userCredentials.username,
        ),
      ),
    );
      if (result == true) {
      _loadOrders();
    }
  },
),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _groupedOrders.length,
                    itemBuilder: (context, groupIndex) {
                      final group = _groupedOrders[groupIndex];
                      final month = group.keys.first;
                      final orders = group.values.first;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Tháng $month',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: orders.length,
                            itemBuilder: (context, index) {
                              final order = orders[index];
                              return Card(
  margin: EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 8.0,
  ),
  color: _getStatusColor(order.trangThai ?? ''),
  child: ListTile(
    title: Text(
      order.nguoiDung ?? '',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: order.trangThai?.toLowerCase() == 'từ chối' ? Colors.red : null,
      ),
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Phân loại: ${order.phanLoai ?? ''}'),
        Text(
          'Trạng thái: ${order.trangThai ?? ''}',
          style: TextStyle(
            color: order.trangThai?.toLowerCase() == 'từ chối' ? Colors.red : 
                  order.trangThai?.toLowerCase() == 'duyệt' ? Colors.green :
                  order.trangThai?.toLowerCase() == 'hoàn thành' ? Colors.purple :
                  null,
            fontWeight: FontWeight.bold
          ),
        ),
        if (order.thoiGianNhan != null)
          Text('Thời gian nhận: ${DateFormat('dd/MM/yyyy').format(order.thoiGianNhan!)}'),
      ],
    ),
    trailing: Icon(
      Icons.chevron_right,
      color: order.trangThai?.toLowerCase() == 'từ chối' ? Colors.red : 
            order.trangThai?.toLowerCase() == 'duyệt' ? Colors.green :
            order.trangThai?.toLowerCase() == 'hoàn thành' ? Colors.purple :
            null,
    ),
    onTap: () => _showOrderDetails(order),
  ),
);
                            },
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
class OrderDetailsDialog extends StatefulWidget {
  final DongPhucModel order;
  final List<ChiTietDPModel> initialDetails;
  final VoidCallback onRefresh;

  const OrderDetailsDialog({
    Key? key,
    required this.order,
    required this.initialDetails,
    required this.onRefresh,
  }) : super(key: key);

  @override
  _OrderDetailsDialogState createState() => _OrderDetailsDialogState();
}

class _OrderDetailsDialogState extends State<OrderDetailsDialog> {
  late List<ChiTietDPModel> _details;
  
  @override
  void initState() {
    super.initState();
    _details = List.from(widget.initialDetails);
  }
  
  Future<void> _refreshDetails() async {
    try {
      final dbHelper = DBHelper();
      final allDetails = await dbHelper.query(
        DatabaseTables.chiTietDPTable,
        where: 'OrderUID = ?',
        whereArgs: [widget.order.uid],
      );
      
      setState(() {
        _details = allDetails.map((d) => ChiTietDPModel.fromMap(d)).toList();
      });
    } catch (e) {
      print('Error refreshing details: $e');
    }
  }

  Future<void> _updateOrderStatus(BuildContext context) async {
    try {
      final updatedOrder = DongPhucModel(
        uid: widget.order.uid,
        nguoiDung: widget.order.nguoiDung,
        boPhan: widget.order.boPhan,
        phanLoai: widget.order.phanLoai,
        thoiGianNhan: widget.order.thoiGianNhan,
        trangThai: 'Gửi',  // Change status to Gửi
        thang: widget.order.thang,
        xuLy: widget.order.xuLy,
      );

      final response = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/dongphuccapnhat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updatedOrder.toMap()),
      );

      if (response.statusCode == 200) {
        final dbHelper = DBHelper();
        await dbHelper.update(
          DatabaseTables.dongPhucTable,
          updatedOrder.toMap(),
          where: 'UID = ?',
          whereArgs: [widget.order.uid],
        );
        
        Navigator.pop(context);
        widget.onRefresh();
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi cập nhật trạng thái: $e')),
      );
    }
  }

  void _showAddItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddUniformItemDialog(
        orderUid: widget.order.uid,
        boPhan: widget.order.boPhan,
        onItemAdded: () {
          Navigator.pop(context);
          _refreshDetails(); // Refresh the list after adding
        },
      ),
    );
  }

  Future<void> _deleteOrderItem(BuildContext context, ChiTietDPModel item) async {
    try {
      final response = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chitietdpxoa'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'UID': item.uid}),
      );

      if (response.statusCode == 200) {
        final dbHelper = DBHelper();
        await dbHelper.delete(
          DatabaseTables.chiTietDPTable,
          where: 'UID = ?',
          whereArgs: [item.uid],
        );
        
        // Refresh the details list
        await _refreshDetails();
        
        // Also notify parent to refresh
        widget.onRefresh();
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xóa chi tiết: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chi tiết đơn'),
        actions: [
          if (widget.order.trangThai == 'Nháp')
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    final result = await showDialog(
                      context: context,
                      builder: (context) => EditOrderDialog(
                        order: widget.order,
                        onUpdate: () {
                          Navigator.pop(context);
                          widget.onRefresh();
                        },
                      ),
                    );
                    if (result == true) {
                      widget.onRefresh();
                    }
                  },
                  child: Text('Sửa'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: () => _updateOrderStatus(context),
                  child: Text('Gửi'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order info section
          Container(
            color: Colors.grey[200],
            padding: EdgeInsets.all(16),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Người đặt: ${widget.order.nguoiDung}', style: TextStyle(fontSize: 16)),
                Text('Phân loại: ${widget.order.phanLoai}', style: TextStyle(fontSize: 16)),
                Text('Trạng thái: ${widget.order.trangThai}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (widget.order.thoiGianNhan != null)
                  Text('Thời gian nhận: ${DateFormat('dd/MM/yyyy').format(widget.order.thoiGianNhan!)}', style: TextStyle(fontSize: 16)),
                Text('Bộ phận: ${widget.order.boPhan}', style: TextStyle(fontSize: 16)),
                if (widget.order.xuLy?.isNotEmpty == true)
                  Text('Xử lý: ${widget.order.xuLy}', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
          
          // Action bar for order details
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Danh sách chi tiết (${_details.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.order.trangThai == 'Nháp')
                  ElevatedButton.icon(
                    icon: Icon(Icons.add),
                    label: Text('Thêm'),
                    onPressed: () => _showAddItemDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          
          // Table header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Nhân viên', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Áo', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Quần', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Giày', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Khác', style: TextStyle(fontWeight: FontWeight.bold))),
                if (widget.order.trangThai == 'Nháp') SizedBox(width: 48),
              ],
            ),
          ),
          
          Divider(height: 1),
          
          // Detail items
          Expanded(
            child: _details.isEmpty 
                ? Center(child: Text('Chưa có chi tiết đơn hàng', style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    itemCount: _details.length,
                    separatorBuilder: (context, index) => Divider(height: 1),
                    itemBuilder: (context, index) {
                      final detail = _details[index];
                      return InkWell(
                        onTap: () {
                          // Show detailed view when clicked
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => Container(
                              padding: EdgeInsets.all(16),
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Chi tiết đồng phục', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                    SizedBox(height: 16),
                                    Text('Mã CN: ${detail.maCN ?? ''}'),
                                    Text('Tên: ${detail.ten ?? ''}'),
                                    Text('Giới tính: ${detail.gioiTinh ?? ''}'),
                                    SizedBox(height: 8),
                                    if (detail.loaiAo?.isNotEmpty == true) ...[
                                      Text('Áo:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text('${detail.loaiAo} - Size ${detail.sizeAo}'),
                                      SizedBox(height: 8),
                                    ],
                                    if (detail.loaiQuan?.isNotEmpty == true) ...[
                                      Text('Quần:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text('${detail.loaiQuan} - Size ${detail.sizeQuan}'),
                                      SizedBox(height: 8),
                                    ],
                                    if (detail.loaiGiay?.isNotEmpty == true) ...[
                                      Text('Giày:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text('${detail.loaiGiay} - Size ${detail.sizeGiay}'),
                                      SizedBox(height: 8),
                                    ],
                                    if (detail.loaiKhac?.isNotEmpty == true) ...[
                                      Text('Khác:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text('${detail.loaiKhac} - Size ${detail.sizeKhac}'),
                                      SizedBox(height: 8),
                                    ],
                                    if (detail.ghiChu?.isNotEmpty == true) ...[
                                      Text('Ghi chú:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text('${detail.ghiChu}'),
                                      SizedBox(height: 8),
                                    ],
                                    if (detail.thoiGianGanNhat != null) ...[
                                      Text('Thời gian cấp gần nhất:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text('${DateFormat('dd/MM/yyyy').format(detail.thoiGianGanNhat!)}'),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              // Staff info
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(detail.ten ?? '', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text(detail.maCN ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                  ],
                                ),
                              ),
                              
                              // Áo
                              Expanded(
                                flex: 2,
                                child: detail.loaiAo?.isNotEmpty == true
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(detail.loaiAo ?? ''),
                                          Text('Size: ${detail.sizeAo ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                        ],
                                      )
                                    : Text('-'),
                              ),
                              
                              // Quần
                              Expanded(
                                flex: 2,
                                child: detail.loaiQuan?.isNotEmpty == true
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(detail.loaiQuan ?? ''),
                                          Text('Size: ${detail.sizeQuan ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                        ],
                                      )
                                    : Text('-'),
                              ),
                              
                              // Giày
                              Expanded(
                                flex: 2,
                                child: detail.loaiGiay?.isNotEmpty == true
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(detail.loaiGiay ?? ''),
                                          Text('Size: ${detail.sizeGiay ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                        ],
                                      )
                                    : Text('-'),
                              ),
                              
                              // Khác
                              Expanded(
                                flex: 2,
                                child: detail.loaiKhac?.isNotEmpty == true
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(detail.loaiKhac ?? ''),
                                          Text('Size: ${detail.sizeKhac ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                        ],
                                      )
                                    : Text('-'),
                              ),
                              
                              // Delete action
                              if (widget.order.trangThai == 'Nháp')
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('Xác nhận'),
                                        content: Text('Bạn có chắc muốn xóa chi tiết này?'),
                                        actions: [
                                          TextButton(
                                            child: Text('Hủy'),
                                            onPressed: () => Navigator.of(context).pop(),
                                          ),
                                          TextButton(
                                            child: Text('Xóa'),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.red,
                                            ),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                              _deleteOrderItem(context, detail);
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
class NewUniformOrderScreen extends StatefulWidget {
  final String boPhan;
  final String username;

  const NewUniformOrderScreen({
    Key? key,
    required this.boPhan,
    required this.username,
  }) : super(key: key);

  @override
  _NewUniformOrderScreenState createState() => _NewUniformOrderScreenState();
}

class _NewUniformOrderScreenState extends State<NewUniformOrderScreen> {
  final List<String> _phanLoaiOptions = ['Thay thế', 'Cấp mới'];
  String? _selectedPhanLoai;
  DateTime? _selectedDate;
  bool _isSubmitting = false;
  
  // Get valid date range
  DateTime get _minDate => DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1
  );
  
  DateTime get _maxDate {
  final now = DateTime.now();
  final lastDay = DateTime(now.year, now.month + 4, 0);
  return lastDay;
}

  Future<void> _submitOrder() async {
  if (_selectedPhanLoai == null || _selectedDate == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')),
    );
    return;
  }

  setState(() {
    _isSubmitting = true;
  });

  try {
    // Create first day of current month
    final firstDayOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

    final newOrder = DongPhucModel(
      uid: const Uuid().v4(),
      nguoiDung: widget.username.toLowerCase(),
      boPhan: widget.boPhan,
      phanLoai: _selectedPhanLoai!,
      thoiGianNhan: DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day),
      trangThai: 'Nháp',
      thang: firstDayOfMonth,
      xuLy: 'Chưa xử lý',
    );
      print('Sending order data: ${json.encode(newOrder.toMap())}');

      final response = await AuthenticatedHttpClient.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/dongphucmoi'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(newOrder.toMap()),
      );
      print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');
      if (response.statusCode == 200) {
        final dbHelper = DBHelper();
        await dbHelper.insertDongPhuc(newOrder);

        if (mounted) {
          Navigator.pop(context, true); // Return true to trigger refresh
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tạo đơn thành công'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('Error submitting order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể tạo đơn: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tạo đơn mới'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display fixed information
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thông tin cơ bản',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text('Người đặt: ${widget.username}'),
                    Text('Bộ phận: ${widget.boPhan}'),
                    Text('Trạng thái: Nháp'),
                    Text('Xử lý: Chưa xử lý'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Phân loại dropdown
            DropdownButtonFormField<String>(
              value: _selectedPhanLoai,
              decoration: InputDecoration(
                labelText: 'Phân loại',
                border: OutlineInputBorder(),
              ),
              items: _phanLoaiOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedPhanLoai = newValue;
                });
              },
            ),
            SizedBox(height: 16),

            // Date picker
            InkWell(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate ?? DateTime.now(),
                  firstDate: _minDate,
                  lastDate: _maxDate,
                );
                if (picked != null) {
                  setState(() {
                    _selectedDate = picked;
                  });
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Thời gian nhận',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDate != null
                          ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                          : 'Chọn ngày',
                    ),
                    Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 0, 204, 34),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isSubmitting ? null : _submitOrder,
                child: _isSubmitting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text('Tạo đơn'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class AddUniformItemDialog extends StatefulWidget {
  final String orderUid;
  final String boPhan;
  final VoidCallback onItemAdded;

  const AddUniformItemDialog({
    required this.orderUid,
    required this.boPhan,
    required this.onItemAdded,
  });

  @override
  _AddUniformItemDialogState createState() => _AddUniformItemDialogState();
}

class _AddUniformItemDialogState extends State<AddUniformItemDialog> {
  Map<String, dynamic>? _selectedStaff;
  Map<String, dynamic>? _staffbioData;
  String? _selectedAo;
  String? _selectedSizeAo;
  String? _selectedQuan;
  String? _selectedSizeQuan;
  String? _selectedGiay;
  String? _selectedSizeGiay;
  String? _selectedLoaiKhac;
  String? _selectedSizeKhac;
  final TextEditingController _ghiChuController = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _staffList = [];
  bool _isPreparationOrder = false;
  String? _selectedGender;
  int _orderAmount = 1;
  
  @override
  void initState() {
    super.initState();
    _loadStaffList();
  }

  @override
  void dispose() {
    _ghiChuController.dispose();
    super.dispose();
  }

  Future<void> _loadStaffList() async {
    try {
      final dbHelper = DBHelper();
      final staffList = await dbHelper.getStaffListByDepartment(widget.boPhan);
      setState(() {
        _staffList = staffList;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading staff list: $e');
    }
  }

  Future<void> _loadStaffbioData(String maNV) async {
    try {
      final dbHelper = DBHelper();
      final staffbioData = await dbHelper.query(
        DatabaseTables.staffbioTable,
        where: 'MaNV = ?',
        whereArgs: [maNV],
      );

      if (staffbioData.isNotEmpty) {
        setState(() {
          _staffbioData = staffbioData.first;
        });
      }
    } catch (e) {
      print('Error loading staffbio data: $e');
    }
  }

  List<String> _getAoOptions(String gioiTinh) {
    if (gioiTinh == "Nam") {
      return ["Áo xám tay lỡ", "Áo xanh nam thêu logo", "Áo xám cổ pha tím nam", "Áo phông cam nam", "Áo mới 2025"];
    } else {
      return ["Áo nữ xanh thêu logo", "Áo phông cam nữ", "Áo xám tay lỡ", "Áo mới 2025"];
    }
  }

  List<String> _getSizeAoOptions(String gioiTinh, String ao) {
    if (gioiTinh == "Nam") {
      switch (ao) {
        case "Áo xám tay lỡ":
        case "Áo xanh nam thêu logo":
        case "Áo xám cổ pha tím nam":
          return ["Số 1", "Số 2", "Số 3", "Số 4", "Số 5", "Số 6"];
        case "Áo phông cam nam":
          return ["M", "L", "XL"];
        case "Áo mới 2025":
          return ["S", "M", "L", "XL", "XXL"];
        default:
          return [];
      }
    } else {
      switch (ao) {
        case "Áo nữ xanh thêu logo":
        case "Áo xám tay lỡ":
          return ["Số 1", "Số 2", "Số 3", "Số 4", "Số 5", "Số 6"];
        case "Áo phông cam nữ":
          return ["M", "L", "XL"];
        case "Áo mới 2025":
          return ["S", "M", "L", "XL", "XXL"];
        default:
          return [];
      }
    }
  }
  List<String> _getQuanOptions(String gioiTinh) {
    return gioiTinh == "Nam" ? ["Quần Nam"] : ["Quần nữ"];
  }

  List<String> _getSizeQuanOptions() {
    return ["Size 1", "Size 2", "Size 3", "Size 4", "Size 5", "Size 6"];
  }

  List<String> _getGiayOptions(String gioiTinh) {
    if (gioiTinh == "Nam") {
      return ["Dép tổ ong cỡ", "Rọ đen Kim Long", "Giày lưới", "Sục lưới", "Giày đinh"];
    } else {
      return ["Giày asian nữ", "Giày lưới", "Sục lưới", "Giày đinh", "Dép rọ đỏ nữ", "Dép tổ ong cỡ", "Rọ đen Kim Long"];
    }
  }

  List<String> _getSizeGiayOptions(String gioiTinh, String giay) {
    if (gioiTinh == "Nam") {
      switch (giay) {
        case "Giày lưới":
          return ["Số 36", "Số 37", "Số 38", "Số 39", "Số 40", "Số 41", "Số 42", "Số 43"];
        case "Sục lưới":
          return ["Số 36", "Số 37", "Số 38", "Số 39", "Số 40", "Số 41", "Số 42", "Số 43", "Số 44"];
        case "Giày đinh":
          return ["Số 38", "Số 39", "Số 40", "Số 41", "Số 42", "Số 43", "Số 44"];
        case "Dép tổ ong cỡ":
          return ["Đôi"];
        case "Rọ đen Kim Long":
          return ["Số 39", "Số 40", "Số 41", "Số 42", "Số 43"];
        default:
          return [];
      }
    } else {
      switch (giay) {
        case "Giày asian nữ":
          return ["Số 35", "Số 36", "Số 37", "Số 38", "Số 39", "Số 40", "Số 41", "Số 42", "Số 43"];
        case "Giày lưới":
          return ["Số 36", "Số 37", "Số 38", "Số 39", "Số 40", "Số 41", "Số 42", "Số 43"];
        case "Sục lưới":
          return ["Số 36", "Số 37", "Số 38", "Số 39", "Số 40", "Số 41", "Số 42", "Số 43", "Số 44"];
        case "Giày đinh":
          return ["Số 38", "Số 39", "Số 40"];
        case "Dép tổ ong cỡ":
          return ["Đôi"];
        case "Dép rọ đỏ nữ":
        case "Rọ đen Kim Long":
          return ["Số 39", "Số 40", "Số 41", "Số 42", "Số 43"];
        default:
          return [];
      }
    }
  }

  List<String> _getLoaiKhacOptions(String gioiTinh) {
    if (gioiTinh == "Nam") {
      return ["Áo mùa đông", "Mũ BV", "Bộ quần áo bệnh viện", "Bộ phòng mổ"];
    } else {
      return ["Mũ BV", "Bộ quần áo bệnh viện", "Bộ phòng mổ", "Cặp tóc mới", "Áo mùa đông"];
    }
  }

  List<String> _getSizeKhacOptions(String gioiTinh, String loaiKhac) {
    if (gioiTinh == "Nam") {
      switch (loaiKhac) {
        case "Áo mùa đông":
        case "Bộ quần áo bệnh viện":
        case "Bộ phòng mổ":
          return ["Số 1", "Số 2", "Số 3", "Số 4", "Số 5", "Số 6"];
        case "Mũ BV":
          return ["Cái"];
        default:
          return [];
      }
    } else {
      switch (loaiKhac) {
        case "Mũ BV":
        case "Cặp tóc mới":
          return ["Cái"];
        case "Bộ quần áo bệnh viện":
        case "Bộ phòng mổ":
        case "Áo mùa đông":
          return ["Số 1", "Số 2", "Số 3", "Số 4", "Số 5", "Số 6"];
        default:
          return [];
      }
    }
  }
Future<void> _saveItem() async {
    // Validation for regular staff order
    if (!_isPreparationOrder && _selectedStaff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng chọn nhân viên')),
      );
      return;
    }
    
    // Validation for preparation order
    if (_isPreparationOrder && _selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng chọn giới tính')),
      );
      return;
    }

    try {
      if (_isPreparationOrder) {
        // Create multiple items for preparation order
        for (int i = 0; i < _orderAmount; i++) {
          final newItem = ChiTietDPModel(
            orderUid: widget.orderUid,
            uid: const Uuid().v4(),
            maCN: 'HDM-${_selectedGender == 'Nam' ? 'NAM' : 'NU'}-${DateTime.now().millisecondsSinceEpoch}-$i',
            ten: 'Hợp đồng mới ${_selectedGender}',
            gioiTinh: _selectedGender,
            thoiGianGanNhat: null,
            loaiAo: _selectedAo,
            sizeAo: _selectedSizeAo,
            loaiQuan: _selectedQuan,
            sizeQuan: _selectedSizeQuan,
            loaiGiay: _selectedGiay,
            sizeGiay: _selectedSizeGiay,
            loaiKhac: _selectedLoaiKhac,
            sizeKhac: _selectedSizeKhac,
            ghiChu: 'Đặt hàng chuẩn bị nhân viên mới. ${_ghiChuController.text}',
          );
          
          await _submitItemToServer(newItem);
        }
        
        widget.onItemAdded();
      } else {
        // Create single item for existing staff
        final newItem = ChiTietDPModel(
          orderUid: widget.orderUid,
          uid: const Uuid().v4(),
          maCN: _selectedStaff!['MaNV'],
          ten: _staffbioData?['Ho_ten'],
          gioiTinh: _staffbioData?['Gioi_tinh'],
          thoiGianGanNhat: _staffbioData?['NgayCapDP'] != null 
              ? DateTime.parse(_staffbioData!['NgayCapDP']) 
              : null,
          loaiAo: _selectedAo,
          sizeAo: _selectedSizeAo,
          loaiQuan: _selectedQuan,
          sizeQuan: _selectedSizeQuan,
          loaiGiay: _selectedGiay,
          sizeGiay: _selectedSizeGiay,
          loaiKhac: _selectedLoaiKhac,
          sizeKhac: _selectedSizeKhac,
          ghiChu: _ghiChuController.text,
        );
        
        await _submitItemToServer(newItem);
        widget.onItemAdded();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lưu chi tiết: $e')),
      );
    }
  }

  Future<void> _submitItemToServer(ChiTietDPModel item) async {
    final response = await http.post(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chitietdpmoi'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(item.toMap()),
    );

    if (response.statusCode == 200) {
      final dbHelper = DBHelper();
      await dbHelper.insertChiTietDP(item);
    } else {
      throw Exception('Server returned ${response.statusCode}');
    }
  }
   void _toggleOrderMode(String gender) {
    setState(() {
      _isPreparationOrder = true;
      _selectedGender = gender;
      _selectedStaff = null;
      _staffbioData = null;
      
      // Reset selections
      _selectedAo = null;
      _selectedSizeAo = null;
      _selectedQuan = null;
      _selectedSizeQuan = null;
      _selectedGiay = null;
      _selectedSizeGiay = null;
      _selectedLoaiKhac = null;
      _selectedSizeKhac = null;
    });
  } 
@override
Widget build(BuildContext context) {
  final String gioiTinh = _isPreparationOrder 
      ? _selectedGender ?? '' 
      : _staffbioData?['Gioi_tinh'] ?? '';

  return Dialog(
    child: SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       mainAxisSize: MainAxisSize.min,
       children: [
         Text(
           'Thêm chi tiết đồng phục',
           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
         ),
         SizedBox(height: 16),

         if (!_isPreparationOrder) ...[
           DropdownButtonFormField<Map<String, dynamic>>(
             value: _selectedStaff,
             decoration: InputDecoration(
               labelText: 'Chọn nhân viên',
               border: OutlineInputBorder(),
             ),
             items: _staffList.map((staff) {
               return DropdownMenuItem<Map<String, dynamic>>(
                 value: staff,
                 child: Text('${staff['MaNV']} - ${staff['Ho_ten'] ?? ''}'),
               );
             }).toList(),
             onChanged: (value) {
               setState(() {
                 _selectedStaff = value;
                 if (value != null) {
                   _loadStaffbioData(value['MaNV']);
                 }
               });
             },
           ),
           
           SizedBox(height: 16),
           
           Row(
             children: [
               Expanded(
                 child: ElevatedButton(
                   onPressed: () => _toggleOrderMode('Nam'),
                   child: Text('Đặt HĐ mới NV Nam'),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.blue,
                     foregroundColor: Colors.white,
                   ),
                 ),
               ),
               SizedBox(width: 8),
               Expanded(
                 child: ElevatedButton(
                   onPressed: () => _toggleOrderMode('Nữ'),
                   child: Text('Đặt HĐ mới NV Nữ'),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.pink,
                     foregroundColor: Colors.white,
                   ),
                 ),
               ),
             ],
           ),
         ],
         
         if (_isPreparationOrder) ...[
           Card(
             color: _selectedGender == 'Nam' ? Colors.blue[50] : Colors.pink[50],
             child: Padding(
               padding: EdgeInsets.all(16.0),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     'Đặt đồng phục cho nhân viên ${_selectedGender} mới',
                     style: TextStyle(
                       fontWeight: FontWeight.bold,
                       fontSize: 16,
                     ),
                   ),
                   SizedBox(height: 8),
                   
                   Row(
                     children: [
                       Text('Số lượng:'),
                       Expanded(
                         child: Slider(
                           value: _orderAmount.toDouble(),
                           min: 1,
                           max: 20,
                           divisions: 19,
                           label: _orderAmount.toString(),
                           onChanged: (value) {
                             setState(() {
                               _orderAmount = value.toInt();
                             });
                           },
                         ),
                       ),
                       Container(
                         width: 40,
                         child: Text(
                           _orderAmount.toString(),
                           style: TextStyle(
                             fontWeight: FontWeight.bold,
                             fontSize: 18,
                           ),
                           textAlign: TextAlign.center,
                         ),
                       ),
                     ],
                   ),
                   
                   SizedBox(height: 8),
                   ElevatedButton(
                     onPressed: () {
                       setState(() {
                         _isPreparationOrder = false;
                         _selectedStaff = null;
                         _staffbioData = null;
                       });
                     },
                     child: Text('Quay lại đặt cho nhân viên cũ'),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.grey,
                       foregroundColor: Colors.white,
                     ),
                   ),
                 ],
               ),
             ),
           ),
           SizedBox(height: 16),
         ],

         if (gioiTinh.isNotEmpty) ...[
           DropdownButtonFormField<String>(
             value: _selectedAo,
             decoration: InputDecoration(
               labelText: 'Áo',
               border: OutlineInputBorder(),
             ),
             items: _getAoOptions(gioiTinh).map((String value) {
               return DropdownMenuItem<String>(
                 value: value,
                 child: Text(value),
               );
             }).toList(),
             onChanged: (value) {
               setState(() {
                 _selectedAo = value;
                 _selectedSizeAo = null;
               });
             },
           ),

           if (_selectedAo != null) ...[
             SizedBox(height: 8),
             DropdownButtonFormField<String>(
               value: _selectedSizeAo,
               decoration: InputDecoration(
                 labelText: 'Size áo',
                 border: OutlineInputBorder(),
               ),
               items: _getSizeAoOptions(gioiTinh, _selectedAo!).map((String value) {
                 return DropdownMenuItem<String>(
                   value: value,
                   child: Text(value),
                 );
               }).toList(),
               onChanged: (value) {
                 setState(() {
                   _selectedSizeAo = value;
                 });
               },
             ),
           ],
           SizedBox(height: 16),
           
           DropdownButtonFormField<String>(
             value: _selectedQuan,
             decoration: InputDecoration(
               labelText: 'Quần',
               border: OutlineInputBorder(),
             ),
             items: _getQuanOptions(gioiTinh).map((String value) {
               return DropdownMenuItem<String>(
                 value: value,
                 child: Text(value),
               );
             }).toList(),
             onChanged: (value) {
               setState(() {
                 _selectedQuan = value;
                 _selectedSizeQuan = null;
               });
             },
           ),

           if (_selectedQuan != null) ...[
             SizedBox(height: 8),
             DropdownButtonFormField<String>(
               value: _selectedSizeQuan,
               decoration: InputDecoration(
                 labelText: 'Size quần',
                 border: OutlineInputBorder(),
               ),
               items: _getSizeQuanOptions().map((String value) {
                 return DropdownMenuItem<String>(
                   value: value,
                   child: Text(value),
                 );
               }).toList(),
               onChanged: (value) {
                 setState(() {
                   _selectedSizeQuan = value;
                 });
               },
             ),
           ],

           SizedBox(height: 16),

           DropdownButtonFormField<String>(
             value: _selectedGiay,
             decoration: InputDecoration(
               labelText: 'Giày',
               border: OutlineInputBorder(),
             ),
             items: _getGiayOptions(gioiTinh).map((String value) {
               return DropdownMenuItem<String>(
                 value: value,
                 child: Text(value),
               );
             }).toList(),
             onChanged: (value) {
               setState(() {
                 _selectedGiay = value;
                 _selectedSizeGiay = null;
               });
             },
           ),

           if (_selectedGiay != null) ...[
             SizedBox(height: 8),
             DropdownButtonFormField<String>(
               value: _selectedSizeGiay,
               decoration: InputDecoration(
                 labelText: 'Size giày',
                 border: OutlineInputBorder(),
               ),
               items: _getSizeGiayOptions(gioiTinh, _selectedGiay!).map((String value) {
                 return DropdownMenuItem<String>(
                   value: value,
                   child: Text(value),
                 );
               }).toList(),
               onChanged: (value) {
                 setState(() {
                   _selectedSizeGiay = value;
                 });
               },
             ),
           ],

           SizedBox(height: 16),

           DropdownButtonFormField<String>(
             value: _selectedLoaiKhac,
             decoration: InputDecoration(
               labelText: 'Loại khác',
               border: OutlineInputBorder(),
             ),
             items: _getLoaiKhacOptions(gioiTinh).map((String value) {
               return DropdownMenuItem<String>(
                 value: value,
                 child: Text(value),
               );
             }).toList(),
             onChanged: (value) {
               setState(() {
                 _selectedLoaiKhac = value;
                 _selectedSizeKhac = null;
               });
             },
           ),

           if (_selectedLoaiKhac != null) ...[
             SizedBox(height: 8),
             DropdownButtonFormField<String>(
               value: _selectedSizeKhac,
               decoration: InputDecoration(
                 labelText: 'Size loại khác',
                 border: OutlineInputBorder(),
               ),
               items: _getSizeKhacOptions(gioiTinh, _selectedLoaiKhac!).map((String value) {
                 return DropdownMenuItem<String>(
                   value: value,
                   child: Text(value),
                 );
               }).toList(),
               onChanged: (value) {
                 setState(() {
                   _selectedSizeKhac = value;
                 });
               },
             ),
           ],

           SizedBox(height: 16),
           TextField(
             controller: _ghiChuController,
             decoration: InputDecoration(
               labelText: 'Ghi chú',
               border: OutlineInputBorder(),
             ),
             maxLines: 3,
           ),

           SizedBox(height: 24),
           SizedBox(
             width: double.infinity,
             child: ElevatedButton(
               style: ElevatedButton.styleFrom(
                 backgroundColor: const Color.fromARGB(255, 0, 204, 34),
                 foregroundColor: Colors.white,
               ),
               onPressed: _saveItem,
               child: Text(_isPreparationOrder 
                 ? 'Lưu (${_orderAmount} đơn)' 
                 : 'Lưu'),
             ),
           ),
         ],
       ],
     ),
   ),
 );
}
}
class EditOrderDialog extends StatefulWidget {
  final DongPhucModel order;
  final VoidCallback onUpdate;

  const EditOrderDialog({
    required this.order,
    required this.onUpdate,
  });

  @override
  _EditOrderDialogState createState() => _EditOrderDialogState();
}

class _EditOrderDialogState extends State<EditOrderDialog> {
 final List<String> _phanLoaiOptions = ['Thay thế', 'Cấp mới'];
 String? _selectedPhanLoai;
 DateTime? _selectedDate;
 bool _isSubmitting = false;

 @override
 void initState() {
   super.initState();
   _selectedPhanLoai = widget.order.phanLoai; 
   _selectedDate = widget.order.thoiGianNhan;
 }

 DateTime get _minDate => DateTime(DateTime.now().year, DateTime.now().month, 1);
 
 DateTime get _maxDate {
   final now = DateTime.now();
   final lastDay = DateTime(now.year, now.month + 4, 0);
   return lastDay;
 }

 Future<void> _updateOrder() async {
   if (_selectedPhanLoai == null || _selectedDate == null) {
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')));
     return;
   }

   setState(() => _isSubmitting = true);

   try {
     final updatedOrder = DongPhucModel(
       uid: widget.order.uid,
       nguoiDung: widget.order.nguoiDung,
       boPhan: widget.order.boPhan,
       phanLoai: _selectedPhanLoai!,
       thoiGianNhan: DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day),
       trangThai: widget.order.trangThai,
       thang: widget.order.thang,
       xuLy: widget.order.xuLy,
     );

     final response = await AuthenticatedHttpClient.post(
       Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/dongphuccapnhat'),
       headers: {'Content-Type': 'application/json'},
       body: json.encode(updatedOrder.toMap()),
     );

     if (response.statusCode == 200) {
       final dbHelper = DBHelper();
       await dbHelper.update(
         DatabaseTables.dongPhucTable,
         updatedOrder.toMap(),
         where: 'UID = ?',
         whereArgs: [widget.order.uid],
       );
       Navigator.pop(context, true);
     } else {
       throw Exception('Server returned ${response.statusCode}');
     }
   } catch (e) {
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi cập nhật: $e')));
   } finally {
     setState(() => _isSubmitting = false);
   }
 }

 @override
 Widget build(BuildContext context) {
   return Dialog(
     child: SingleChildScrollView(
       padding: EdgeInsets.all(16.0),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         mainAxisSize: MainAxisSize.min,
         children: [
           Text('Sửa đơn hàng', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
           SizedBox(height: 16),
           Card(
             child: Padding(
               padding: EdgeInsets.all(16.0),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text('Thông tin cơ bản', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   SizedBox(height: 16),
                   Text('Người đặt: ${widget.order.nguoiDung}'),
                   Text('Bộ phận: ${widget.order.boPhan}'),
                   Text('Trạng thái: ${widget.order.trangThai}'),
                   Text('Xử lý: ${widget.order.xuLy}'),
                 ],
               ),
             ),
           ),
           SizedBox(height: 16),
           DropdownButtonFormField<String>(
             value: _selectedPhanLoai,
             decoration: InputDecoration(labelText: 'Phân loại', border: OutlineInputBorder()),
             items: _phanLoaiOptions.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
             onChanged: (value) => setState(() => _selectedPhanLoai = value),
           ),
           SizedBox(height: 16),
           InkWell(
             onTap: () async {
               final picked = await showDatePicker(
                 context: context,
                 initialDate: _selectedDate ?? DateTime.now(),
                 firstDate: _minDate,
                 lastDate: _maxDate,
               );
               if (picked != null) setState(() => _selectedDate = picked);
             },
             child: InputDecorator(
               decoration: InputDecoration(labelText: 'Thời gian nhận', border: OutlineInputBorder()),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text(_selectedDate != null ? DateFormat('dd/MM/yyyy').format(_selectedDate!) : 'Chọn ngày'),
                   Icon(Icons.calendar_today),
                 ],
               ),
             ),
           ),
           SizedBox(height: 32),
           SizedBox(
             width: double.infinity,
             child: ElevatedButton(
               style: ElevatedButton.styleFrom(
                 backgroundColor: const Color.fromARGB(255, 0, 204, 34),
                 foregroundColor: Colors.white,
                 padding: EdgeInsets.symmetric(vertical: 16),
               ),
               onPressed: _isSubmitting ? null : _updateOrder,
               child: _isSubmitting
                   ? SizedBox(
                       height: 20,
                       width: 20,
                       child: CircularProgressIndicator(
                         strokeWidth: 2,
                         valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                       ),
                     )
                   : Text('Cập nhật'),
             ),
           ),
         ],
       ),
     ),
   );
 }
}