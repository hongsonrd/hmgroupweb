import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'projectplan.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:collection/collection.dart';
import 'http_client.dart';
import 'package:dropdown_search/dropdown_search.dart';

class ProjectWorkReport extends StatefulWidget {
  final String? selectedDate;
  final String? selectedBoPhan;
  final String? userType;

  ProjectWorkReport({this.selectedDate, this.selectedBoPhan, this.userType});
  @override
  _ProjectWorkReportState createState() => _ProjectWorkReportState();
}

class _ProjectWorkReportState extends State<ProjectWorkReport> with SingleTickerProviderStateMixin {
  final dbHelper = DBHelper();
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  
  String? _selectedProject;
  String? _selectedTopic;
  List<String> _projectList = [];
  List<String> _selectedShare = [];
  final _formKey = GlobalKey<FormState>();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isSyncing = false;
  List<String> _userList = [];
  late TabController _tabController;
  List<BaocaoModel> _reports = [];

  final _moTaChungController = TextEditingController();
  final _giaiPhapChungController = TextEditingController();
  final _danhGiaNSController = TextEditingController();
  final _giaiPhapNSController = TextEditingController();
  final _danhGiaCLController = TextEditingController();
  final _giaiPhapCLController = TextEditingController();
  final _danhGiaVTController = TextEditingController();
  final _giaiPhapVTController = TextEditingController();
  final _danhGiaYKienKhachHangController = TextEditingController();
  final _giaiPhapYKienKhachHangController = TextEditingController();
  final _danhGiaMayMocController = TextEditingController();
  final _giaiPhapMayMocController = TextEditingController();

  Map<String, List<String>> userTypeTopics = {
  'HM-DV': [
    'Kiểm tra dự án',
    'Đào tạo công nhân',
    'Họp công nhân',
    'Gặp khách hàng',
    'Triển khai HĐ mới',
    'Đề xuất/ Ý kiến sáng tạo'
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
  'HM-CSKH': [
    'Ý kiến KH',
    'Báo cáo doanh thu',
    'Báo giá/ Giải trình/ Dự toán chi phí',
    'Biến động nhân sự',
'Công lương',
'Công nợ khách hàng',
'Công văn, tờ trình, đề xuất',
'Gặp trực tiếp KH',
'Giải quyết sự vụ CN, GS',
'Gọi điện thoại KH',
'Họp GS/CN',
'Họp/ gặp trực tiếp KH',
'Hợp đồng dừng',
'Hợp đồng không ổn định',
'Hợp đồng mới, mở rộng',
'Họp nội bộ',
'Khảo sát hợp đồng dịch vụ',
'Khảo sát HĐ dịch vụ',
'Kiểm soát chất lượng DV',
'Kế hoạch tuần',
'KS Lịch làm việc qua app',
'Làm hợp đồng duy trì',
'Làm thầu',
'Làm việc tại văn phòng',
'Nghiệm thu',
'Đào tạo GS/CN',
'Thị trường mới',
'Đối thủ cạnh tranh'
  ],
  'HM-NS': [
    'Hồ sơ',
    'Công lương',
    'Bảo hiểm',
    'Đánh giá nhân sự',
    'Chế độ chính sách',
    'Đề xuất cải tiến'
  ],
  'HM-RD': [
    'Họp',
    'Hỗ trợ người dùng',
    'Cập nhật app',
    'Nhân sự',
    'Kinh doanh',
    'Tuyển dụng',
    'QLDV',
    'Giám sát',
    'Công lương',
    'Chung'
  ],
  'HM-QA': [
    'Báo cáo',
'Phát sinh',
'Kế hoạch',
'Đề xuất'
  ],
  'HM-KT': [
    'Báo cáo',
'Phát sinh',
'Kế hoạch',
'Đề xuất'
  ],
  'HM-TD': [
    'Tuyển dụng',
    'Báo cáo',
    'Đề xuất',
    'Ý kiến KH',
    'CV Khác',
'Phát sinh',
'Kế hoạch'
  ],
    'HM-HS': [
    'Báo cáo',
'Phát sinh',
'Kế hoạch',
'Đề xuất'
  ],
      'HM-KS': [
    'Báo cáo',
'Phát sinh',
'Kế hoạch',
'Đề xuất'
  ],
};
  Map<String, String> topicIcons = {
  'Phản hồi kế hoạch': '⚠️',
  'Kiểm tra dự án': '🔍',
  'Đào tạo công nhân': '📚',
  'Họp công nhân': '📋',
  'Gặp khách hàng': '🤝',
  'Triển khai HĐ mới': '📑',
  'Đề xuất/ Ý kiến sáng tạo': '💡',
  'Ý kiến KH': '💭',
  'Báo cáo doanh thu': '📊',
  'Báo giá/ Giải trình/ Dự toán chi phí': '💰',
  'Biến động nhân sự': '👥',
  'Công lương': '💵',
  'Công nợ khách hàng': '📒',
  'Công văn, tờ trình, đề xuất': '📝',
  'Gặp trực tiếp KH': '🤝',
  'Giải quyết sự vụ CN, GS': '⚡',
  'Gọi điện thoại KH': '📞',
  'Họp GS/CN': '👥',
  'Họp/ gặp trực tiếp KH': '🤝',
  'Hợp đồng dừng': '🚫',
  'Hợp đồng không ổn định': '⚠️',
  'Hợp đồng mới, mở rộng': '📋',
  'Họp nội bộ': '💼',
  'Khảo sát hợp đồng dịch vụ': '📋',
  'Khảo sát HĐ dịch vụ': '📋',
  'Kiểm soát chất lượng DV': '✅',
  'Kế hoạch tuần': '📅',
  'KS Lịch làm việc qua app': '📱',
  'Làm hợp đồng duy trì': '📄',
  'Làm thầu': '📊',
  'Làm việc tại văn phòng': '💻',
  'Nghiệm thu': '✔️',
  'Đào tạo GS/CN': '📚',
  'Thị trường mới': '🎯',
  'Đối thủ cạnh tranh': '🏃',
  'Hồ sơ': '📁',
  'Bảo hiểm': '🏥',
  'Đánh giá nhân sự': '📊',
  'Chế độ chính sách': '📜',
  'Đề xuất cải tiến': '💡',
  'Chung': '📌',
  'Nhân sự': '👥',
  'Kinh doanh': '💹',
  'Tuyển dụng': '📎',
  'QLDV': '🔄',
  'Giám sát': '👀',
  'Báo cáo': '📊',
  'Phát sinh': '⚡',
  'Kế hoạch': '📅',
  'Đề xuất': '💡',
  'CV Khác': '📋',
  'Ý kiến KH': '💭',
};
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProjects();
    _loadSavedUserList();
    _syncData();
    _loadReports();
    _setDefaultChiaSe(widget.userType);
    topicList = userTypeTopics[widget.userType] ?? userTypeTopics['HM-DV'] ?? [];
  }
late List<String> topicList;
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
        _selectedShare = []; // No default value
    }
  }

  @override
  void dispose() {
    _moTaChungController.dispose();
    _giaiPhapChungController.dispose();
    _danhGiaNSController.dispose();
    _giaiPhapNSController.dispose();
    _danhGiaCLController.dispose();
    _giaiPhapCLController.dispose();
    _danhGiaVTController.dispose();
    _giaiPhapVTController.dispose();
    _danhGiaYKienKhachHangController.dispose();
    _giaiPhapYKienKhachHangController.dispose();
    _danhGiaMayMocController.dispose();
    _giaiPhapMayMocController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedUserList() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userList = prefs.getStringList('userList') ?? [];
    });
  }

  Future<void> _syncData() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final userCredentials = Provider.of<UserCredentials>(context, listen: false);
      final username = userCredentials.username.toLowerCase();

      final userListResponse = await AuthenticatedHttpClient.get(Uri.parse('$baseUrl/userlist'));
      if (userListResponse.statusCode != 200) throw Exception('Failed to load user list');
      final List<dynamic> userListData = json.decode(userListResponse.body);
      setState(() => _userList = List<String>.from(userListData));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('userList', _userList);

      final reportsResponse = await AuthenticatedHttpClient.get(Uri.parse('$baseUrl/userbaocao/$username'));
      if (reportsResponse.statusCode != 200) throw Exception('Failed to load reports');
      final List<dynamic> reportsData = json.decode(reportsResponse.body);
      await dbHelper.clearTable(DatabaseTables.baocaoTable);
      for (var report in reportsData) {
        await dbHelper.insertBaocao(BaocaoModel.fromMap(report));
      }
      _showSuccess('Đồng bộ thành công');
    } catch (e) {
      print('Error syncing: $e');
      _showError('Lỗi đồng bộ: ${e.toString()}');
    } finally {
      setState(() => _isSyncing = false);
    }
  }
  Future<void> _loadProjects() async {
  try {
    final List<String> projects = await dbHelper.getUserBoPhanList();
    setState(() {
      _projectList = projects;
      // Auto-select first project if list is not empty
      if (_projectList.isNotEmpty && _selectedProject == null) {
        _selectedProject = _projectList[0];
      }
    });
  } catch (e) {
    _showError('Error loading projects: $e');
  }
}
  Future<bool> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
        return true;
      }
      return false;
    } catch (e) {
      _showError('Error picking image: $e');
      return false;
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Chọn từ thư viện'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera),
                title: Text('Chụp ảnh mới'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _submitReport({bool createTask = false, DateTime? taskDate, String? taskContent}) async {
  if (!_formKey.currentState!.validate()) return;

  final userCredentials = Provider.of<UserCredentials>(context, listen: false);
  final username = userCredentials.username;
  final uuid = Uuid().v4();
  final now = DateTime.now();

  // Capture current values before any state changes
  final currentProject = _selectedProject;
  final currentShares = List<String>.from(_selectedShare);
  final currentTopic = _selectedTopic;

  try {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/baocaocongviec'));
    
    if (_imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath('image', _imageFile!.path));
    }

    // Format date and time properly
    final formattedDate = now.toIso8601String().split('T')[0]; // YYYY-MM-DD
    final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    request.fields.addAll({
      'uid': uuid,
      'ngay': formattedDate,
      'gio': formattedTime,
      'nguoiDung': username ?? '',
      'boPhan': currentProject ?? '',
      'chiaSe': currentShares.join(','),
      'phanLoai': currentTopic ?? '',
      'moTaChung': _moTaChungController.text.trim().isEmpty ? '.' : _moTaChungController.text.trim(),
      'giaiPhapChung': _giaiPhapChungController.text.trim().isEmpty ? '.' : _giaiPhapChungController.text.trim(),
      'danhGiaNS': _danhGiaNSController.text.trim().isEmpty ? '.' : _danhGiaNSController.text.trim(),
      'giaiPhapNS': _giaiPhapNSController.text.trim().isEmpty ? '.' : _giaiPhapNSController.text.trim(),
      'danhGiaCL': _danhGiaCLController.text.trim().isEmpty ? '.' : _danhGiaCLController.text.trim(),
      'giaiPhapCL': _giaiPhapCLController.text.trim().isEmpty ? '.' : _giaiPhapCLController.text.trim(),
      'danhGiaVT': _danhGiaVTController.text.trim().isEmpty ? '.' : _danhGiaVTController.text.trim(),
      'giaiPhapVT': _giaiPhapVTController.text.trim().isEmpty ? '.' : _giaiPhapVTController.text.trim(),
      'danhGiaYKienKhachHang': _danhGiaYKienKhachHangController.text.trim().isEmpty ? '.' : _danhGiaYKienKhachHangController.text.trim(),
      'giaiPhapYKienKhachHang': _giaiPhapYKienKhachHangController.text.trim().isEmpty ? '.' : _giaiPhapYKienKhachHangController.text.trim(),
      'danhGiaMayMoc': _danhGiaMayMocController.text.trim().isEmpty ? '.' : _danhGiaMayMocController.text.trim(),
      'giaiPhapMayMoc': _giaiPhapMayMocController.text.trim().isEmpty ? '.' : _giaiPhapMayMocController.text.trim(),
      'nhom': 'Báo cáo',
      'phatSinh': 'Không',
      'xetDuyet': 'Chưa duyệt',
    });

    // Print the request fields for debugging
    print('Submitting report with fields:');
    request.fields.forEach((key, value) {
      print('$key: $value');
    });

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    print('Server response: $responseData');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(responseData);
      final report = BaocaoModel.fromMap(data);
      await dbHelper.insertBaocao(report);

      // Now handle task submission if requested
      if (createTask && taskDate != null && taskContent != null) {
        final taskUuid = Uuid().v4();
        final taskFormattedDate = taskDate.toIso8601String().split('T')[0];

        final taskData = {
          'uid': taskUuid,
          'ngay': taskFormattedDate,
          'gio': formattedTime,
          'nguoiDung': username ?? '',
          'boPhan': currentProject ?? '',  // Use the captured values
          'chiaSe': currentShares.join(','),  // Use the captured values
          'phanLoai': 'Cả ngày',
          'moTaChung': taskContent.trim().isEmpty ? '.' : taskContent.trim(),
          'nhom': 'Kế hoạch',
          'phatSinh': 'Có',
          'xetDuyet': 'Chưa duyệt',
        };

        print('Submitting task with data:');
        taskData.forEach((key, value) {
          print('$key: $value');
        });

        final taskResponse = await http.post(
          Uri.parse('$baseUrl/submitplan'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(taskData),
        );

        final taskResponseData = await taskResponse.body;
        print('Server response for task: $taskResponseData');

        if (taskResponse.statusCode == 200) {
          _showSuccess('Báo cáo và hẹn xử lý đã được gửi thành công');
        } else {
          throw Exception('Báo cáo đã gửi nhưng lỗi tạo hẹn: ${taskResponse.statusCode}');
        }
      } else {
        _showSuccess('Báo cáo đã được gửi thành công');
      }

      _formKey.currentState?.reset(); // Reset the form
      setState(() {
        _selectedProject = null;
        _selectedTopic = null;
        _selectedShare = [];
        _imageFile = null;
        _moTaChungController.clear();
        _giaiPhapChungController.clear();
        _danhGiaNSController.clear();
        _giaiPhapNSController.clear();
        _danhGiaCLController.clear();
        _giaiPhapCLController.clear();
        _danhGiaVTController.clear();
        _giaiPhapVTController.clear();
        _danhGiaYKienKhachHangController.clear();
        _giaiPhapYKienKhachHangController.clear();
        _danhGiaMayMocController.clear();
        _giaiPhapMayMocController.clear();
      });
      
      Navigator.of(context).pop();
      _loadReports(); // Reload the reports list
    } else {
      throw Exception('Failed to submit report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error submitting report: $e');
    _showError('Error submitting report: $e');
  }
}

  Future<void> _loadReports() async {
    try {
      final reports = await dbHelper.getAllBaocao();
      setState(() {
        _reports = reports;
      });
    } catch (e) {
      _showError('Error loading reports: $e');
    }
  }
  Future<void> _submitTask(DateTime taskDate, String content) async {
  final userCredentials = Provider.of<UserCredentials>(context, listen: false);
  final username = userCredentials.username;
  final uuid = Uuid().v4();
  final now = DateTime.now();

  try {
    // Format dates properly
    final formattedDate = taskDate.toIso8601String().split('T')[0]; // YYYY-MM-DD
    final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Make sure we're capturing the current values, not the class variables
    final currentProject = _selectedProject;
    final currentShares = _selectedShare;

    final taskData = {
      'uid': uuid,
      'ngay': formattedDate,
      'gio': formattedTime,
      'nguoiDung': username ?? '',
      'boPhan': currentProject ?? '', // Explicitly use the current project value
      'chiaSe': currentShares.join(','), // Explicitly use the current shares
      'phanLoai': 'Cả ngày',
      'moTaChung': content.trim().isEmpty ? '.' : content.trim(),
      'nhom': 'Kế hoạch',
      'phatSinh': 'Có',
      'xetDuyet': 'Chưa duyệt',
    };

    // Print for debugging
    print('Submitting task with data:');
    taskData.forEach((key, value) {
      print('$key: $value');
    });

    final response = await http.post(
      Uri.parse('$baseUrl/submitplan'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(taskData),
    );

    final responseData = await response.body;
    print('Server response for task: $responseData');

    if (response.statusCode == 200) {
      _showSuccess('Hẹn xử lý đã được tạo thành công');
    } else {
      throw Exception('Failed to create task: ${response.statusCode}');
    }
  } catch (e) {
    print('Error submitting task: $e');
    _showError('Error creating task: $e');
  }
}
Future<void> _showReportDialog() async {
  bool _createTask = false;
  DateTime _taskDate = DateTime.now().add(Duration(days: 1)); // Default to tomorrow
  final _taskContentController = TextEditingController();
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(
                title: Text('Tạo báo cáo'),
                leading: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  TextButton(
  onPressed: () {
    _submitReport(
      createTask: _createTask,
      taskDate: _createTask ? _taskDate : null,
      taskContent: _createTask ? _taskContentController.text : null
    );
  },
  child: Text('Gửi'),
),
                ],
              ),
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_imageFile != null)
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Image.file(
                              _imageFile!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _imageFile = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.image),
                        label: Text(_imageFile == null ? 'Chọn ảnh' : 'Đổi ảnh khác'),
                        onPressed: _showImagePickerOptions,
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: MultiSelectDialogField<String>(
                              items: _userList.map((user) => MultiSelectItem<String>(user, user)).toList(),
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
                      TextFormField(
                        controller: _moTaChungController,
                        decoration: InputDecoration(
                          labelText: 'Mô tả chung',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập mô tả';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _giaiPhapChungController,
                        decoration: InputDecoration(
                          labelText: 'Giải pháp chung',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: 16),
                      if (_selectedTopic == 'Kiểm tra dự án') ...[
                        TextFormField(
                          controller: _danhGiaNSController,
                          decoration: InputDecoration(
                            labelText: 'Đánh giá nhân sự',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _giaiPhapNSController,
                          decoration: InputDecoration(
                            labelText: 'Giải pháp nhân sự',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _danhGiaCLController,
                          decoration: InputDecoration(
                            labelText: 'Đánh giá chất lượng',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _giaiPhapCLController,
                          decoration: InputDecoration(
                            labelText: 'Giải pháp chất lượng',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _danhGiaVTController,
                          decoration: InputDecoration(
                            labelText: 'Đánh giá vật tư',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _giaiPhapVTController,
                          decoration: InputDecoration(
                            labelText: 'Giải pháp vật tư',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _danhGiaYKienKhachHangController,
                          decoration: InputDecoration(
                            labelText: 'Đánh giá ý kiến khách hàng',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _giaiPhapYKienKhachHangController,
                          decoration: InputDecoration(
                            labelText: 'Giải pháp ý kiến khách hàng',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _danhGiaMayMocController,
                          decoration: InputDecoration(
                            labelText: 'Đánh giá máy móc',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _giaiPhapMayMocController,
                          decoration: InputDecoration(
                            labelText: 'Giải pháp máy móc',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                      ],
                      SizedBox(height: 24),
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
                                      
                                      // Initialize task content when toggled on
                                      if (_createTask) {
                                        // Prioritize giaiPhapChung if it has content
                                        if (_giaiPhapChungController.text.isNotEmpty && 
                                            _giaiPhapChungController.text != '.') {
                                          _taskContentController.text = _giaiPhapChungController.text;
                                        } 
                                        // Otherwise use moTaChung
                                        else if (_moTaChungController.text.isNotEmpty && 
                                                 _moTaChungController.text != '.') {
                                          _taskContentController.text = _moTaChungController.text;
                                        }
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
                                validator: (value) {
                                  if (_createTask && (value == null || value.isEmpty)) {
                                    return 'Vui lòng nhập nội dung hẹn xử lý';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      );
    },
  );
}

  Widget _buildReportList(bool isMyReports) {
  final userCredentials = Provider.of<UserCredentials>(context, listen: false);
  final username = userCredentials.username;

  final filteredReports = _reports.where((report) {
    if (isMyReports) {
      return report.nguoiDung == username && report.nhom == "Báo cáo";
    } else {
      return report.nguoiDung != username && 
             (report.chiaSe?.split(',').contains(username) ?? false) &&
             report.nhom == "Báo cáo";
    }
  }).toList();

  // Sort the reports by date in descending order
  filteredReports.sort((a, b) {
    int dateComparison = b.ngay.compareTo(a.ngay);
    if (dateComparison != 0) return dateComparison;
    return b.gio.compareTo(a.gio);
  });

  return ListView.builder(
    itemCount: filteredReports.length,
    itemBuilder: (context, index) {
      final report = filteredReports[index];
      return Card(
  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  child: ListTile(
    leading: Text(
      topicIcons[report.phanLoai] ?? '📄',
      style: TextStyle(fontSize: 24),
    ),
    title: Text('${report.boPhan} - ${report.phanLoai}'),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${report.ngay.toString().substring(0, 10)} ${report.gio}',
          style: TextStyle(fontSize: 12),
        ),
        Text(
          'Người gửi: ${report.nguoiDung}',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    ),
    onTap: () {
      _showReportDetails(report);
    },
  ),
);
    },
  );
}
void _showReportDetails(BaocaoModel report) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Chi tiết báo cáo'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (report.hinhAnh != null && report.hinhAnh!.isNotEmpty)
                Container(
                  height: 200,
                  width: double.infinity,
                  child: Image.network(
                    report.hinhAnh!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                      Center(child: Text('Unable to load image')),
                  ),
                ),
              SizedBox(height: 16),
              Text(
                'Mô tả chung:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(report.moTaChung ?? 'N/A'),
              SizedBox(height: 8),
              Text(
                'Giải pháp chung:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(report.giaiPhapChung ?? 'N/A'),
              if (report.phanLoai == 'Kiểm tra dự án') ...[
                if (report.danhGiaNS != null) ...[
                  SizedBox(height: 8),
                  Text(
                    'Đánh giá nhân sự:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(report.danhGiaNS!),
                  Text(
                    'Giải pháp nhân sự:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(report.giaiPhapNS ?? 'N/A'),
                ],
                // Add other evaluation fields similarly...
              ],
              SizedBox(height: 8),
              Text(
                'Người tạo: ${report.nguoiDung}',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (report.chiaSe != null && report.chiaSe!.isNotEmpty)
                Text(
                  'Chia sẻ với: ${report.chiaSe}',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Đóng'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    },
  );
}
Widget _buildReportChart(List<BaocaoModel> reports) {
  final grouped = groupBy<BaocaoModel, String>(reports, (BaocaoModel r) => 
    "${r.ngay.year}-${r.ngay.month.toString().padLeft(2, '0')}-${r.ngay.day.toString().padLeft(2, '0')}");
  
  return Container(
    height: 200,
    child: LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(show: true),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: grouped.entries
              .mapIndexed((index, entry) => 
                FlSpot(index.toDouble(), entry.value.length.toDouble()))
              .toList(),
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
            dotData: FlDotData(show: true),
          ),
        ],
      ),
    ),
  );
}
void _createWeeklySummarySheet(Excel excel, List<BaocaoModel> reports) {
  final sheet = excel['Tổng hợp tuần'];
  
  // Headers
  sheet.cell(CellIndex.indexByString("A1")).value = "Tuần";
  sheet.cell(CellIndex.indexByString("B1")).value = "Số dự án";
  sheet.cell(CellIndex.indexByString("C1")).value = "Đã xử lý";

  // Group by week
  final groupedByWeek = groupBy<BaocaoModel, String>(reports, (BaocaoModel r) {
  final date = r.ngay;
  return '${date.year}-W${(date.difference(DateTime(date.year, 1, 1)).inDays / 7).ceil()}';
});

  var row = 2;
  groupedByWeek.forEach((week, weekReports) {
    final uniqueProjects = weekReports.map((r) => r.boPhan).toSet();
    final processedReports = weekReports.where((r) => 
      r.giaiPhapChung != null && r.giaiPhapChung!.isNotEmpty).length;

    sheet.cell(CellIndex.indexByString("A$row")).value = week;
    sheet.cell(CellIndex.indexByString("B$row")).value = uniqueProjects.length;
    sheet.cell(CellIndex.indexByString("C$row")).value = 
      "${processedReports}/${weekReports.length}";
    
    row++;
  });
}

void _createMonthlySummarySheet(Excel excel, List<BaocaoModel> reports) {
  final sheet = excel['Tổng hợp tháng'];
  
  // Headers
  sheet.cell(CellIndex.indexByString("A1")).value = "Tháng";
  sheet.cell(CellIndex.indexByString("B1")).value = "Số dự án";
  sheet.cell(CellIndex.indexByString("C1")).value = "Đã xử lý";

  // Group by month
  final groupedByMonth = groupBy<BaocaoModel, String>(reports, (BaocaoModel r) {
  final date = r.ngay;
  return '${date.year}-${date.month.toString().padLeft(2, '0')}';
});

  var row = 2;
  groupedByMonth.forEach((month, monthReports) {
    final uniqueProjects = monthReports.map((r) => r.boPhan).toSet();
    final processedReports = monthReports.where((r) => 
      r.giaiPhapChung != null && r.giaiPhapChung!.isNotEmpty).length;

    sheet.cell(CellIndex.indexByString("A$row")).value = month;
    sheet.cell(CellIndex.indexByString("B$row")).value = uniqueProjects.length;
    sheet.cell(CellIndex.indexByString("C$row")).value = 
      "${processedReports}/${monthReports.length}";
    
    row++;
  });
}

void _createDetailedReportSheet(Excel excel, List<BaocaoModel> reports) {
  final sheet = excel['Chi tiết báo cáo'];
  
  // Define all headers
  final headers = {
    "A": "Ngày",
    "B": "Giờ",
    "C": "Người dùng",
    "D": "Bộ phận",
    "E": "Phân loại",
    "F": "Mô tả chung",
    "G": "Giải pháp chung",
    "H": "Đánh giá NS",
    "I": "Giải pháp NS",
    "J": "Đánh giá CL",
    "K": "Giải pháp CL",
    "L": "Đánh giá VT",
    "M": "Giải pháp VT",
    "N": "Đánh giá YKKH",
    "O": "Giải pháp YKKH",
    "P": "Đánh giá máy móc",
    "Q": "Giải pháp máy móc",
    "R": "Chia sẻ với",
    "S": "Hình ảnh"
  };

  // Add headers
  headers.forEach((column, title) {
    sheet.cell(CellIndex.indexByString("${column}1")).value = title;
  });

  var row = 2;
  for (var report in reports) {
    // Add data for each row
    sheet.cell(CellIndex.indexByString("A$row")).value = report.ngay.toString();
    sheet.cell(CellIndex.indexByString("B$row")).value = report.gio;
    sheet.cell(CellIndex.indexByString("C$row")).value = report.nguoiDung;
    sheet.cell(CellIndex.indexByString("D$row")).value = report.boPhan;
    sheet.cell(CellIndex.indexByString("E$row")).value = report.phanLoai;
    sheet.cell(CellIndex.indexByString("F$row")).value = report.moTaChung;
    sheet.cell(CellIndex.indexByString("G$row")).value = report.giaiPhapChung;
    sheet.cell(CellIndex.indexByString("H$row")).value = report.danhGiaNS;
    sheet.cell(CellIndex.indexByString("I$row")).value = report.giaiPhapNS;
    sheet.cell(CellIndex.indexByString("J$row")).value = report.danhGiaCL;
    sheet.cell(CellIndex.indexByString("K$row")).value = report.giaiPhapCL;
    sheet.cell(CellIndex.indexByString("L$row")).value = report.danhGiaVT;
    sheet.cell(CellIndex.indexByString("M$row")).value = report.giaiPhapVT;
    sheet.cell(CellIndex.indexByString("N$row")).value = report.danhGiaYKienKhachHang;
    sheet.cell(CellIndex.indexByString("O$row")).value = report.giaiPhapYKienKhachHang;
    sheet.cell(CellIndex.indexByString("P$row")).value = report.danhGiaMayMoc;
    sheet.cell(CellIndex.indexByString("Q$row")).value = report.giaiPhapMayMoc;
    sheet.cell(CellIndex.indexByString("R$row")).value = report.chiaSe;
    sheet.cell(CellIndex.indexByString("S$row")).value = report.hinhAnh;
    
    row++;
  }
}

void _createEmployeeSummarySheet(Excel excel, List<BaocaoModel> reports) {
  final sheet = excel['Tổng hợp theo NV'];
  
  // Get unique dates and users
final dates = reports.map((BaocaoModel r) => 
  "${r.ngay.year}-${r.ngay.month.toString().padLeft(2, '0')}-${r.ngay.day.toString().padLeft(2, '0')}")
  .toSet().toList()..sort();
    final users = reports.map((r) => r.nguoiDung).toSet().toList()..sort();

  // Headers
  sheet.cell(CellIndex.indexByString("A1")).value = "Nhân viên";
  var col = 1;
  for (var date in dates) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).value = date;
    col++;
  }

  var row = 1;
  for (var user in users) {
    sheet.cell(CellIndex.indexByString("A${row + 1}")).value = user;
    
    col = 1;
    for (var date in dates) {
     final dailyReports = reports.where((BaocaoModel r) => 
  r.nguoiDung == user && 
  "${r.ngay.year}-${r.ngay.month.toString().padLeft(2, '0')}-${r.ngay.day.toString().padLeft(2, '0')}" == date
).toList();
      
      if (dailyReports.isNotEmpty) {
        final uniqueProjects = dailyReports.map((r) => r.boPhan).toSet().length;
        final unprocessed = dailyReports.where((r) => 
          r.giaiPhapChung == null || r.giaiPhapChung!.isEmpty).length;
          
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
          .value = "${dailyReports.length}/$uniqueProjects/$unprocessed";
      }
      
      col++;
    }
    row++;
  }
}
void _createDailySummarySheet(Excel excel, List<BaocaoModel> reports) {
  final sheet = excel['Tổng hợp ngày'];
  
  // Headers
  sheet.cell(CellIndex.indexByString("A1")).value = "Ngày";
  sheet.cell(CellIndex.indexByString("B1")).value = "Số dự án";
  sheet.cell(CellIndex.indexByString("C1")).value = "Đã xử lý";
  
  // Group by date
  final groupedByDate = groupBy<BaocaoModel, String>(reports, (BaocaoModel r) => 
  "${r.ngay.year}-${r.ngay.month.toString().padLeft(2, '0')}-${r.ngay.day.toString().padLeft(2, '0')}");
  
  var row = 2;
  groupedByDate.forEach((date, dateReports) {
    final uniqueProjects = dateReports.map((r) => r.boPhan).toSet();
    final processedReports = dateReports.where((r) => 
      r.giaiPhapChung != null && r.giaiPhapChung!.isNotEmpty).length;
      
    sheet.cell(CellIndex.indexByString("A$row")).value = date;
    sheet.cell(CellIndex.indexByString("B$row")).value = uniqueProjects.length;
    sheet.cell(CellIndex.indexByString("C$row")).value = 
      "${processedReports}/${dateReports.length}";
    
    row++;
  });
}

Future<void> _generateReport(DateTime startDate, DateTime endDate) async {
  // Show loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Center(
        child: CircularProgressIndicator(),
      );
    },
  );

  try {
    print('Start Date: $startDate');
    print('End Date: $endDate');
    
    // Filter reports by date range
    final filteredReports = _reports.where((report) {
  final reportDate = DateTime.parse(report.ngay.toString());
  return reportDate.isAfter(startDate.subtract(Duration(days: 1))) && 
         reportDate.isBefore(endDate.add(Duration(days: 1))) &&
         report.nhom == "Báo cáo";
}).toList();

    print('Filtered Reports Count: ${filteredReports.length}');

    if (filteredReports.isEmpty) {
      Navigator.of(context).pop(); // Hide loading
      _showError('Không có báo cáo trong khoảng thời gian này');
      return;
    }

    // Create Excel workbook
    final excel = Excel.createExcel();
    
    // Daily summary
    _createDailySummarySheet(excel, filteredReports);
    
    // Weekly summary
    _createWeeklySummarySheet(excel, filteredReports);
    
    // Monthly summary
    _createMonthlySummarySheet(excel, filteredReports);
    
    // Detailed report
    _createDetailedReportSheet(excel, filteredReports);
    
    // Employee summary
    _createEmployeeSummarySheet(excel, filteredReports);

    // Save file
    final bytes = excel.encode();
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/report.xlsx');
    await file.writeAsBytes(bytes!);

    // Hide loading dialog
    Navigator.of(context).pop();

    // Share file
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Báo cáo công việc',
    );

  } catch (e) {
    print('Error generating report: $e');
    Navigator.of(context).pop(); // Hide loading
    _showError('Lỗi tạo báo cáo: $e');
  }
}
void _showDateRangeDialog() {
  DateTime? startDate;
  DateTime? endDate;
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {  // Use a separate context for dialog
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Chọn khoảng thời gian'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('Ngày bắt đầu'),
                  subtitle: Text(startDate?.toString().split(' ')[0] ?? 'Chưa chọn'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        startDate = picked;
                      });
                    }
                  },
                ),
                ListTile(
                  title: Text('Ngày kết thúc'),
                  subtitle: Text(endDate?.toString().split(' ')[0] ?? 'Chưa chọn'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: startDate ?? DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        endDate = picked;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text('Hủy'),
                onPressed: () => Navigator.pop(dialogContext),
              ),
              TextButton(
  child: Text('Xác nhận'),
  onPressed: () {
    if (startDate != null && endDate != null) {
      Navigator.pop(dialogContext);
      _generateReport(startDate!, endDate!);
    } else {
      _showError('Vui lòng chọn ngày bắt đầu và kết thúc');
    }
  },
),
            ],
          );
        },
      );
    },
  );
}
Widget _buildProjectDropdown() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Chọn dự án:', style: TextStyle(fontWeight: FontWeight.bold)),
      SizedBox(height: 4),
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
        selectedItem: _selectedProject,
        onChanged: (String? newValue) {
          setState(() => _selectedProject = newValue);
        },
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    ],
  );
}
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Báo cáo CV'),
      actions: [
        IconButton(
          icon: _isSyncing 
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Icon(Icons.sync),
          onPressed: _isSyncing ? null : _syncData,
          tooltip: 'Đồng bộ',
        ),
      ],
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
    body: CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tạo báo cáo mới', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
  child: _buildProjectDropdown(),
),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Chọn chủ đề:', 
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedTopic,
                              items: topicList.map((String topic) {
                                return DropdownMenuItem<String>(
                                  value: topic,
                                  child: Text(topic),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() => _selectedTopic = newValue);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
  children: [
    Expanded(
      child: ElevatedButton(
        onPressed: _selectedProject != null && _selectedTopic != null 
          ? _showReportDialog 
          : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note, size: 20),
            Text(
              'Tạo\nbáo cáo', 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87),
            ),
          ],
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade100,
          padding: EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4), // Reduced roundedness
          ),
        ),
      ),
    ),
    SizedBox(width: 8),
    Expanded(
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => ProjectPlan(
    userType: widget.userType,
    selectedBoPhan: widget.selectedBoPhan,
  )),
);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, size: 20),
            Text(
              'Tạo\nkế hoạch', 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87),
            ),
          ],
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade100,
          padding: EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4), // Reduced roundedness
          ),
        ),
      ),
    ),
    SizedBox(width: 8),
    Expanded(
      child: ElevatedButton(
        onPressed: _showDateRangeDialog,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.summarize, size: 20),
            Text(
              'Tổng\nhợp', 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87),
            ),
          ],
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.pink.shade100,
          padding: EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4), // Reduced roundedness
          ),
        ),
      ),
    ),
  ],
),
                ],
              ),
            ),
          ),
        ),
        SliverFillRemaining(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
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
                        _buildReportTable(true),
                        _buildReportTable(false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
Widget _buildReportTable(bool isMyReports) {
  final userCredentials = Provider.of<UserCredentials>(context, listen: false);
  final username = userCredentials.username;

  final filteredReports = _reports.where((report) {
    if (isMyReports) {
      return report.nguoiDung == username && report.nhom == "Báo cáo";
    } else {
      return report.nguoiDung != username && 
             (report.chiaSe?.split(',').contains(username) ?? false) &&
             report.nhom == "Báo cáo";
    }
  }).toList();

  // Sort the reports by date in descending order
  filteredReports.sort((a, b) {
    // First compare dates
    int dateComparison = b.ngay.compareTo(a.ngay);
    if (dateComparison != 0) return dateComparison;
    // If dates are equal, compare times
    return b.gio.compareTo(a.gio);
  });

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: SingleChildScrollView(
      child: DataTable(
        columns: [
          DataColumn(label: Text('Ngày')),
          DataColumn(label: Text('Dự án')),
          DataColumn(label: Text('Chủ đề')),
          DataColumn(label: Text('Người tạo')),
          DataColumn(label: Text('Trạng thái')),
        ],
        rows: filteredReports.map((report) {
          return DataRow(
            cells: [
              DataCell(Text('${report.ngay.toString().substring(0, 10)} ${report.gio}')),
              DataCell(Text(report.boPhan ?? 'N/A')),
              DataCell(Row(
                children: [
                  Text(topicIcons[report.phanLoai ?? ''] ?? '📄'),
                  SizedBox(width: 8),
                  Text(report.phanLoai ?? 'N/A'),
                ],
              )),
              DataCell(Text(report.nguoiDung ?? 'N/A')),
              DataCell(
                TextButton(
                  child: Text('Chi tiết'),
                  onPressed: () => _showReportDetails(report),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    ),
  );
}
}