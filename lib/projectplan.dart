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

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columns: [
        DataColumn(label: Text('')),
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
        
        return DataRow(
          color: MaterialStateProperty.all(rowColor),
          cells: [
            DataCell(
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
),
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
  );
}
void _showReportDialog(BaocaoModel plan) {
  final _giaiPhapController = TextEditingController();
  List<String> _selectedImages = [];
   void dispose() {
    _giaiPhapController.dispose();
  }
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return WillPopScope(
        onWillPop: () async {
          dispose();
          return true;
        },
        child: StatefulBuilder(
        builder: (context, setState) {
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
  onPressed: () async {
    try {
      if (_giaiPhapController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vui lòng nhập giải pháp')),
        );
        return;
      }

      final userCredentials = Provider.of<UserCredentials>(context, listen: false);
      final username = userCredentials.username;
      
      print('GiaiPhap text: ${_giaiPhapController.text}'); // Debug log
      
      final reportData = {
        'nguoiDung': username,
        'ngay': DateTime.now().toIso8601String(),
        'boPhan': plan.boPhan,
        'phanLoai': 'Phản hồi kế hoạch',
        'moTaChung': 'Báo cáo kế hoạch ngày ${DateFormat('dd/MM/yyyy').format(plan.ngay)} về dự án ${plan.boPhan}: ${plan.moTaChung}',
        'giaiPhapChung': _giaiPhapController.text.trim(),
        'chiaSe': plan.chiaSe,
        'nhom': 'Báo cáo',
        'phatSinh': 'Có',
        'xetDuyet': 'Chưa duyệt',
        'hinhAnh': _selectedImages.join(','),
      };

      print('Full report data: ${json.encode(reportData)}'); // Debug log

      final response = await http.post(
        Uri.parse('$baseUrl/submitplan'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(reportData),
      );

      print('Response status: ${response.statusCode}'); // Debug log
      print('Response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        await _loadPlans();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Phản hồi đã được gửi thành công')),
        );
        Navigator.of(context).pop();
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error submitting report: $e'); // Debug log
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi gửi phản hồi: $e')),
      );
    }
  },
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
                            'Báo cáo kế hoạch ngày ${DateFormat('dd/MM/yyyy').format(plan.ngay)} về dự án ${plan.boPhan}: ${plan.moTaChung}',
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
  onChanged: (value) {
    print('Current text: $value');
  },
),
                          SizedBox(height: 16),
                          //ElevatedButton.icon(
                            //icon: Icon(Icons.image),
                            //label: Text('Thêm hình ảnh'),
                            //onPressed: () async {
                              // Add your image picking logic here
                              // Update _selectedImages list with selected image paths
                            //},
                          //),
                          if (_selectedImages.isNotEmpty)
                            Column(
                              children: _selectedImages.map((imagePath) => 
                                ListTile(
                                  title: Text(imagePath),
                                  trailing: IconButton(
                                    icon: Icon(Icons.delete),
                                    onPressed: () {
                                      setState(() {
                                        _selectedImages.remove(imagePath);
                                      });
                                    },
                                  ),
                                )
                              ).toList(),
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
      ),
      );
    },
  ).then((_) => dispose());
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