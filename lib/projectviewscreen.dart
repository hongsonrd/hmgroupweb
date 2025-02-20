import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:http/http.dart' as http;
import 'user_credentials.dart';
import 'package:provider/provider.dart';
import 'dart:convert'; 
import 'package:intl/intl.dart';
import 'http_client.dart';

class ProjectViewScreen extends StatefulWidget {
  final String? selectedDate;
  final String? selectedBoPhan;

  const ProjectViewScreen({
    Key? key,
    required this.selectedDate,
    required this.selectedBoPhan,
  }) : super(key: key);

  @override
  _ProjectViewScreenState createState() => _ProjectViewScreenState();
}

class _ProjectViewScreenState extends State<ProjectViewScreen> with SingleTickerProviderStateMixin {
  final dbHelper = DBHelper();
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  late TabController _tabController;
  List<Map<String, dynamic>> _taskHistory = [];
  List<Map<String, dynamic>> _staffList = [];
  Map<String, Map<String, dynamic>> _staffBioData = {};
  Map<String, Map<String, dynamic>> _latestVTHistory = {};
  String? _selectedPhanLoai;
  bool _showProblemsOnly = false;
  bool _isLoading = true;
  List<String> _chuDeList = ['Chất lượng', 'Nhân sự', 'Vật tư', 'Máy móc', 'An toàn', 'Khác'];
List<String> _giamSatList = [];
Map<String, List<String>> _cachedGiamSatList = {};
String? _selectedBoPhanForInteraction;

  @override
void initState() {
  super.initState();
  _tabController = TabController(length: 3, vsync: this);
  _loadAllData();
  if (widget.selectedBoPhan != 'Tất cả') {
    _fetchGiamSatList(widget.selectedBoPhan!);
  }
}

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
  setState(() => _isLoading = true);
  try {
    await _loadStaffList();
    await _loadStaffBioData();
    await Future.wait([
      _loadTaskHistory(),
      _loadVTHistory(),
    ]);
    
    setState(() => _isLoading = false);
  } catch (e) {
    print('Error loading data: $e');
    setState(() => _isLoading = false);
  }
}

  Future<void> _loadTaskHistory() async {
    final db = await dbHelper.database;
    String query = '''
      SELECT 
        t.*,
        s.Ho_ten as StaffName,
        s.MaNV as StaffCode,
        p.BoPhan as ProjectName
      FROM ${DatabaseTables.taskHistoryTable} t
      LEFT JOIN ${DatabaseTables.staffbioTable} s ON t.NguoiDung = s.UID
      LEFT JOIN ${DatabaseTables.projectListTable} p ON t.BoPhan = p.MaBP
      WHERE date(t.Ngay) = ?
    ''';
    List<dynamic> args = [widget.selectedDate];

    if (widget.selectedBoPhan != 'Tất cả') {
      query += ' AND t.BoPhan = ?';
      args.add(widget.selectedBoPhan);
    }

    query += ' ORDER BY t.Ngay DESC, t.Gio DESC';
    _taskHistory = await db.rawQuery(query, args);
  }

  Future<void> _loadStaffList() async {
  try {
    final db = await dbHelper.database;
    String query = '''
      SELECT s.*, p.BoPhan as ProjectName 
      FROM ${DatabaseTables.staffListTable} s
      LEFT JOIN ${DatabaseTables.projectListTable} p ON s.BoPhan = p.MaBP
    ''';
    if (widget.selectedBoPhan != 'Tất cả') {
      query += ' WHERE s.BoPhan = ?';
      _staffList = await db.rawQuery(query, [widget.selectedBoPhan]);
    } else {
      _staffList = await db.rawQuery(query);
    }
    print('Loaded ${_staffList.length} staff members');
  } catch (e) {
    print('Error loading staff list: $e');
    _staffList = [];
  }
}

Future<void> _loadStaffBioData() async {
  try {
    final db = await dbHelper.database;
    
    // Get all staffbio entries first and create a map for quick lookup
    final staffbioList = await db.query(DatabaseTables.staffbioTable);
    
    for (var staffBio in staffbioList) {
      if (staffBio['MaNV'] != null) {
        _staffBioData[staffBio['MaNV'].toString()] = staffBio;
      }
    }
    
    print('Loaded ${_staffBioData.length} staffbio records');
    
    // Debug: Print a few sample mappings
    _staffBioData.entries.take(3).forEach((entry) {
      print('StaffBio mapping - MaNV: ${entry.key}, Name: ${entry.value['Ho_ten']}');
    });

  } catch (e) {
    print('Error loading staffbio data: $e');
  }
}
Future<void> _loadVTHistory() async {
  _latestVTHistory.clear();
  print('Starting VT History load for ${_staffList.length} staff members');
  
  for (var staff in _staffList) {
    if (staff['MaNV'] != null && staff['BoPhan'] != null) {
      print('Querying VT History for staff: ${staff['MaNV']} at ${staff['BoPhan']}');
      
      // First verify if there are any records for this staff
      final countCheck = await dbHelper.rawQuery('''
        SELECT COUNT(*) as count 
        FROM ${DatabaseTables.vtHistoryTable}
        WHERE NhanVien = ?
      ''', [staff['MaNV']]);
      
      print('Found ${countCheck.first['count']} records for ${staff['MaNV']}');

      final vtHistory = await dbHelper.rawQuery('''
        SELECT * FROM ${DatabaseTables.vtHistoryTable}
        WHERE NhanVien = ? AND BoPhan = ?
        ORDER BY Ngay DESC, Gio DESC
        LIMIT 1
      ''', [staff['MaNV'], staff['BoPhan']]);

      if (vtHistory.isNotEmpty) {
        _latestVTHistory[staff['MaNV']] = vtHistory.first;
        print('Added VT History for ${staff['MaNV']}: ${vtHistory.first['TrangThai']}');
      } else {
        print('No VT History found for ${staff['MaNV']}');
      }
    }
  }
  
  print('Finished loading VT History. Total records: ${_latestVTHistory.length}');
}
  Widget _buildReportListTab() {
    Set<String> phanLoaiOptions = _taskHistory
        .where((task) => task['PhanLoai'] != null)
        .map((task) => task['PhanLoai'].toString())
        .toSet();

    List<Map<String, dynamic>> filteredTasks = _taskHistory.where((task) {
      bool matchesPhanLoai = _selectedPhanLoai == null || 
                           task['PhanLoai'] == _selectedPhanLoai;
      bool matchesProblemFilter = !_showProblemsOnly || 
                                task['KetQua'] != '✔️';
      return matchesPhanLoai && matchesProblemFilter;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Phân loại',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedPhanLoai,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text('Tất cả'),
                    ),
                    ...phanLoaiOptions.map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedPhanLoai = value);
                  },
                ),
              ),
              SizedBox(width: 16),
              FilterChip(
                label: Text('Chỉ hiện vấn đề'),
                selected: _showProblemsOnly,
                onSelected: (value) {
                  setState(() => _showProblemsOnly = value);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: filteredTasks.length,
            itemBuilder: (context, index) {
              final task = filteredTasks[index];
              return Card(
                margin: EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  title: Row(
                    children: [
                      Icon(
                        task['KetQua'] == '✔️'
                            ? Icons.check_circle
                            : Icons.warning,
                        color: task['KetQua'] == '✔️'
                            ? Colors.green
                            : Colors.orange,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task['ProjectName'] ?? task['BoPhan'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              task['ChiTiet'] ?? 'No details',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${task['StaffName'] ?? task['NguoiDung']} - ${task['Gio']}',
                    style: TextStyle(fontSize: 12),
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (task['ChiTiet2'] != null)
                            Text('Chi tiết bổ sung: ${task['ChiTiet2']}'),
                          if (task['PhanLoai'] != null)
                            Text('Phân loại: ${task['PhanLoai']}'),
                          if (task['GiaiPhap'] != null)
                            Text('Giải pháp: ${task['GiaiPhap']}'),
                          SizedBox(height: 8),
                          Text(
                            'Vị trí: ${task['ViTri'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
Color _getStatusColor(int sufficient, int total) {
  final percentage = (sufficient / total) * 100;
  if (percentage >= 90) return const Color.fromARGB(255, 210, 235, 255);
  if (percentage >= 75) return const Color.fromARGB(255, 255, 236, 207);
  return const Color.fromARGB(255, 255, 210, 207);
}
  Widget _buildStaffListTab() {
  print('Building staff list tab with ${_staffList.length} staff members');
  
  // Group staff by project
  Map<String, List<Map<String, dynamic>>> staffByProject = {};
  for (var staff in _staffList) {
    final project = staff['ProjectName'] ?? staff['BoPhan'] ?? 'Unknown';
    staffByProject.putIfAbsent(project, () => []).add(staff);
  }
  
  // Sort projects alphabetically
  final sortedProjects = staffByProject.keys.toList()..sort();
  
  return ListView.builder(
    padding: EdgeInsets.all(16),
    itemCount: sortedProjects.length,
    itemBuilder: (context, projectIndex) {
      final project = sortedProjects[projectIndex];
      final projectStaff = staffByProject[project]!;

      return Card(
        margin: EdgeInsets.only(bottom: 8),
        child: ExpansionTile(
          title: Row(
  children: [
    Expanded(
      child: Text(
        project,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(
          projectStaff.where((staff) => 
            _latestVTHistory[staff['MaNV']]?['TrangThai'] == 'Đang làm việc'
          ).length,
          projectStaff.length,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            projectStaff.where((staff) => 
              _latestVTHistory[staff['MaNV']]?['TrangThai'] == 'Đang làm việc'
            ).length.toString()+ ' đủ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 0, 0, 0),
            ),
          ),
          Text(
            projectStaff.length.toString()+ ' nhân viên',
            style: TextStyle(
              fontSize: 12,
              color: const Color.fromARGB(179, 0, 0, 0),
            ),
          ),
        ],
      ),
    ),
  ],
),
          children: [
            ListView.builder(
  shrinkWrap: true,
  physics: NeverScrollableScrollPhysics(),
  itemCount: projectStaff.length,
  itemBuilder: (context, staffIndex) {
    final staff = projectStaff[staffIndex];
    final vtHistory = _latestVTHistory[staff['UID']];
    final staffBio = _staffBioData[staff['MaNV']]; // Changed from UID to MaNV
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () {
          print('Staff card tapped: ${staff['MaNV']}'); // Debug print
          _showStaffDetails(staff);
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                child: Text(
                  staff['VT'] ?? 'N/A',
                  style: TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.blue[100],
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staffBio?['Ho_ten'] ?? 'Unknown',  // Only show Ho_ten
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'MNV: ${staff['MaNV'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (vtHistory != null) ...[
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${vtHistory['TrangThai']} - ${vtHistory['Ngay']}',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
)
          ],
        ),
      );
    },
  );
}

  void _showStaffDetails(Map<String, dynamic> staff) {
  final staffBio = _staffBioData[staff['MaNV']];
  if (staffBio == null) {
    print('No staffBio found for MaNV: ${staff['MaNV']}');
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        padding: EdgeInsets.all(16),
        child: ListView(
          controller: controller,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    staffBio['Ho_ten'] ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildInfoSection('Thông tin cơ bản', {
              'Mã NV': staffBio['MaNV'],
              'Chức vụ': staffBio['Chuc_vu'],
              'Vị trí': staff['VT'],
              'Bộ phận': staff['BoPhan'],
              'Ngày vào': staffBio['Ngay_vao'],
              'Loại hình': staffBio['Loai_hinh_lao_dong'],
              'Tình trạng': staffBio['Tinh_trang'],
            }),
            _buildInfoSection('Thông tin cá nhân', {
              'Ngày sinh': staffBio['Ngay_sinh'],
              'Tuổi': staffBio['Tuoi'],
              'Giới tính': staffBio['Gioi_tinh'],
              'CCCD': staffBio['Can_cuoc_cong_dan'],
              'Ngày cấp': staffBio['Ngay_cap'],
              'Nơi cấp': staffBio['Noi_cap'],
              'Điện thoại': staffBio['SDT'],
              'Email': staffBio['Email'],
              'Dân tộc': staffBio['Dan_toc'],
              'Trình độ': staffBio['Trinh_do'],
              'Chuyên ngành': staffBio['Chuyen_nganh'],
            }),
            _buildInfoSection('Thông tin BHXH', {
              'Số BHXH': staffBio['So_BHXH'],
              'Bắt đầu BHXH': staffBio['Bat_dau_tham_gia_BHXH'],
              'Số thẻ BHYT': staffBio['So_the_BHYT'],
              'Số thẻ BH hưu trí': staffBio['So_the_BH_huu_tri'],
            }),
            _buildInfoSection('Thông tin ngân hàng', {
              'Số tài khoản': staffBio['So_tai_khoan'],
              'Ngân hàng': staffBio['Ngan_hang'],
              'MST': staffBio['Ma_so_thue'],
            }),
            _buildInfoSection('Địa chỉ', {
              'Thường trú': staffBio['Thuong_tru'],
              'Liên lạc': staffBio['Dia_chi_lien_lac'],
              'Nguyên quán': staffBio['Nguyen_quan'],
            }),
            _buildInfoSection('Thông tin thêm', {
              'Ghi chú': staffBio['Ghi_chu'],
              'Tình trạng hồ sơ': staffBio['Tinh_trang_ho_so'],
              'Hồ sơ còn thiếu': staffBio['Ho_so_con_thieu'],
              'Quá trình': staffBio['Qua_trinh'],
            }),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildInfoSection(String title, Map<String, dynamic> data) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            ...data.entries.map((entry) => Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${entry.key}: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(entry.value?.toString() ?? 'N/A'),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTab() {
  // Debug: Print the total number of VT History records
  print('Total VT History records: ${_latestVTHistory.length}');

  // Group VT History by Project Name
  Map<String, List<Map<String, dynamic>>> vtHistoryByProject = {};
  
  _latestVTHistory.forEach((staffId, vtRecord) {
    // Find the corresponding staff member to get the project name
    final staff = _staffList.firstWhere(
      (s) => s['MaNV'] == staffId, 
      orElse: () => {}
    );
    
    final projectName = staff['ProjectName'] ?? staff['BoPhan'] ?? 'Unknown Project';
    
    vtHistoryByProject.putIfAbsent(projectName, () => []).add({
      ...vtRecord,
      'StaffName': _staffBioData[staffId]?['Ho_ten'] ?? 'Unknown',
      'StaffCode': staffId,
    });
  });

  // Debug: Print the number of projects and VT History records per project
  print('Number of projects with VT History: ${vtHistoryByProject.length}');
  vtHistoryByProject.forEach((project, records) {
    print('Project: $project, Records: ${records.length}');
  });

  return ListView.builder(
    padding: EdgeInsets.all(16),
    itemCount: vtHistoryByProject.keys.length,
    itemBuilder: (context, index) {
      final projectName = vtHistoryByProject.keys.toList()[index];
      final projectVTRecords = vtHistoryByProject[projectName]!;

      return Card(
        margin: EdgeInsets.only(bottom: 16),
        child: ExpansionTile(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  projectName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${projectVTRecords.length} nhân viên',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: projectVTRecords.length,
              itemBuilder: (context, recordIndex) {
                final vtRecord = projectVTRecords[recordIndex];
                return ListTile(
  title: Text(
    vtRecord['StaffName'] ?? 'Unknown',
    style: TextStyle(fontWeight: FontWeight.bold),
  ),
  subtitle: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Mã NV: ${vtRecord['StaffCode']}'),
      Text('Trạng thái: ${vtRecord['TrangThai']}'),
      Text('Thời gian: ${DateTime.parse(vtRecord['Ngay']).toString().split(' ')[0].split('-').reversed.join('/')} ${vtRecord['Gio']}'),
      if (vtRecord['HoTro'] != null && vtRecord['HoTro'].toString().isNotEmpty)
        Text('Hỗ trợ: ${vtRecord['HoTro']}'),
      if (vtRecord['PhuongAn'] != null && vtRecord['PhuongAn'].toString().isNotEmpty)
        Text('Phương án: ${vtRecord['PhuongAn']}'),
    ],
  ),
  trailing: Icon(
    vtRecord['TrangThai'] == 'Active' 
      ? Icons.check_circle 
      : Icons.warning,
    color: vtRecord['TrangThai'] == 'Active' 
      ? Colors.green 
      : Colors.orange,
  ),
);
              },
            ),
          ],
        ),
      );
    },
  );
}
Future<void> _fetchGiamSatList(String boPhan) async {
  if (_cachedGiamSatList.containsKey(boPhan)) {
    setState(() {
      _giamSatList = _cachedGiamSatList[boPhan]!;
    });
    return;
  }

  try {
    final response = await AuthenticatedHttpClient.get(
      Uri.parse('$baseUrl/gsbp/${Uri.encodeComponent(boPhan)}'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      _cachedGiamSatList[boPhan] = data.map((e) => e.toString()).toList();
      setState(() {
        _giamSatList = _cachedGiamSatList[boPhan]!;
      });
    }
  } catch (e) {
    print('Error fetching giam sat list: $e');
  }
}
Future<List<Map<String, dynamic>>> _loadInteractionHistory() async {
  try {
    final db = await dbHelper.database;
    String query = '''
      SELECT * FROM ${DatabaseTables.interactionTable}
      WHERE date(Ngay) = ?
    ''';
    List<dynamic> args = [widget.selectedDate];

    if (widget.selectedBoPhan != 'Tất cả') {
      query += ' AND BoPhan = ?';
      args.add(widget.selectedBoPhan);
    }

    query += ' ORDER BY Ngay DESC, Gio DESC';
    return await db.rawQuery(query, args);
  } catch (e) {
    print('Error loading interaction history: $e');
    return [];
  }
}

void _showInteractionForm() {
  final TextEditingController noiDungController = TextEditingController();
  String? selectedChuDe;
  String? selectedGiamSat;
  List<Map<String, dynamic>> interactionHistory = [];

  _loadInteractionHistory().then((history) {
    if (mounted) setState(() => interactionHistory = history);
  });

  final List<String> availableProjects = widget.selectedBoPhan == 'Tất cả' 
      ? _staffList
          .map((staff) => staff['ProjectName'] ?? staff['BoPhan'])
          .whereType<String>()
          .toSet()
          .toList()
      : [];

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text('Thêm tương tác mới', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.selectedBoPhan == 'Tất cả') 
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Bộ phận',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedBoPhanForInteraction,
                        items: availableProjects
                            .map((project) => DropdownMenuItem(value: project, child: Text(project)))
                            .toList(),
                        onChanged: (value) async {
                          setState(() => _selectedBoPhanForInteraction = value);
                          if (value != null) await _fetchGiamSatList(value);
                        },
                      ),
                    if (widget.selectedBoPhan == 'Tất cả') SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Chủ đề',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                            value: selectedChuDe,
                            items: _chuDeList.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                            onChanged: (value) => setState(() => selectedChuDe = value),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Giám sát',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                            value: selectedGiamSat,
                            items: _giamSatList.map((gs) => DropdownMenuItem(value: gs, child: Text(gs))).toList(),
                            onChanged: (value) => setState(() => selectedGiamSat = value),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: noiDungController,
                      decoration: InputDecoration(
                        labelText: 'Nội dung',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      maxLines: 2,
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
  final currentBoPhan = widget.selectedBoPhan == 'Tất cả' 
      ? _selectedBoPhanForInteraction 
      : widget.selectedBoPhan;
      
  if (currentBoPhan == null || selectedChuDe == null || 
      noiDungController.text.isEmpty || selectedGiamSat == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Vui lòng điền đầy đủ thông tin'))
    );
    return;
  }

  final userCredentials = Provider.of<UserCredentials>(context, listen: false);
  final now = DateTime.now();
  
  try {
    final response = await AuthenticatedHttpClient.post(
      Uri.parse('$baseUrl/tuongtacmoi'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'Ngay': DateFormat('yyyy-MM-dd').format(now),  // Format the date properly
        'Gio': DateFormat('HH:mm').format(now),        // Format the time properly
        'NguoiDung': userCredentials.username,
        'BoPhan': currentBoPhan,
        'NoiDung': noiDungController.text,
        'ChuDe': selectedChuDe,
        'GiamSat': selectedGiamSat,
        'PhanLoai': 'ready'
      }),
    );

    if (response.statusCode == 200) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm tương tác mới'))
      );
    } else {
      throw Exception('Failed to add interaction: ${response.body}');
    }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi: ${e.toString()}'))
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[100],
                        minimumSize: Size(double.infinity, 40),
                      ),
                      child: Text('Lưu tương tác'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lịch sử tương tác', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: interactionHistory.length,
                          itemBuilder: (context, index) {
                            final interaction = interactionHistory[index];
                            return Card(
                              margin: EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(interaction['NoiDung'] ?? ''),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${interaction['ChuDe']} - ${interaction['GiamSat']}'),
                                    Text('${interaction['Ngay']} ${interaction['Gio']}'),
                                  ],
                                ),
                                trailing: Text(
                                  interaction['PhanLoai'] ?? '',
                                  style: TextStyle(
                                    color: interaction['PhanLoai'] == 'ready' ? Colors.orange : Colors.green,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
  @override 
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Chi tiết ${widget.selectedBoPhan}',
              style: TextStyle(
                fontWeight: FontWeight.bold, 
              ),
            ),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.add_comment),
            label: Text('Tương tác'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.purple,
            ),
            onPressed: _showInteractionForm,
          ),
        ],
      ),
      bottom: TabBar(
        controller: _tabController,
        tabs: [
          Tab(icon: Icon(Icons.assignment), text: 'Kết quả báo cáo'),
          Tab(icon: Icon(Icons.people), text: 'Danh sách CN'), 
          Tab(icon: Icon(Icons.analytics), text: 'Báo cáo CN'),
        ],
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 251, 240, 255),
              Color.fromARGB(255, 239, 201, 255),
              Color.fromARGB(255, 255, 250, 255),
              Color.fromARGB(255, 246, 215, 249),
            ],
          ),
        ),
      ),
    ),
    body: _isLoading
        ? Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildReportListTab(),
              _buildStaffListTab(),
              _buildReportTab(),
            ],
          ),
  );
}
}