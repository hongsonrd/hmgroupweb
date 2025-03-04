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
import 'http_client.dart';
import 'package:uuid/uuid.dart';

class ProjectPlan extends StatefulWidget {
  final String? userType;
  final String? selectedBoPhan;
  final String? selectedDate;
  ProjectPlan({this.selectedDate, this.selectedBoPhan, this.userType});
  @override
  _ProjectPlanState createState() => _ProjectPlanState();
}

class _ProjectPlanState extends State<ProjectPlan> with SingleTickerProviderStateMixin {
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
      'chiaSe': _selectedShare.join(','),
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
                          DropdownButtonFormField<String>(
                            value: selectedProject,
                            decoration: InputDecoration(
                              labelText: 'Dự án',
                              border: OutlineInputBorder(),
                            ),
                            items: _projectList.map((project) {
                              return DropdownMenuItem(value: project, child: Text(project));
                            }).toList(),
                            onChanged: (value) => selectedProject = value,
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
Widget _buildPlanList(bool isMyPlans) {
  final userCredentials = Provider.of<UserCredentials>(context, listen: false);
  final username = userCredentials.username;

  final filteredPlans = _plans.where((plan) {
    if (isMyPlans) {
      return plan.nguoiDung == username;
    } else {
      return plan.nguoiDung != username && 
             (plan.chiaSe?.split(',').contains(username) ?? false);
    }
  }).toList();

  filteredPlans.sort((a, b) => b.ngay.compareTo(a.ngay));

  // Wrap in a vertical scroll view first
  return SingleChildScrollView(
    scrollDirection: Axis.vertical,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        columns: [
          DataColumn(label: Text('')),
          if (!isMyPlans) DataColumn(label: Text('Người dùng')),
          DataColumn(label: Text('Ngày')),
          DataColumn(label: Text('Thời gian')),
          DataColumn(label: Text('Dự án')),
          DataColumn(label: Text('Chi tiết')),
          DataColumn(label: Text('Phát sinh')),
          DataColumn(label: Text('Trạng thái')),
          if (!isMyPlans) DataColumn(label: Text('Xét duyệt')),
        ],
        rows: filteredPlans.map((plan) {
          final rowColor = !isMyPlans ? _getStatusColor(plan.xetDuyet ?? '') : null;
          final isPhatSinh = plan.phatSinh == 'Có';
          
          return DataRow(
            color: MaterialStateProperty.all(rowColor),
            onSelectChanged: (_) => _showPlanDetailsDialog(plan),
            cells: [
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Add checkbox that's red if PhatSinh is "Có"
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
            if (!isMyPlans) DataCell(Text(plan.nguoiDung ?? '')),
            DataCell(Text(DateFormat('dd/MM/yyyy').format(plan.ngay))),
            DataCell(Text(plan.phanLoai ?? '')),
            DataCell(Text(plan.boPhan ?? '')),
            DataCell(Text(plan.moTaChung ?? '')),
            DataCell(Text(plan.phatSinh ?? 'Không')),
            DataCell(Text(plan.xetDuyet ?? 'Chưa duyệt')),
            if (!isMyPlans)
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
          ],
          );
        }).toList(),
      ),
    ),
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
                  // Show red checkbox for highlighted values (PhatSinh = 'Có')
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
  bool _createTask = false;
  DateTime _taskDate = DateTime.now().add(Duration(days: 1));
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  
  @override
  void initState() {
    super.initState();
    _giaiPhapController = TextEditingController();
    _taskContentController = TextEditingController();
  }
  
  @override
  void dispose() {
    _giaiPhapController.dispose();
    _taskContentController.dispose();
    super.dispose();
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
                    Text(
                      'Báo cáo kế hoạch ngày ${DateFormat('dd/MM/yyyy').format(widget.plan.ngay)} về dự án ${widget.plan.boPhan}: ${widget.plan.moTaChung}',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
      
      // Capture all values
      final giaiPhapText = _giaiPhapController.text.trim();
      final taskContentText = _taskContentController.text.trim();
      final createTaskFlag = _createTask;
      final taskDateCopy = DateTime(_taskDate.year, _taskDate.month, _taskDate.day);
      
      final reportData = {
        'nguoiDung': username,
        'ngay': DateTime.now().toIso8601String(),
        'boPhan': widget.plan.boPhan,
        'phanLoai': 'Phản hồi kế hoạch',
        'moTaChung': 'Báo cáo kế hoạch ngày ${DateFormat('dd/MM/yyyy').format(widget.plan.ngay)} về dự án ${widget.plan.boPhan}: ${widget.plan.moTaChung}',
        'giaiPhapChung': giaiPhapText,
        'chiaSe': widget.plan.chiaSe,
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
          'chiaSe': widget.plan.chiaSe,
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
