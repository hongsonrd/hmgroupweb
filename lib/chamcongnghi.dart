import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'http_client.dart';

enum ChamCongScreenType { vang, nghi, tangCa }

class ChamCongNghiScreen extends StatefulWidget {
  final String username;
  final String userRole;
  final String approverUsername;
  final ChamCongScreenType screenType;

  const ChamCongNghiScreen({
    Key? key,
    required this.username,
    required this.userRole,
    required this.approverUsername,
    this.screenType = ChamCongScreenType.nghi,
  }) : super(key: key);

  @override
  _ChamCongNghiScreenState createState() => _ChamCongNghiScreenState();
}

class _ChamCongNghiScreenState extends State<ChamCongNghiScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DBHelper _dbHelper = DBHelper();
  List<ChamCongVangNghiTcaModel> _myRecords = [];
  List<ChamCongVangNghiTcaModel> _approvalRecords = [];
  List<String> _userList = [];
  String? _selectedUser;
  String? _selectedMonth;
  List<String> _monthOptions = [];
  bool _isLoading = true;
  String? _fetchedUserRole;
  // Different TruongHop options based on screen type
  late List<String> _truongHopOptions;
  
  // Get screen title based on screen type
  String get screenTitle {
    switch (widget.screenType) {
      case ChamCongScreenType.vang:
        return 'Báo vắng';
      case ChamCongScreenType.nghi:
        return 'Báo nghỉ';
      case ChamCongScreenType.tangCa:
        return 'Báo tăng ca';
    }
  }
  
  // Get PhanLoai value based on screen type
  String get phanLoaiValue {
    switch (widget.screenType) {
      case ChamCongScreenType.vang:
        return 'Vắng';
      case ChamCongScreenType.nghi:
        return 'Nghỉ';
      case ChamCongScreenType.tangCa:
        return 'Tăng ca';
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupMonthOptions();
    // Set truongHop options based on screen type
    _setupTruongHopOptions();
    _loadData();
    _fetchUserRoleIfNeeded();
  }
  Future<void> _fetchUserRoleIfNeeded() async {
  print('Starting _fetchUserRoleIfNeeded');
  print('Initial widget.userRole: ${widget.userRole}');
  print('Initial widget.username: ${widget.username}');

  if (widget.userRole.isEmpty || widget.userRole == null) {
    try {
      final url = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/myrole/${widget.username}');
      print('Fetching role from URL: $url');

      final response = await AuthenticatedHttpClient.get(url);
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final fetchedRole = response.body.trim();
        print('Fetched role: $fetchedRole');
        
        setState(() {
          _fetchedUserRole = fetchedRole;
        });
      } else {
        print('Failed to fetch user role: ${response.statusCode}');
        print('Response body: ${response.body}');
        _fetchedUserRole = 'HM-RD';
      }
    } catch (e) {
      print('Error fetching user role: $e');
      _fetchedUserRole = 'HM-RD';
    }
  } else {
    print('User role already provided: ${widget.userRole}');
    _fetchedUserRole = widget.userRole;
  }

  print('Final _fetchedUserRole: $_fetchedUserRole');
}
  String get effectiveUserRole => _fetchedUserRole ?? widget.userRole ?? 'unknown';
  void _setupTruongHopOptions() {
    switch (widget.screenType) {
      case ChamCongScreenType.vang:
        _truongHopOptions = ['Vắng sáng', 'Vắng chiều', 'Vắng cả ngày'];
        break;
      case ChamCongScreenType.nghi:
        _truongHopOptions = ['Nghỉ phép','Nghỉ phép 1/2 ngày', 'Nghỉ ốm', 'Nghỉ không lương', 'Nghỉ bù'];
        break;
      case ChamCongScreenType.tangCa:
        _truongHopOptions = ['Tăng ca thường', 'Tăng ca cuối tuần', 'Tăng ca lễ', 'Khác'];
        break;
    }
  }
void _setGiaTriNgayBasedOnTruongHop(String? truongHop, StateSetter setState, double giaTriNgay) {
  if (truongHop == null) return;
  
  double newValue = giaTriNgay;
  
  // For Vắng
  if (truongHop == 'Vắng sáng' || truongHop == 'Vắng chiều') {
    newValue = 0.5;
  } else if (truongHop == 'Vắng cả ngày') {
    newValue = 1.0;
  }
  
  // For Nghỉ
  else if (truongHop == 'Nghỉ phép' || truongHop == 'Nghỉ bù') {
    newValue = 1.0;
  } else if (truongHop == 'Nghỉ phép 1/2 ngày') {
    newValue = 0.5;
  } else if (truongHop == 'Nghỉ ốm' || truongHop == 'Nghỉ không lương') {
    newValue = 0.0;
  }
  
  // Update the state with the new value
  setState(() {
    giaTriNgay = newValue;
  });
}
  void _setupMonthOptions() {
    // Generate month options (current month and previous 11 months)
    final DateFormat monthFormat = DateFormat('yyyy-MM');
    final now = DateTime.now();
    
    for (int i = 0; i < 12; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      final formattedMonth = monthFormat.format(month);
      _monthOptions.add(formattedMonth);
    }
    
    // Set current month as default selection
    _selectedMonth = _monthOptions.first;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get all records
      final allRecords = await _dbHelper.getAllChamCongVangNghiTca();
      print('Total records in database: ${allRecords.length}');
      
      // Apply PhanLoai filter based on screen type
      final filteredByTypeRecords = allRecords.where((record) => record.phanLoai == phanLoaiValue).toList();
      print('Records with PhanLoai "$phanLoaiValue": ${filteredByTypeRecords.length}');
      
      // Filter records based on selected month (if any)
      final filteredRecords = _selectedMonth != null 
          ? _filterRecordsByMonth(filteredByTypeRecords, _selectedMonth!)
          : filteredByTypeRecords;
      
      // Filter records based on selected user (if any)
      final userFilteredRecords = _selectedUser != null
          ? filteredRecords.where((record) => record.nguoiDung == _selectedUser).toList()
          : filteredRecords;
      
      // Split records into "my records" and "approval records"
      final myRecords = userFilteredRecords.where(
        (record) => record.nguoiDung == widget.username
      ).toList();
      
      final approvalRecords = userFilteredRecords.where(
        (record) => record.nguoiDuyet == widget.username
      ).toList();
      
      print('After filtering:');
      print('My records: ${myRecords.length}');
      print('Approval records: ${approvalRecords.length}');
      
      // Get unique users for dropdown
      final Set<String> uniqueUsers = {};
      for (var record in allRecords) {
        if (record.nguoiDung?.isNotEmpty == true) {
          uniqueUsers.add(record.nguoiDung!);
        }
      }
      
      setState(() {
        _myRecords = myRecords;
        _approvalRecords = approvalRecords;
        _userList = uniqueUsers.toList()..sort();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading data: $e');
    }
  }

  List<ChamCongVangNghiTcaModel> _filterRecordsByMonth(List<ChamCongVangNghiTcaModel> records, String monthStr) {
    return records.where((record) {
      // Check if the record dates fall within the selected month
      if (record.ngayBatDau != null) {
        final startMonth = DateFormat('yyyy-MM').format(record.ngayBatDau!);
        return startMonth == monthStr;
      }
      return false;
    }).toList();
  }
DateTimeRange _getCurrentMonthRange() {
  final now = DateTime.now();
  final firstDayOfMonth = DateTime(now.year, now.month, 1);
  final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
  return DateTimeRange(start: firstDayOfMonth, end: lastDayOfMonth);
}
  Future<void> _showAddNewEntryDialog() async {
  final TextEditingController noteController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  String? truongHop;
  final monthRange = _getCurrentMonthRange();

  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Tạo ${screenTitle.toLowerCase()} mới'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ngày bắt đầu'),
                  ListTile(
                    title: Text(
                      startDate == null ? 'Chọn ngày' : DateFormat('dd/MM/yyyy').format(startDate!),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().isAfter(monthRange.end) ? monthRange.end : DateTime.now(),
                        firstDate: monthRange.start,
                        lastDate: monthRange.end,
                      );
                      if (selected != null) {
                        setState(() {
                          startDate = selected;
                          if (endDate == null || endDate!.isBefore(startDate!) || endDate!.isAfter(monthRange.end)) {
                            endDate = startDate;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Ngày kết thúc'),
                  ListTile(
                    title: Text(
                      endDate == null ? 'Chọn ngày' : DateFormat('dd/MM/yyyy').format(endDate!),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      if (startDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng chọn ngày bắt đầu trước'))
                        );
                        return;
                      }
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? startDate!,
                        firstDate: startDate!,
                        lastDate: monthRange.end,
                      );
                      if (selected != null) {
                        setState(() {
                          endDate = selected;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Trường hợp'),
                  DropdownButtonFormField<String>(
                    value: truongHop,
                    hint: const Text('Chọn trường hợp'),
                    items: _truongHopOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        truongHop = newValue;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Ghi chú'),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      hintText: 'Nhập ghi chú (nếu có)',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (startDate == null || endDate == null || truongHop == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin'))
                    );
                    return;
                  }
                  _saveNewEntry(
                    startDate!,
                    endDate!,
                    truongHop!,
                    noteController.text,
                    0.0, // Default value, will be overridden in _saveNewEntry
                  );
                  Navigator.pop(context);
                },
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<bool> _syncWithServer(String method, String endpoint, {Map<String, dynamic>? data, String? id}) async {
  try {
    final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
    final url = id != null 
        ? Uri.parse('$baseUrl/$endpoint/$id') 
        : Uri.parse('$baseUrl/$endpoint');
    
    http.Response response;
    
    switch (method.toUpperCase()) {
      case 'POST':
        response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(data),
        );
        break;
      case 'PUT':
        response = await http.put(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(data),
        );
        break;
      case 'DELETE':
        response = await http.delete(url);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      print('Server sync successful for $method $endpoint ${id ?? ""}');
      return true;
    } else {
      print('Server sync failed with status ${response.statusCode}: ${response.body}');
      return false;
    }
  } catch (e) {
    print('Error syncing with server: $e');
    return false;
  }
}
String _determineApprover(String userRole) {
  print('Determining approver for role: $userRole');
  
  final normalizedRole = userRole.toUpperCase().trim();
  print('Normalized role: $normalizedRole');

  String initialApprover;
  switch (normalizedRole) {
    case 'HM-RD':
      initialApprover = 'hm.tason';
      break;
    case 'HM-CSKH':
      initialApprover = 'hm.tranminh'; 
      break;
    case 'HM-HS':
      initialApprover = 'hm.luukinh';
      break;
    case 'HM-KS':
      initialApprover = 'hm.trangiang';
      break;
    case 'HM-DV':
      initialApprover = 'hm.hahuong'; 
      break;
    case 'HM-KH':
      initialApprover = 'hm.phamthuy';
      break;
    case 'HM-DVV':
      initialApprover = 'hm.daotan';
      break;
    case 'HM-DL':
      initialApprover = 'hm.daotan'; 
      break;
    case 'HM-QA':
      initialApprover = 'hm.vuquyen';
      break;
    case 'HM-HCM2':
      initialApprover = 'hm.damlinh';
      break;
    case 'HM-TEST':
      initialApprover = 'BPthunghiem'; 
      break;
    case 'HM-KY':
      initialApprover = 'hm.duongloan';
      break;
    case 'HM-NS':
      initialApprover = 'hm.nguyengiang';
      break;
    case 'HM-KT':
      initialApprover = 'hm.luukinh'; 
      break;
    case 'HM-DA':
      initialApprover = 'hm.lehang';
      break;
    case 'HM-SX':
      initialApprover = 'hm.anhmanh';
      break;
    case 'HM-DN2':
      initialApprover = 'hm.nguyenhien'; 
      break;
    case 'HM-DN':
      initialApprover = 'hm.doannga';
      break;
    case 'HM-LX':
      initialApprover = 'hm.daotan';
      break;
    case 'HM-HSDN':
      initialApprover = 'hm.trangiang'; 
      break;
    case 'HM-HSNT':
      initialApprover = 'hm.trangiang';
      break;
    case 'DV-Loi':
      initialApprover = 'hm.phamloi';
      break;
    case 'DV-NHuyen':
      initialApprover = 'hm.nguyenhuyen'; 
      break;
    case 'DV-HThanh':
      initialApprover = 'hm.hanthanh';
      break;
    case 'DV-Hanh':
      initialApprover = 'hm.nguyenhanh';
      break;
    case 'DV-Hung':
      initialApprover = 'hm.nguyenhung'; 
      break;
    case 'DV-BHuyen':
      initialApprover = 'hm.buihuyen';
      break;
    case 'DV-Huong':
      initialApprover = 'hm.hahuong'; 
      break;
    case 'DV-NThanh':
      initialApprover = 'hm.ngothanh';
      break;
    case 'HM-HCM':
      initialApprover = 'hm.damlinh';
      break;
    case 'HM-TT':
      initialApprover = 'hm.vuquyen'; 
      break;
    case 'HM-TD':
      initialApprover = 'hm.tranhanh';
      break;
    case 'HM-MKT':
      initialApprover = 'hm.daotan';
      break;
    case 'HM-LC':
      initialApprover = 'hm.lethihoa'; 
      break;
    case 'DV-HaiAnh':
      initialApprover = 'haianh';
      break;
    case 'ADMIN':
      initialApprover = widget.username;
      break;
    default:
      initialApprover = widget.approverUsername.isNotEmpty 
        ? widget.approverUsername 
        : 'nvthunghiem';
  }
  // If the initial approver is the same as the current user, find an alternative
  String finalApprover = initialApprover;
  if (initialApprover == widget.username) {
    switch (normalizedRole) {
      case 'HM-RD':
        finalApprover = 'hm.luukinh';
        break;
      case 'HM-CSKH':
        finalApprover = 'hm.luukinh';
        break;
      case 'HM-HS':
        finalApprover = 'hm.luukinh';
        break;
      case 'HM-KS':
        finalApprover = 'hm.luukinh';
        break;
      case 'HM-DV':
        finalApprover = 'hm.luukinh';
        break;
      case 'HM-KH':
        finalApprover = 'hm.luukinh';
        break;
      case 'HM-DVV':
        finalApprover = 'hm.luukinh';
        break;
      case 'HM-QA':
        finalApprover = 'hm.luukinh';
        break;
      case 'HM-KY':
        finalApprover = 'hm.luukinh';
        break;
      case 'HM-KT':
        finalApprover = 'hm.luukinh';
        break;
      case 'HM-TT':
        finalApprover = 'hm.luukinh';
        break;
      case 'HM-TD':
        finalApprover = 'hm.luukinh';
        break;
      case 'HM-MKT':
        finalApprover = 'hm.luukinh';
        break;
      default:
        finalApprover = 'hm.nguyengiang';
    }
  }
  print('Initial approver: $initialApprover');
  print('Final approver: $finalApprover');
  return finalApprover;
}
double _calculateGiaTriNgay(String? truongHop) {
  if (truongHop == null) return 1.0; // Default value
  
  // For Vắng
  if (truongHop == 'Vắng sáng' || truongHop == 'Vắng chiều') {
    return 0.5;
  } else if (truongHop == 'Vắng cả ngày') {
    return 1.0;
  }
  
  // For Nghỉ
  else if (truongHop == 'Nghỉ phép' || truongHop == 'Nghỉ bù') {
    return 1.0;
  } else if (truongHop == 'Nghỉ phép 1/2 ngày') {
    return 0.5;
  } else if (truongHop == 'Nghỉ ốm' || truongHop == 'Nghỉ không lương') {
    return 0.0;
  }
  
  return 1.0;
}
  Future<void> _saveNewEntry(
  DateTime startDate,
  DateTime endDate,
  String truongHop,
  String ghiChu,
  double giaTriNgay, // This will be ignored for Tăng ca
) async {
  try {
    // Generate a unique ID
    final uid = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Determine the approver based on effective userRole
    final String determinedApprover = _determineApprover(effectiveUserRole);
    
    // Calculate GiaTriNgay based on PhanLoai and TruongHop
    double calculatedGiaTriNgay;
    if (widget.screenType == ChamCongScreenType.tangCa) {
      calculatedGiaTriNgay = 0.0; // Always 0 for Tăng ca
    } else {
      calculatedGiaTriNgay = _calculateGiaTriNgay(truongHop); // For Vắng or Nghỉ
    }

    final newEntry = ChamCongVangNghiTcaModel(
      uid: uid,
      nguoiDung: widget.username,
      phanLoai: phanLoaiValue,
      ngayBatDau: startDate,
      ngayKetThuc: endDate,
      ghiChu: ghiChu,
      truongHop: truongHop,
      nguoiDuyet: determinedApprover,
      trangThai: 'Chưa xem',
      giaTriNgay: calculatedGiaTriNgay, 
    );
    
    // Server data
    final serverData = {
      'UID': uid,
      'NguoiDung': widget.username,
      'PhanLoai': phanLoaiValue,
      'NgayBatDau': startDate.toIso8601String(),
      'NgayKetThuc': endDate.toIso8601String(),
      'GhiChu': ghiChu,
      'TruongHop': truongHop,
      'NguoiDuyet': determinedApprover,
      'TrangThai': 'Chưa xem',
      'GiaTriNgay': calculatedGiaTriNgay,
    };
    
    bool serverSynced = await _syncWithServer('POST', 'chamconglsphep', data: serverData);
    
    await _dbHelper.insertChamCongVangNghiTca(newEntry);
    _loadData();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(serverSynced 
          ? 'Đã tạo ${screenTitle.toLowerCase()} mới thành công' 
          : 'Đã lưu cục bộ, không thể đồng bộ với máy chủ'),
        backgroundColor: serverSynced ? Colors.green : Colors.orange,
      )
    );
  } catch (e) {
    print('Error saving new entry: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi: $e'))
    );
  }
}

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: Text(screenTitle),
  actions: [
    Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Mới', style: TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        onPressed: _showAddNewEntryDialog,
      ),
    ),
  ],
  bottom: TabBar(
    controller: _tabController,
    tabs: const [
      Tab(text: 'Của tôi'),
      Tab(text: 'Xét duyệt'),
    ],
  ),
),
      body: Column(
        children: [
          // Filter section
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bộ lọc',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // User filter dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Người dùng',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            value: _selectedUser,
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Tất cả'),
                              ),
                              ..._userList.map((String user) {
                                return DropdownMenuItem<String>(
                                  value: user,
                                  child: Text(user),
                                );
                              }).toList(),
                            ],
                            onChanged: (newValue) {
                              setState(() {
                                _selectedUser = newValue;
                              });
                              _loadData();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Month filter dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Tháng',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            value: _selectedMonth,
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Tất cả'),
                              ),
                              ..._monthOptions.map((String month) {
                                return DropdownMenuItem<String>(
                                  value: month,
                                  child: Text(month),
                                );
                              }).toList(),
                            ],
                            onChanged: (newValue) {
                              setState(() {
                                _selectedMonth = newValue;
                              });
                              _loadData();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Tab content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // My records tab
                      _buildRecordsList(_myRecords),
                      
                      // Approval records tab
                      _buildRecordsList(_approvalRecords, isApprovalList: true),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList(List<ChamCongVangNghiTcaModel> records, {bool isApprovalList = false}) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              isApprovalList 
                ? 'Không có ${screenTitle.toLowerCase()} nào cần xét duyệt' 
                : 'Bạn chưa có ${screenTitle.toLowerCase()} nào',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
   
    return ListView.builder(
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        final startDateStr = record.ngayBatDau != null 
            ? DateFormat('dd/MM/yyyy').format(record.ngayBatDau!)
            : 'N/A';
        final endDateStr = record.ngayKetThuc != null 
            ? DateFormat('dd/MM/yyyy').format(record.ngayKetThuc!)
            : 'N/A';
       
        // Calculate total days or hours based on screen type
        String totalValueStr;
        if (widget.screenType == ChamCongScreenType.tangCa) {
          totalValueStr = '${record.giaTriNgay?.toStringAsFixed(1) ?? "0.0"} giờ';
        } else {
          final totalDays = record.ngayBatDau != null && record.ngayKetThuc != null
              ? record.ngayKetThuc!.difference(record.ngayBatDau!).inDays + 1
              : 0;
              
          final double giaTriTotal = totalDays * (record.giaTriNgay ?? 1.0);
          totalValueStr = '${giaTriTotal.toStringAsFixed(1)} ngày';
        }
           
        // Define status color based on TrangThai
        Color statusColor;
        switch (record.trangThai) {
          case 'Chưa xem':
            statusColor = Colors.grey;
            break;
          case 'Đồng ý':
            statusColor = Colors.green;
            break;
          case 'Từ chối':
            statusColor = Colors.red;
            break;
          default:
            statusColor = Colors.grey;
        }
       
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ExpansionTile(
            title: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${startDateStr} - ${endDateStr}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Trường hợp: ${record.truongHop ?? ""}'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tổng: $totalValueStr'),
                    Text(
                      record.trangThai ?? "Chưa xác định",
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Người tạo: ${record.nguoiDung ?? ""}'),
                    const SizedBox(height: 8),
                    Text('Người duyệt: ${record.nguoiDuyet ?? ""}'),
                    const SizedBox(height: 8),
                    //if (record.ghiChu?.isNotEmpty == true) ...[
                      const Text(
  'Ghi chú:',
  style: TextStyle(fontWeight: FontWeight.bold),
),
Container(
  padding: const EdgeInsets.all(8),
  width: double.infinity,
  decoration: BoxDecoration(
    color: Colors.grey[100],
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(record.ghiChu ?? ""),
),
                    //],
                   
                    // Action buttons for the record - only in Xét duyệt tab for records with status "Chưa xem"
                    if (isApprovalList && record.trangThai == 'Chưa xem' && record.uid != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _handleApproval(record.uid!, false),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Từ chối'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _handleApproval(record.uid!, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text('Đồng ý'),
                          ),
                        ],
                      ),
                    ],
                   
                    // Edit/delete buttons for own records with status "Chưa xem"
                    if (!isApprovalList && record.trangThai == 'Chưa xem' && record.uid != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _handleDelete(record.uid!),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Xóa'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _handleEdit(record),
                            child: const Text('Sửa'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleApproval(String uid, bool isApproved) async {
  try {
    final status = isApproved ? 'Đồng ý' : 'Từ chối';
    final serverData = {
      'TrangThai': status,
    };
    bool serverSynced = await _syncWithServer('PUT', 'chamconglsphep', data: serverData, id: uid);
    await _dbHelper.updateChamCongVangNghiTca(uid, {'TrangThai': status});
    _loadData();
     
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(serverSynced
          ? (isApproved 
              ? 'Đã duyệt ${screenTitle.toLowerCase()} và đồng bộ với máy chủ' 
              : 'Đã từ chối ${screenTitle.toLowerCase()} và đồng bộ với máy chủ')
          : (isApproved 
              ? 'Đã duyệt cục bộ, không thể đồng bộ với máy chủ' 
              : 'Đã từ chối cục bộ, không thể đồng bộ với máy chủ')),
        backgroundColor: serverSynced 
          ? (isApproved ? Colors.green : Colors.red) 
          : Colors.orange,
      ),
    );
  } catch (e) {
    print('Error handling approval: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi: $e')),
    );
  }
}

  Future<void> _handleDelete(String uid) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Xác nhận'),
      content: Text('Bạn có chắc chắn muốn xóa ${screenTitle.toLowerCase()} này?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('Xóa'),
        ),
      ],
    ),
  );
 
  if (confirmed == true) {
    try {
      // First sync with server
      bool serverSynced = await _syncWithServer('DELETE', 'chamconglsphep', id: uid);
      
      // Delete from local database regardless of server response
      await _dbHelper.deleteChamCongVangNghiTca(uid);
      
      // Reload data
      _loadData();
     
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(serverSynced 
            ? 'Đã xóa ${screenTitle.toLowerCase()} và đồng bộ với máy chủ'
            : 'Đã xóa cục bộ, không thể đồng bộ với máy chủ'),
          backgroundColor: serverSynced ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      print('Error deleting record: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }
}

  Future<void> _handleEdit(ChamCongVangNghiTcaModel record) async {
    if (record.uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể chỉnh sửa bản ghi không có ID')),
      );
      return;
    }
    
    final TextEditingController noteController = TextEditingController(text: record.ghiChu ?? '');
    DateTime? startDate = record.ngayBatDau;
    DateTime? endDate = record.ngayKetThuc;
    String? truongHop = record.truongHop;
    double giaTriNgay = record.giaTriNgay ?? 1.0;
    
    // For Tăng ca, we need a decimal input
    final TextEditingController giaTriController = TextEditingController(
      text: widget.screenType == ChamCongScreenType.tangCa 
          ? giaTriNgay.toString() 
          : '1.0'
    );
  final monthRange = _getCurrentMonthRange();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Chỉnh sửa ${screenTitle.toLowerCase()}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ngày bắt đầu'),
            ListTile(
              title: Text(
                startDate == null ? 'Chọn ngày' : DateFormat('dd/MM/yyyy').format(startDate!),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: startDate ?? monthRange.start,
                  firstDate: monthRange.start,
                  lastDate: monthRange.end,
                );
                if (selected != null) {
                  setState(() {
                    startDate = selected;
                    if (endDate == null || endDate!.isBefore(startDate!) || endDate!.isAfter(monthRange.end)) {
                      endDate = startDate;
                    }
                  });
                }
              },
            ),
            
            const SizedBox(height: 16),
            const Text('Ngày kết thúc'),
            ListTile(
              title: Text(
                endDate == null ? 'Chọn ngày' : DateFormat('dd/MM/yyyy').format(endDate!),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                if (startDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng chọn ngày bắt đầu trước'))
                  );
                  return;
                }
                
                final selected = await showDatePicker(
                  context: context,
                  initialDate: endDate ?? startDate!,
                  firstDate: startDate!,
                  lastDate: monthRange.end,
                );
                if (selected != null) {
                  setState(() {
                    endDate = selected;
                  });
                }
              },
            ),
                   
                    const SizedBox(height: 16),
                    const Text('Trường hợp'),
                    DropdownButtonFormField<String>(
                      value: truongHop,
                      hint: const Text('Chọn trường hợp'),
                      items: _truongHopOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
  setState(() {
    truongHop = newValue;
  });
  _setGiaTriNgayBasedOnTruongHop(newValue, setState, giaTriNgay);
},
                    ),
                   
                    const SizedBox(height: 16),
                    
                    // Different UI for Giá trị based on screen type
                    if (widget.screenType == ChamCongScreenType.tangCa) ...[
                      const Text('Số giờ tăng ca'),
                      TextField(
                        controller: giaTriController,
                        decoration: const InputDecoration(
                          hintText: 'Nhập số giờ',
                          suffixText: 'giờ',
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          try {
                            giaTriNgay = double.parse(value);
                          } catch (e) {
                            // Handle invalid input
                          }
                        },
                      ),
                    ] else ...[
                      const Text('Giá trị ngày'),
                      Slider(
                        value: giaTriNgay,
                        min: 0.0,
                        max: 1.0,
                        divisions: 2,
                        label: giaTriNgay == 0.5 ? '1/2 ngày' : (giaTriNgay == 0.0 ? '0 ngày' : '1 ngày'),
                        onChanged: (value) {
                          setState(() {
                            giaTriNgay = value;
                          });
                        },
                      ),
                      Center(
                        child: Text(
                          giaTriNgay == 0.5 ? '1/2 ngày' : (giaTriNgay == 0.0 ? '0 ngày' : '1 ngày'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    const Text('Ghi chú'),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        hintText: 'Nhập ghi chú (nếu có)',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (startDate == null || endDate == null || truongHop == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin'))
                      );
                      return;
                    }
                    
                    // For tăng ca, get the value from the text field
                    if (widget.screenType == ChamCongScreenType.tangCa) {
                      try {
                        giaTriNgay = double.parse(giaTriController.text);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập số giờ hợp lệ'))
                        );
                        return;
                      }
                    }
                   
                    _updateEntry(
                      record.uid!,
                      startDate!,
                      endDate!,
                      truongHop!,
                      noteController.text,
                      giaTriNgay,
                    );
                   
                    Navigator.pop(context);
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateEntry(
  String uid,
  DateTime startDate,
  DateTime endDate,
  String truongHop,
  String ghiChu,
  double giaTriNgay,
) async {
  try {
    final updates = {
      'NgayBatDau': startDate.toIso8601String(),
      'NgayKetThuc': endDate.toIso8601String(),
      'TruongHop': truongHop,
      'GhiChu': ghiChu,
      'GiaTriNgay': giaTriNgay,
    };
    
    // First sync with server
    bool serverSynced = await _syncWithServer('PUT', 'chamconglsphep', data: updates, id: uid);
    
    // Update local database regardless of server response
    await _dbHelper.updateChamCongVangNghiTca(uid, updates);
    
    // Reload data
    _loadData();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(serverSynced 
          ? 'Đã cập nhật ${screenTitle.toLowerCase()} thành công' 
          : 'Đã cập nhật cục bộ, không thể đồng bộ với máy chủ'),
        backgroundColor: serverSynced ? Colors.green : Colors.orange,
      )
    );
  } catch (e) {
    print('Error updating entry: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi: $e'))
    );
  }
}
}