import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_credentials.dart';
import 'table_models.dart';
import 'package:table_calendar/table_calendar.dart';
import 'db_helper.dart';
import 'package:intl/intl.dart';
//import 'package:image_picker/image_picker.dart';
//import 'dart:io';
//import 'package:uuid/uuid.dart';
import 'package:uuid/uuid.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'http_client.dart';
import 'package:excel/excel.dart' as xl;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ProjectPlan extends StatefulWidget {
  final String? userType;
  final String? selectedBoPhan;
  final String? selectedDate;
  ProjectPlan({this.selectedDate, this.selectedBoPhan, this.userType});
  @override
  _ProjectPlanState createState() => _ProjectPlanState();
}

class _ProjectPlanState extends State<ProjectPlan> with SingleTickerProviderStateMixin {
  DateTime? _startDate;
DateTime? _endDate;
String? _filterByUser;
  late TabController _tabController;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  List<BaocaoModel> _plans = [];
  Map<DateTime, List<BaocaoModel>> _events = {};
  List<String> _projectList = [];
  List<String> _selectedShare = [];
  final dbHelper = DBHelper();
List<String> _userList = [];
  bool _isGeneratingExcel = false;

Future<void> _loadSavedUserList() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    _userList = prefs.getStringList('userList') ?? [];
  });
}
  final List<String> phanLoaiOptions = ['Sáng', 'Chiều', 'Cả ngày', 'Tối'];
  String? _selectedPhanLoai;
  String? _selectedProject;
  Map<String, List<String>> userTypeTasks = {
  'HM-CSKH': [
    'Ý kiến KH',
    'Báo cáo doanh thu',
    'Báo giá, Giải trình, Dự toán chi phí',
    'Biến động nhân sự',
    'Thu hồi công nợ',
    'Công nợ khách hàng',
    'Công văn, tờ trình, đề xuất',
    'Họp, gặp trực tiếp KH',
    'Giải quyết sự vụ CN, GS',
    'Nghiệm thu',
    'Đối thủ cạnh tranh',
    'Thị trường mới',
    'Kiểm soát chất lượng DV',
    'Khảo sát HĐ dịch vụ',
    'Họp nội bộ',
    'Họp đồng duy trì',
    'Họp đồng Tổng vệ sinh',
    'Tương tác nhóm QA',
    'Lập Doanh thu',
    'Lập Kế hoạch',
    'Lập Báo cáo'
  ],
  'HM-DV': [
    'Làm thầu',
    'Tương tác: Biến động NS',
    'Tương tác: PA bố trí NS thiếu',
    'Tương tác: Kiểm soát CL',
    'Tương tác: Vật tư',
    'Tương tác: Máy móc',
    'Tương tác: Đề xuất GS',
    'Kiểm soát chất lượng DV',
    'Khách hàng: gặp họp nghiệm thu',
    'Đánh giá đối thủ',
    'Họp CN BP',
    'In nghiệm thu',
    'Khảo sát HDM',
    'Họp GS',
    'Đào tạo CN',
    'Đào tạo GS',
    'Họp giao ban',
    'Họp phòng DV',
    'Triển khai hợp đồng mới',
    'Đi hỗ trợ',
    'Làm giáo trình đào tạo',
    'Thay thế giám sát',
    'Làm công nghiệm thu',
    'Làm báo cáo cho KH',
    'Yêu cầu vật tư ban đầu',
    'Yêu cầu cung cấp đồng phục ban đầu'
  ],
  'HM-RD': [
    'Công việc khác',
    'Nghỉ',
    'Ý kiến KH',
    'Báo cáo doanh thu',
    'Báo giá, Giải trình, Dự toán chi phí',
    'Biến động nhân sự',
    'Thu hồi công nợ',
    'Công nợ khách hàng',
    'Công văn, tờ trình, đề xuất',
    'Nghiệm thu',
    'Họp, gặp trực tiếp KH'
  ],
  'HM-KT': [
    'Công việc khác',
    'Nghỉ',
    'Ý kiến KH',
    'Báo cáo doanh thu',
    'Báo giá, Giải trình, Dự toán chi phí',
    'Biến động nhân sự',
    'Thu hồi công nợ',
    'Công nợ khách hàng',
    'Công văn, tờ trình, đề xuất',
    'Nghiệm thu',
    'Họp, gặp trực tiếp KH'
  ],
  'HM-NS': [
    'Công việc khác',
    'Nghỉ',
    'Ý kiến KH',
    'Báo cáo doanh thu',
    'Báo giá, Giải trình, Dự toán chi phí',
    'Biến động nhân sự',
    'Thu hồi công nợ',
    'Công nợ khách hàng',
    'Công văn, tờ trình, đề xuất',
    'Nghiệm thu',
    'Họp, gặp trực tiếp KH'
  ],
  'HM-TD': [
    'Công việc khác',
    'Nghỉ',
    'Ý kiến KH',
    'Báo cáo doanh thu',
    'Báo giá, Giải trình, Dự toán chi phí',
    'Biến động nhân sự',
    'Thu hồi công nợ',
    'Công nợ khách hàng',
    'Công văn, tờ trình, đề xuất',
    'Nghiệm thu',
    'Họp, gặp trực tiếp KH'
  ],
  'HM-HS': [
    'Công việc khác',
    'Nghỉ',
    'Ý kiến KH',
    'Báo cáo doanh thu',
    'Báo giá, Giải trình, Dự toán chi phí',
    'Biến động nhân sự',
    'Thu hồi công nợ',
    'Công nợ khách hàng',
    'Công văn, tờ trình, đề xuất',
    'Nghiệm thu',
    'Họp, gặp trực tiếp KH'
  ],
  'HM-KS': [
    'Công việc khác',
    'Nghỉ',
    'Ý kiến KH',
    'Báo cáo doanh thu',
    'Báo giá, Giải trình, Dự toán chi phí',
    'Biến động nhân sự',
    'Thu hồi công nợ',
    'Công nợ khách hàng',
    'Công văn, tờ trình, đề xuất',
    'Nghiệm thu',
    'Họp, gặp trực tiếp KH'
  ]
};
  void _setDefaultChiaSe(String? userType) {
    switch (userType) {
      case 'HM-DV':
        _selectedShare = ['hm.hahuong'];
        break;
      case 'HM-CSKH':
        _selectedShare = ['hm.tranminh'];
        break;
      case 'HM-NS':
        _selectedShare = ['hm.nguyengiang'];
        break;
      case 'HM-RD':
        _selectedShare = ['hm.tason'];
        break;
      case 'HM-QA':
        _selectedShare = ['hm.vuquyen'];
        break;
      case 'HM-KT':
        _selectedShare = ['hm.nguyenyen'];
        break;
      case 'HM-HS':
        _selectedShare = ['hm.luukinh'];
        break;
      case 'HM-KS':
        _selectedShare = ['hm.trangiang'];
        break;
      case 'HM-TD':
        _selectedShare = ['hm.nguyenhanh'];
        break;
      default:
        _selectedShare = [];
    }
  }
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProjects();
    _loadPlans();
    _setDefaultChiaSe(widget.userType);
    _loadSavedUserList();
  }

Future<void> _loadProjects() async {
    try {
      final List<String> projects = await dbHelper.getUserBoPhanList();
      setState(() {
        _projectList = projects;
        if (_projectList.isNotEmpty && _selectedProject == null) {
          _selectedProject = _projectList[0];
        }
      });
    } catch (e) {
      print('Error loading projects: $e');
    }
  }

  Future<void> _loadPlans() async {
    try {
      final userCredentials = Provider.of<UserCredentials>(context, listen: false);
      final username = userCredentials.username;
      
      final response = await AuthenticatedHttpClient.get(Uri.parse('$baseUrl/userbaocao/$username'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _plans = data
              .map((item) => BaocaoModel.fromMap(item))
              .where((plan) => plan.nhom == 'Kế hoạch')
              .toList();
          
          // Group plans by date for calendar events
          _events = {};
          for (var plan in _plans) {
            final date = DateTime(plan.ngay.year, plan.ngay.month, plan.ngay.day);
            if (_events[date] == null) _events[date] = [];
            _events[date]!.add(plan);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading plans: $e')),
      );
    }
  }

  void _showPlanDialog([BaocaoModel? existingPlan]) {
  final _detailsController = TextEditingController(text: existingPlan?.moTaChung);
  String? selectedPhanLoai = existingPlan?.phanLoai ?? 'Sáng';
  String? selectedProject = existingPlan?.boPhan ?? _selectedProject;
  String phatSinh = existingPlan?.phatSinh ?? 'Không';
  
  // Convert existing plan's chiaSe to a list if it exists
  List<String> selectedShareUsers = existingPlan?.chiaSe?.split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList() ?? List.from(_selectedShare);

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with title and buttons
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existingPlan == null ? 'Tạo kế hoạch mới' : 'Chi tiết kế hoạch',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              child: Text('Hủy'),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              child: Text('Lưu'),
                              onPressed: () async {
                                try {
                                  final userCredentials = Provider.of<UserCredentials>(context, listen: false);
                                  final username = userCredentials.username;
                                  
                                  // Format date to ISO string
                                  final formattedDate = _selectedDay?.toIso8601String() ?? DateTime.now().toIso8601String();

                                  // Prepare data to send
                                  final planData = {
  'nguoiDung': username,
  'ngay': formattedDate,
  'boPhan': selectedProject,
  'phanLoai': selectedPhanLoai,
  'moTaChung': _detailsController.text,
  'chiaSe': selectedShareUsers.join(','),
  'nhom': 'Kế hoạch',
  'phatSinh': phatSinh,
  'xetDuyet': phatSinh == 'Có' ? 'Chưa duyệt' : 'Đồng ý'
};

                                  // Send request to server
                                  final response = await http.post(
                                    Uri.parse('$baseUrl/submitplan'),
                                    headers: {'Content-Type': 'application/json'},
                                    body: json.encode(planData),
                                  );

                                  if (response.statusCode == 200) {
                                    // Refresh plans list
                                    await _loadPlans();
                                    
                                    // Show success message
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Kế hoạch đã được lưu thành công')),
                                    );
                                    
                                    // Close dialog
                                    Navigator.of(context).pop();
                                  } else {
                                    throw Exception('Failed to save plan');
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Lỗi khi lưu kế hoạch: $e')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownSearch<String>(
                            popupProps: PopupProps.menu(
                              showSearchBox: true,
                              searchFieldProps: TextFieldProps(
                                decoration: InputDecoration(
                                  hintText: "Tìm kiếm dự án...",
                                  contentPadding: EdgeInsets.fromLTRB(12, 12, 8, 0),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              showSelectedItems: true,
                            ),
                            items: _projectList,
                            selectedItem: selectedProject,
                            onChanged: (value) => selectedProject = value,
                            dropdownDecoratorProps: DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                labelText: 'Dự án',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedPhanLoai,
                            decoration: InputDecoration(
                              labelText: 'Thời gian',
                              border: OutlineInputBorder(),
                            ),
                            items: phanLoaiOptions.map((option) {
                              return DropdownMenuItem(value: option, child: Text(option));
                            }).toList(),
                            onChanged: (value) => selectedPhanLoai = value,
                          ),
                          SizedBox(height: 16),
                          TextField(
                            controller: _detailsController,
                            decoration: InputDecoration(
                              labelText: 'Chi tiết',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 5,
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: MultiSelectDialogField<String>(
                                  items: _userList.map((user) => 
                                    MultiSelectItem<String>(user, user)).toList(),
                                  listType: MultiSelectListType.CHIP,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  buttonText: Text("Chia sẻ với"),
                                  title: Text("Chọn người chia sẻ"),
                                  initialValue: selectedShareUsers,
                                  onConfirm: (values) {
                                    setState(() {
                                      selectedShareUsers = values;
                                    });
                                  },
                                  chipDisplay: MultiSelectChipDisplay(
                                    onTap: (value) {
                                      setState(() {
                                        selectedShareUsers.remove(value);
                                      });
                                    },
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    selectedShareUsers = [];
                                  });
                                },
                                tooltip: 'Xoá chia sẻ',
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 16),
                          Text('Công việc có sẵn:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Container(
                            height: 150,
                            child: ListView(
                              children: (userTypeTasks[widget.userType] ?? []).map((task) {
                                return ListTile(
                                  title: Text(task),
                                  trailing: TextButton(
                                    child: Text('Thêm'),
                                    onPressed: () {
                                      final currentText = _detailsController.text;
                                      final newTask = '- $task';
                                      _detailsController.text = currentText.isEmpty 
                                        ? newTask 
                                        : '$currentText\n$newTask';
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Text('Phát sinh: '),
                              Radio(
                                value: 'Không',
                                groupValue: phatSinh,
                                onChanged: (value) => setState(() => phatSinh = value.toString()),
                              ),
                              Text('Không'),
                              Radio(
                                value: 'Có',
                                groupValue: phatSinh,
                                onChanged: (value) => setState(() => phatSinh = value.toString()),
                              ),
                              Text('Có'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
void _showPlanDetailsDialog(BaocaoModel plan) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Chi tiết kế hoạch',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Người tạo', plan.nguoiDung ?? 'N/A'),
                      _buildDetailRow('Ngày', DateFormat('dd/MM/yyyy').format(plan.ngay)),
                      _buildDetailRow('Thời gian', plan.phanLoai ?? 'N/A'),
                      _buildDetailRow('Dự án', plan.boPhan ?? 'N/A'),
                      _buildDetailRow('Chi tiết', plan.moTaChung ?? 'N/A', multiLine: true),
                      _buildDetailRow('Phát sinh', plan.phatSinh ?? 'Không', 
                        isHighlighted: plan.phatSinh == 'Có'),
                      _buildDetailRow('Trạng thái', plan.xetDuyet ?? 'Chưa duyệt'),
                      _buildDetailRow('Chia sẻ với', plan.chiaSe ?? 'N/A'),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            child: Text('Phản hồi'),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showReportDialog(plan);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
Widget _buildDetailRow(String label, String value, {bool multiLine = false, bool isHighlighted = false}) {
  return Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        multiLine
            ? Container(
                width: double.infinity,
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  value,
                  style: TextStyle(fontSize: 14),
                ),
              )
            : Row(
                children: [
                  if (isHighlighted)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.check_box, color: Colors.red, size: 18),
                    ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: isHighlighted ? Colors.red : null,
                    ),
                  ),
                ],
              ),
      ],
    ),
  );
}
Widget _buildPlanList(bool isMyPlans) {
  final userCredentials = Provider.of<UserCredentials>(context, listen: false);
  final username = userCredentials.username;

  // Initial filtering - separate shared vs. my plans
  final initialFilteredPlans = _plans.where((plan) {
    if (isMyPlans) {
      return plan.nguoiDung == username;
    } else {
      return plan.nguoiDung != username ;
      //&&        (plan.chiaSe?.split(',').contains(username) ?? false);
    }
  }).toList();

  initialFilteredPlans.sort((a, b) => b.ngay.compareTo(a.ngay));
  
  if (!isMyPlans) {
    // Get unique users for filter dropdown
    final uniqueUsers = initialFilteredPlans
        .map((plan) => plan.nguoiDung)
        .where((user) => user != null)
        .toSet()
        .toList();
    
    // Apply secondary filters
    List<BaocaoModel> finalFilteredPlans = List.from(initialFilteredPlans);
    
    if (_filterByUser != null) {
      finalFilteredPlans = finalFilteredPlans.where((plan) => 
        plan.nguoiDung == _filterByUser).toList();
    }
    
    if (_startDate != null && _endDate != null) {
      finalFilteredPlans = finalFilteredPlans.where((plan) {
        final planDate = DateTime(plan.ngay.year, plan.ngay.month, plan.ngay.day);
        return !planDate.isBefore(_startDate!) && 
               !planDate.isAfter(_endDate!.add(Duration(days: 1)));
      }).toList();
    }
        
    return Column(
      children: [
        // Filter row with updated count based on all filters
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Text(
                'Tổng số: ${finalFilteredPlans.length}',  // Use count from fully filtered list
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 16),
              // User filter
              Expanded(
                child: Container(
                  height: 32,
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      isDense: true,
                      labelText: 'Người dùng',
                      labelStyle: TextStyle(fontSize: 12),
                    ),
                    value: _filterByUser,
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('Tất cả', style: TextStyle(fontSize: 12)),
                      ),
                      ...uniqueUsers.map((user) => DropdownMenuItem<String>(
                        value: user,
                        child: Text(user ?? '', style: TextStyle(fontSize: 12)),
                      )).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterByUser = value;
                      });
                    },
                  ),
                ),
              ),
              SizedBox(width: 8),
              // Date range
              InkWell(
                onTap: () async {
                  final DateTimeRange? picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    initialDateRange: _startDate != null && _endDate != null
                        ? DateTimeRange(start: _startDate!, end: _endDate!)
                        : null,
                  );
                  if (picked != null) {
                    setState(() {
                      _startDate = picked.start;
                      _endDate = picked.end;
                    });
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.date_range, size: 16),
                      SizedBox(width: 4),
                      Text(
                        _startDate != null && _endDate != null
                            ? '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}'
                            : 'Chọn ngày',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              // Clear filters button
              IconButton(
                icon: Icon(Icons.clear, size: 16),
                onPressed: () {
                  setState(() {
                    _filterByUser = null;
                    _startDate = null;
                    _endDate = null;
                  });
                },
                tooltip: 'Xóa bộ lọc',
                padding: EdgeInsets.all(4),
              ),
            ],
          ),
        ),
        
        // Use the already filtered list for the data table
        Expanded(
          child: _buildFilteredPlanTable(finalFilteredPlans, isMyPlans),
        ),
      ],
    );
  } else {
    return _buildFilteredPlanTable(initialFilteredPlans, isMyPlans);
  }
}
Widget _buildFilteredPlanTable(List<BaocaoModel> plans, bool isMyPlans) {
  // Create columns list to ensure consistency
  final List<DataColumn> columns = [
    DataColumn(label: Text('')),
    if (!isMyPlans) DataColumn(label: Text('Người dùng')),
    DataColumn(label: Text('Ngày')),
    DataColumn(label: Text('Thời gian')),
    DataColumn(label: Text('Dự án')),
    DataColumn(label: Text('Chi tiết')),
    DataColumn(label: Text('Phát sinh')),
    DataColumn(label: Text('Trạng thái')),
    if (!isMyPlans) DataColumn(label: Text('Xét duyệt')),
  ];

  return SingleChildScrollView(
    scrollDirection: Axis.vertical,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        columns: columns,
        rows: plans.map((plan) {
          final rowColor = !isMyPlans ? _getStatusColor(plan.xetDuyet ?? '') : null;
          final isPhatSinh = plan.phatSinh == 'Có';
          
          // Create list of cells that matches columns count exactly
          final List<DataCell> cells = [
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_box,
                    color: isPhatSinh ? Colors.red : Colors.grey,
                    size: 18,
                  ),
                  Container(
                    height: 36,
                    child: IconButton(
                      icon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.reply, size: 14, color: const Color.fromARGB(255, 0, 113, 206)),
                          SizedBox(width: 4),
                          Text(
                            'Trả lời',
                            style: TextStyle(
                              color: Color.fromARGB(255, 0, 113, 206),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      onPressed: () => _showReportDialog(plan),
                      tooltip: 'Phản hồi kế hoạch',
                      padding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ),
          ];
          
          // Add user cell only for shared plans
          if (!isMyPlans) {
            cells.add(DataCell(Text(plan.nguoiDung ?? '')));
          }
          
          // Add the remaining common cells
          cells.addAll([
            DataCell(Text(DateFormat('dd/MM/yyyy').format(plan.ngay))),
            DataCell(Text(plan.phanLoai ?? '')),
            DataCell(Text(plan.boPhan ?? '')),
            DataCell(Text(plan.moTaChung ?? '')),
            DataCell(Text(plan.phatSinh ?? 'Không')),
            DataCell(Text(plan.xetDuyet ?? 'Chưa duyệt')),
          ]);
          
          // Add approval buttons cell only for shared plans
          if (!isMyPlans) {
            cells.add(
              DataCell(
                plan.phatSinh == 'Có' && plan.xetDuyet == 'Chưa duyệt'
                  ? Row(
                      children: [
                        TextButton(
                          child: Text('Đồng ý'),
                          onPressed: () => _updatePlanStatus(plan, 'Đồng ý'),
                        ),
                        TextButton(
                          child: Text('Từ chối'),
                          onPressed: () => _updatePlanStatus(plan, 'Từ chối'),
                        ),
                      ],
                    )
                  : Text(''),
              ),
            );
          }
          
          // Double-check that cells count matches columns count
          assert(cells.length == columns.length, 'Cell count must match column count');
          
          return DataRow(
            color: MaterialStateProperty.all(rowColor),
            onSelectChanged: (_) => _showPlanDetailsDialog(plan),
            cells: cells,
          );
        }).toList(),
      ),
    ),
  );
}
void _showReportDialog(BaocaoModel plan) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return ReportDialogContent(
        plan: plan,
        refreshPlans: _loadPlans,
      );
    },
  );
}
  Future<void> _updatePlanStatus(BaocaoModel plan, String status) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/submitplanchange'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'uid': plan.uid,
          'xetDuyet': status,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã cập nhật trạng thái')),
        );
        _loadPlans();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Chưa duyệt':
        return Colors.transparent;
      case 'Đồng ý':
        return Colors.green.withOpacity(0.1);
      case 'Từ chối':
        return Colors.red.withOpacity(0.1);
      default:
        return Colors.transparent;
    }
  }
Future<String?> _showExportChoiceDialog() async {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Xuất file Excel'),
        content: Text('Bạn muốn chia sẻ file hay lưu vào thư mục ứng dụng?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('share'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.share, size: 16),
                SizedBox(width: 4),
                Text('Chia sẻ'),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder, size: 16),
                SizedBox(width: 4),
                Text('Lưu vào thư mục'),
              ],
            ),
          ),
        ],
      );
    },
  );
}

Future<void> _handleShare(List<int> fileBytes, String fileName) async {
  try {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(fileBytes);
    
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Báo cáo kế hoạch dự án - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã chia sẻ file thành công: $fileName'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  } catch (e) {
    print('Error sharing file: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi khi chia sẻ file: $e'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ),
    );
  }
}

Future<void> _handleSaveToAppFolder(List<int> fileBytes, String fileName) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final appFolder = Directory('${directory.path}/BaoCao_KeHoach');
    
    // Create folder if it doesn't exist
    if (!await appFolder.exists()) {
      await appFolder.create(recursive: true);
    }
    
    final filePath = '${appFolder.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(fileBytes);
    
    // Show success dialog with option to open folder
    await _showSaveSuccessDialog(appFolder.path, fileName);
    
  } catch (e) {
    print('Error saving to app folder: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi khi lưu file: $e'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ),
    );
  }
}

Future<void> _showSaveSuccessDialog(String folderPath, String fileName) async {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Lưu thành công'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File báo cáo kế hoạch đã được lưu:'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                fileName,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 8),
            Text('Ngày tạo: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
            SizedBox(height: 8),
            Text('Đường dẫn thư mục:'),
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                folderPath,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Đóng'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _openFolder(folderPath);
            },
            icon: Icon(Icons.folder_open, size: 16),
            label: Text('Mở thư mục'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    },
  );
}

Future<void> _openFolder(String folderPath) async {
  try {
    if (Platform.isWindows) {
      await Process.run('explorer', [folderPath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [folderPath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [folderPath]);
    }
  } catch (e) {
    print('Error opening folder: $e');
  }
}

Future<void> _generateAndShareExcel() async {
  setState(() {
    _isGeneratingExcel = true;
  });

  try {
    // Show choice dialog first
    final choice = await _showExportChoiceDialog();
    if (choice == null) {
      setState(() {
        _isGeneratingExcel = false;
      });
      return; // User cancelled
    }

    // Create Excel workbook
    var excel = xl.Excel.createExcel();
    
    // Get or create sheet
    xl.Sheet sheet;
    if (excel.tables.containsKey('Sheet1')) {
      sheet = excel.tables['Sheet1']!;
    } else {
      sheet = excel['Kế hoạch dự án'];
    }
    
    // Add headers
    List<String> headers = [
      'STT',
      'Người tạo',
      'Ngày',
      'Thời gian',
      'Dự án',
      'Chi tiết',
      'Phát sinh',
      'Trạng thái',
      'Chia sẻ với'
    ];
    
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = headers[i];
      cell.cellStyle = xl.CellStyle(
        bold: true,
        backgroundColorHex: '#4472C4',
        fontColorHex: '#FFFFFF',
      );
    }
    
    // Sort plans by date (newest first)
    final sortedPlans = List<BaocaoModel>.from(_plans);
    sortedPlans.sort((a, b) => b.ngay.compareTo(a.ngay));
    
    // Add data rows
    for (int i = 0; i < sortedPlans.length; i++) {
      var plan = sortedPlans[i];
      
      List<dynamic> rowData = [
        i + 1,
        plan.nguoiDung ?? '',
        DateFormat('dd/MM/yyyy').format(plan.ngay),
        plan.phanLoai ?? '',
        plan.boPhan ?? '',
        plan.moTaChung ?? '',
        plan.phatSinh ?? 'Không',
        plan.xetDuyet ?? 'Chưa duyệt',
        plan.chiaSe ?? ''
      ];
      
      for (int j = 0; j < rowData.length; j++) {
        var cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1));
        cell.value = rowData[j];
        
        // Color coding based on status
        if (j == 7) { // Status column
          xl.CellStyle? cellStyle;
          final status = plan.xetDuyet ?? 'Chưa duyệt';
          if (status == 'Đồng ý') {
            cellStyle = xl.CellStyle(
              backgroundColorHex: '#C6EFCE',
              fontColorHex: '#006100',
            );
          } else if (status == 'Từ chối') {
            cellStyle = xl.CellStyle(
              backgroundColorHex: '#FFC7CE',
              fontColorHex: '#9C0006',
            );
          } else {
            cellStyle = xl.CellStyle(
              backgroundColorHex: '#FFEB9C',
              fontColorHex: '#9C5700',
            );
          }
          cell.cellStyle = cellStyle;
        }
        
        // Highlight emergency plans (Phát sinh = Có)
        if (j == 6 && plan.phatSinh == 'Có') {
          var cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1));
          cell.cellStyle = xl.CellStyle(
            backgroundColorHex: '#FFC7CE',
            fontColorHex: '#9C0006',
            bold: true,
          );
        }
      }
    }
    
    // Add summary row
    int summaryRow = sortedPlans.length + 2;
    
    // Calculate statistics
    int totalPlans = sortedPlans.length;
    int approvedPlans = sortedPlans.where((p) => p.xetDuyet == 'Đồng ý').length;
    int pendingPlans = sortedPlans.where((p) => p.xetDuyet == 'Chưa duyệt').length;
    int rejectedPlans = sortedPlans.where((p) => p.xetDuyet == 'Từ chối').length;
    int emergencyPlans = sortedPlans.where((p) => p.phatSinh == 'Có').length;
    
    // Summary row data
    List<dynamic> summaryData = [
      'TỔNG CỘNG',
      '$totalPlans kế hoạch',
      '',
      '',
      '',
      'Đồng ý: $approvedPlans | Chưa duyệt: $pendingPlans | Từ chối: $rejectedPlans',
      'Phát sinh: $emergencyPlans',
      '',
      ''
    ];
    
    // Add summary row to sheet
    for (int i = 0; i < summaryData.length; i++) {
      var cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: summaryRow));
      cell.value = summaryData[i];
      cell.cellStyle = xl.CellStyle(
        bold: true,
        backgroundColorHex: '#D9E1F2',
      );
    }
    
    // Add title row
    var titleCell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRow + 2));
    titleCell.value = 'Báo cáo kế hoạch dự án - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}';
    titleCell.cellStyle = xl.CellStyle(
      bold: true,
      fontSize: 14,
    );
    
    // Add generation timestamp
    var timestampCell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRow + 3));
    timestampCell.value = 'Tạo lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}';
    timestampCell.cellStyle = xl.CellStyle(
      italic: true,
      fontSize: 10,
    );
    
    // Generate filename
    String fileName = 'KeHoachDuAn_${DateFormat('dd-MM-yyyy').format(DateTime.now())}.xlsx';
    List<int>? fileBytes = excel.save();
    
    if (fileBytes != null) {
      if (choice == 'share') {
        await _handleShare(fileBytes, fileName);
      } else {
        await _handleSaveToAppFolder(fileBytes, fileName);
      }
    } else {
      throw Exception('Không thể tạo file Excel');
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi khi tạo file Excel: ${e.toString()}'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ),
    );
    print('Error generating Excel: $e');
  } finally {
    setState(() {
      _isGeneratingExcel = false;
    });
  }
}
  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Lập kế hoạch'),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 114, 255, 217),
              Color.fromARGB(255, 201, 255, 236),
              Color.fromARGB(255, 79, 255, 214),
              Color.fromARGB(255, 188, 255, 235),
            ],
          ),
        ),
      ),
      actions: [
        // Excel export button
        Container(
          margin: EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(6),
          ),
          child: IconButton(
            icon: _isGeneratingExcel 
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.download, size: 20, color: Colors.white),
            onPressed: _isGeneratingExcel ? null : () {
              _generateAndShareExcel();
            },
            tooltip: 'Tải xuống Excel',
          ),
        ),
      ],
    ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            //locale: 'vi_VN', // Vietnamese locale
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) => _events[DateTime(day.year, day.month, day.day)] ?? [],
            calendarStyle: CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),),
            onDaySelected: (selectedDay, focusedDay) {
  DateTime startOfWeek = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  startOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
  
  if (selectedDay.isBefore(startOfWeek)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Không thể tạo kế hoạch cho thời gian đã qua')),
    );
    return;
  }
  
  setState(() {
    _selectedDay = selectedDay;
    _focusedDay = focusedDay;
  });
  _showPlanDialog();
},
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Của tôi'),
              Tab(text: 'Được chia sẻ'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPlanList(true),
                _buildPlanList(false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class ReportDialogContent extends StatefulWidget {
  final BaocaoModel plan;
  final Function refreshPlans;

  ReportDialogContent({required this.plan, required this.refreshPlans});

  @override
  _ReportDialogContentState createState() => _ReportDialogContentState();
}

class _ReportDialogContentState extends State<ReportDialogContent> {
  late TextEditingController _giaiPhapController;
  late TextEditingController _taskContentController;
  List<String> _selectedImages = [];
  List<String> _selectedShare = [];
  bool _createTask = false;
  DateTime _taskDate = DateTime.now().add(Duration(days: 1));
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  List<String> _userList = [];
  
  @override
  void initState() {
    super.initState();
    _giaiPhapController = TextEditingController();
    _taskContentController = TextEditingController();
    
    if (widget.plan.chiaSe != null && widget.plan.chiaSe!.isNotEmpty) {
      _selectedShare = widget.plan.chiaSe!.split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    
    _loadSavedUserList();
  }
  
  Future<void> _loadSavedUserList() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userList = prefs.getStringList('userList') ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Phản hồi kế hoạch',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        child: Text('Hủy'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        child: Text('Gửi'),
                        onPressed: () => _submitReport(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Project display
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey.shade100,
                      ),
                      child: Row(
                        children: [
                          Text('Dự án: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(widget.plan.boPhan ?? 'N/A'),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _giaiPhapController,
                      decoration: InputDecoration(
                        labelText: 'Giải pháp',
                        border: OutlineInputBorder(),
                        errorText: _giaiPhapController.text.isEmpty ? 'Vui lòng nhập giải pháp' : null,
                      ),
                      maxLines: 5,
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: MultiSelectDialogField<String>(
                            items: _userList.map((user) => 
                              MultiSelectItem<String>(user, user)).toList(),
                            listType: MultiSelectListType.CHIP,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            buttonText: Text("Chia sẻ với"),
                            title: Text("Chọn người chia sẻ"),
                            initialValue: _selectedShare,
                            onConfirm: (values) {
                              setState(() {
                                _selectedShare = values;
                              });
                            },
                            chipDisplay: MultiSelectChipDisplay(
                              onTap: (value) {
                                setState(() {
                                  _selectedShare.remove(value);
                                });
                              },
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _selectedShare = [];
                            });
                          },
                          tooltip: 'Xoá chia sẻ',
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Add option to create follow-up task
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Switch(
                                value: _createTask,
                                onChanged: (value) {
                                  setState(() {
                                    _createTask = value;
                                    
                                    // Initialize task content with giaiPhap when toggled on
                                    if (_createTask && _giaiPhapController.text.isNotEmpty) {
                                      _taskContentController.text = _giaiPhapController.text;
                                    }
                                  });
                                },
                              ),
                              Text(
                                'Tạo hẹn xử lý',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          if (_createTask) ...[
                            SizedBox(height: 16),
                            // Add project display for task (read-only)
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.grey.shade50,
                              ),
                              child: Row(
                                children: [
                                  Text('Dự án: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text(widget.plan.boPhan ?? 'N/A'),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),
                            Text('Ngày xử lý:'),
                            InkWell(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: _taskDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null && picked != _taskDate) {
                                  setState(() {
                                    _taskDate = picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${_taskDate.day}/${_taskDate.month}/${_taskDate.year}',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    Icon(Icons.calendar_today),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _taskContentController,
                              decoration: InputDecoration(
                                labelText: 'Nội dung',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _submitReport(BuildContext context) async {
    try {
      if (_giaiPhapController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vui lòng nhập giải pháp')),
        );
        return;
      }

      final userCredentials = Provider.of<UserCredentials>(context, listen: false);
      final username = userCredentials.username;
      
      // Capture values
      final giaiPhapText = _giaiPhapController.text.trim();
      final taskContentText = _taskContentController.text.trim();
      final createTaskFlag = _createTask;
      final taskDateCopy = DateTime(_taskDate.year, _taskDate.month, _taskDate.day);
      
      final reportData = {
        'nguoiDung': username,
        'ngay': DateTime.now().toIso8601String(),
        'boPhan': widget.plan.boPhan,  // Use the same project as original plan
        'phanLoai': 'Phản hồi kế hoạch',
        'moTaChung': 'Báo cáo kế hoạch ngày ${DateFormat('dd/MM/yyyy').format(widget.plan.ngay)} về dự án ${widget.plan.boPhan}: ${widget.plan.moTaChung}',
        'giaiPhapChung': giaiPhapText,
        'chiaSe': _selectedShare.join(','),  // Use the selected users
        'nhom': 'Báo cáo',
        'phatSinh': 'Có',
        'xetDuyet': 'Chưa duyệt',
        'hinhAnh': _selectedImages.join(','),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/submitplan'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(reportData),
      );

      // Now handle task creation if requested
      if (createTaskFlag) {
        final taskUuid = Uuid().v4();
        final taskFormattedDate = taskDateCopy.toIso8601String().split('T')[0];
        final now = DateTime.now();
        final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

        final effectiveTaskContent = taskContentText.isEmpty ? 
                   giaiPhapText : taskContentText;

        final taskData = {
          'uid': taskUuid,
          'ngay': taskFormattedDate,
          'gio': formattedTime,
          'nguoiDung': username,
          'boPhan': widget.plan.boPhan,
          'chiaSe': _selectedShare.join(','), 
          'phanLoai': 'Cả ngày',
          'moTaChung': effectiveTaskContent,
          'nhom': 'Kế hoạch',
          'phatSinh': 'Có',
          'xetDuyet': 'Chưa duyệt',
        };

        final taskResponse = await http.post(
          Uri.parse('$baseUrl/submitplan'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(taskData),
        );

        if (taskResponse.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Phản hồi và hẹn xử lý đã được gửi thành công')),
          );
        } else {
          throw Exception('Phản hồi đã gửi nhưng lỗi tạo hẹn: ${taskResponse.statusCode}');
        }
      } else {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Phản hồi đã được gửi thành công')),
          );
        } else {
          throw Exception('Server returned ${response.statusCode}: ${response.body}');
        }
      }

      // Close dialog and refresh data
      Navigator.of(context).pop();
      widget.refreshPlans();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi gửi phản hồi: $e')),
      );
    }
  }
}
