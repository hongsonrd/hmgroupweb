import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';

class CreateWorkRequestScreen extends StatefulWidget {
  @override
  _CreateWorkRequestScreenState createState() => _CreateWorkRequestScreenState();
}

class _CreateWorkRequestScreenState extends State<CreateWorkRequestScreen> {
  final DBHelper _dbHelper = DBHelper();
  final _formKey = GlobalKey<FormState>();
  
  // Form step tracking
  int _currentStep = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _errorMessage = '';
  
  // Form data
  String _username = '';
  String? _giaoViecID;
  String? _selectedDiaDiem;
  List<String> _diaDiemOptions = [];
  List<GoCleanTaiKhoanModel> _allUsers = [];
  List<GoCleanTaiKhoanModel> _filteredUsers = [];
  List<String> _selectedNguoiNghiemThu = [];
  String? _diaChi;
  String? _dinhVi;
  int _soNguoiThucHien = 1;
  String _lapLai = 'Một lần';
  DateTime _ngayBatDau = DateTime.now();
  DateTime _ngayKetThuc = DateTime.now();
  List<DateTime> _selectedDates = [];
  String _hinhThucNghiemThu = 'Tự động';
  
  // Form controllers
  final TextEditingController _moTaCongViecController = TextEditingController();
  final TextEditingController _khuVucThucHienController = TextEditingController();
  final TextEditingController _khoiLuongCongViecController = TextEditingController(text: '100');
  final TextEditingController _yeuCauCongViecController = TextEditingController();
  final TextEditingController _thoiGianBatDauController = TextEditingController(text: '08:00');
  final TextEditingController _thoiGianKetThucController = TextEditingController(text: '17:00');
  final TextEditingController _loaiMaySuDungController = TextEditingController(text: 'Không');
  final TextEditingController _congCuSuDungController = TextEditingController(text: 'Không');
  final TextEditingController _hoaChatSuDungController = TextEditingController(text: 'Không');
  final TextEditingController _ghiChuController = TextEditingController();
  
  // For calendar view
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _generateRandomID();
    _loadLocationOptions();
  }
  
  // Load username from provider
  Future<void> _loadUsername() async {
    try {
      final userCredentials = Provider.of<UserCredentials>(context, listen: false);
      setState(() {
        _username = userCredentials.username;
      });
      print('Username loaded: $_username');
    } catch (e) {
      print('Error loading username: $e');
    }
  }
  
  // Generate a random ID for the new request
  void _generateRandomID() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(10000).toString().padLeft(4, '0');
    
    setState(() {
      _giaoViecID = 'YC${timestamp.toString().substring(timestamp.toString().length - 6)}$randomPart';
    });
    print('Generated ID: $_giaoViecID');
  }
  
  // Load location options from database
  Future<void> _loadLocationOptions() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get all users
      final users = await _dbHelper.getAllGoCleanTaiKhoan();
      
      // Extract unique locations
      final locations = <String>{};
      for (var user in users) {
        if (user.diaDiem != null && user.diaDiem!.isNotEmpty) {
          locations.add(user.diaDiem!);
        }
      }
      
      setState(() {
        _allUsers = users;
        _diaDiemOptions = locations.toList()..sort();
        _isLoading = false;
      });
      
      print('Loaded ${_diaDiemOptions.length} unique locations');
    } catch (e) {
      print('Error loading location options: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải danh sách địa điểm: $e';
      });
    }
  }
  
  // When location is selected, filter users and update address
  void _onLocationSelected(String location) {
    setState(() {
      _selectedDiaDiem = location;
      
      // Filter users for this location with PhanLoai = "Thụ hưởng" and Admin = "Active"
      _filteredUsers = _allUsers.where((user) {
        return user.diaDiem == location && 
               (user.phanLoai == 'Thụ hưởng' || user.phanLoai?.contains('hưởng') == true) && 
               user.admin == 'Active';
      }).toList();
      
      // Reset selected users
      _selectedNguoiNghiemThu = [];
      
      // Set address from the first matching user
      final matchingUser = _allUsers.firstWhere(
        (user) => user.diaDiem == location,
        orElse: () => GoCleanTaiKhoanModel(),
      );
      
      if (matchingUser.diaChi != null && matchingUser.diaChi!.isNotEmpty) {
        _diaChi = matchingUser.diaChi;
      }
      
      if (matchingUser.dinhVi != null && matchingUser.dinhVi!.isNotEmpty) {
        _dinhVi = matchingUser.dinhVi;
      }
    });
    
    print('Selected location: $location, found ${_filteredUsers.length} eligible users');
    if (_diaChi != null) {
      print('Auto-filled address: $_diaChi');
    }
  }
  
  // Toggle user selection for NguoiNghiemThu
  void _toggleUserSelection(GoCleanTaiKhoanModel user) {
    setState(() {
      if (_selectedNguoiNghiemThu.contains(user.taiKhoan)) {
        _selectedNguoiNghiemThu.remove(user.taiKhoan);
      } else {
        _selectedNguoiNghiemThu.add(user.taiKhoan!);
      }
    });
    
    print('Selected users: ${_selectedNguoiNghiemThu.join(", ")}');
  }
  
  // When user selects a date in the calendar
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      if (_lapLai == 'Một lần') {
        // For one-time tasks, just set start and end dates to the selected day
        _ngayBatDau = selectedDay;
        _ngayKetThuc = selectedDay;
        _selectedDates = [selectedDay];
      } else {
        // For recurring tasks, toggle the selected date in the list
        final index = _selectedDates.indexWhere(
          (date) => isSameDay(date, selectedDay)
        );
        
        if (index >= 0) {
          _selectedDates.removeAt(index);
        } else {
          _selectedDates.add(selectedDay);
        }
        
        // Update start and end dates based on selection
        if (_selectedDates.isNotEmpty) {
          _selectedDates.sort((a, b) => a.compareTo(b));
          _ngayBatDau = _selectedDates.first;
          _ngayKetThuc = _selectedDates.last;
        }
      }
      
      _focusedDay = focusedDay;
    });
    
    if (_lapLai == 'Một lần') {
      print('Selected date for one-time task: $_ngayBatDau');
    } else {
      print('Selected dates for recurring task: ${_selectedDates.map((d) => '${d.day}/${d.month}/${d.year}').join(', ')}');
      print('Date range: ${_ngayBatDau.day}/${_ngayBatDau.month} - ${_ngayKetThuc.day}/${_ngayKetThuc.month}');
    }
  }
  
  // Create the individual task records
  List<GoCleanCongViecModel> _generateTaskRecords() {
    final tasks = <GoCleanCongViecModel>[];
    
    // Get the dates to create tasks for
    final dates = _lapLai == 'Một lần' ? [_ngayBatDau] : _selectedDates;
    
    // For each date and each staff member needed, create a task
    for (var date in dates) {
      for (var i = 0; i < _soNguoiThucHien; i++) {
        final taskId = '${_giaoViecID}_${date.day}${date.month}${date.year}_${i + 1}';
        
        final task = GoCleanCongViecModel(
          lichLamViecID: taskId,
          giaoViecID: _giaoViecID,
          ngay: date,
          nguoiThucHien: '',
          xacNhan: 'Chưa có',
          qrCode: '',
          mocBatDau: '',
          hinhAnhTruoc: '',
          mocKetThuc: '',
          hinhAnhSau: '',
          thucHienDanhGia: 0,
          moTaThucHien: '',
          khachHang: '',
          khachHangDanhGia: 0,
          thoiGianDanhGia: '',
          khachHangMoTa: '',
          khachHangChupAnh: '',
          trangThai: '',
        );
        
        tasks.add(task);
      }
    }
    
    print('Generated ${tasks.length} task records');
    return tasks;
  }
  
  // Submit the work request
  Future<void> _submitWorkRequest() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });
    
    try {
      // Create the work request model
      final workRequest = GoCleanYeuCauModel(
        giaoViecID: _giaoViecID,
        nguoiTao: _username,
        nguoiNghiemThu: _selectedNguoiNghiemThu.join(', '),
        diaDiem: _selectedDiaDiem,
        diaChi: _diaChi,
        dinhVi: _dinhVi,
        lapLai: _lapLai,
        ngayBatDau: _ngayBatDau,
        ngayKetThuc: _ngayKetThuc,
        hinhThucNghiemThu: _hinhThucNghiemThu,
        moTaCongViec: _moTaCongViecController.text,
        soNguoiThucHien: _soNguoiThucHien,
        khuVucThucHien: _khuVucThucHienController.text,
        khoiLuongCongViec: int.tryParse(_khoiLuongCongViecController.text) ?? 100,
        yeuCauCongViec: _yeuCauCongViecController.text,
        thoiGianBatDau: _thoiGianBatDauController.text,
        thoiGianKetThuc: _thoiGianKetThucController.text,
        loaiMaySuDung: _loaiMaySuDungController.text,
        congCuSuDung: _congCuSuDungController.text,
        hoaChatSuDung: _hoaChatSuDungController.text,
        ghiChu: _ghiChuController.text,
        xacNhan: 'Chờ xác nhận',
        chiDinh: '',
        huongDan: '',
        nhomThucHien: '',
        caNhanThucHien: '',
        listNguoiThucHien: '',
      );
      
      // Generate task records
      final taskRecords = _generateTaskRecords();
      print('${json.encode(workRequest.toMap())}');
      // Submit work request to server
      final workRequestResponse = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/cleanyeucaumoi/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(workRequest.toMap()),
      );
      
      print('Work request submission status: ${workRequestResponse.statusCode}');
      print('Response: ${workRequestResponse.body}');
      
      if (workRequestResponse.statusCode != 200) {
        throw Exception('Lỗi khi gửi yêu cầu: ${workRequestResponse.body}');
      }
      
      // Submit task records to server
      for (var task in taskRecords) {
        final taskResponse = await http.post(
          Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/cleancongviecmoi/'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(task.toMap()),
        );
        
        print('Task submission status for ${task.lichLamViecID}: ${taskResponse.statusCode}');
        
        if (taskResponse.statusCode != 200) {
          print('Error submitting task: ${taskResponse.body}');
        }
      }
      
      // Also save locally
      await _dbHelper.insertGoCleanYeuCau(workRequest);
      for (var task in taskRecords) {
        await _dbHelper.insertGoCleanCongViec(task);
      }
      
      // Show success message and navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tạo yêu cầu công việc thành công'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context, true); // Return true to indicate success
      
    } catch (e) {
      print('Error submitting work request: $e');
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Lỗi khi gửi yêu cầu: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $_errorMessage'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Show confirmation dialog
  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận thông tin'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildConfirmationItem('ID', _giaoViecID ?? ''),
              _buildConfirmationItem('Địa điểm', _selectedDiaDiem ?? ''),
              _buildConfirmationItem('Người tạo', _username),
              _buildConfirmationItem('Người nghiệm thu', _selectedNguoiNghiemThu.join(', ')),
              _buildConfirmationItem('Địa chỉ', _diaChi ?? ''),
              _buildConfirmationItem('Số người thực hiện', _soNguoiThucHien.toString()),
              _buildConfirmationItem('Loại lặp lại', _lapLai),
              _buildConfirmationItem('Ngày bắt đầu', '${_ngayBatDau.day}/${_ngayBatDau.month}/${_ngayBatDau.year}'),
              _buildConfirmationItem('Ngày kết thúc', '${_ngayKetThuc.day}/${_ngayKetThuc.month}/${_ngayKetThuc.year}'),
              
              if (_lapLai == 'Nhiều lần')
                _buildConfirmationItem('Số ngày đã chọn', '${_selectedDates.length} ngày'),
                
              _buildConfirmationItem('Số công việc sẽ tạo', 
                (_lapLai == 'Một lần' ? 1 : _selectedDates.length) * _soNguoiThucHien),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Quay lại chỉnh sửa'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentStep = 2; // Move to the next step after confirmation
              });
            },
            child: Text('Xác nhận và tiếp tục'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConfirmationItem(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tạo yêu cầu công việc mới'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Stepper(
                currentStep: _currentStep,
                onStepContinue: () {
                  if (_currentStep == 0) {
                    // Check if required fields in step 1 are filled
                    if (_selectedDiaDiem == null || _selectedNguoiNghiemThu.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Vui lòng chọn địa điểm và người nghiệm thu'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    setState(() {
                      _currentStep += 1;
                    });
                  } else if (_currentStep == 1) {
                    // In step 2, show confirmation dialog
                    if (_lapLai == 'Một lần' && _ngayBatDau.isBefore(DateTime.now())) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ngày bắt đầu không thể trước ngày hiện tại'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    if (_lapLai == 'Nhiều lần' && _selectedDates.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Vui lòng chọn ít nhất một ngày trong lịch'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    _showConfirmationDialog();
                  } else if (_currentStep == 2) {
                    // Submit in final step
                    _submitWorkRequest();
                  }
                },
                onStepCancel: () {
                  if (_currentStep > 0) {
                    setState(() {
                      _currentStep -= 1;
                    });
                  }
                },
                steps: [
                  // Step 1: Basic Information
                  Step(
                    title: Text('Thông tin cơ bản'),
                    content: _buildBasicInfoStep(),
                    isActive: _currentStep >= 0,
                  ),
                  
                  // Step 2: Dates and Schedule
                  Step(
                    title: Text('Lịch trình'),
                    content: _buildScheduleStep(),
                    isActive: _currentStep >= 1,
                  ),
                  
                  // Step 3: Task Details
                  Step(
                    title: Text('Chi tiết công việc'),
                    content: _buildTaskDetailsStep(),
                    isActive: _currentStep >= 2,
                  ),
                ],
                controlsBuilder: (context, details) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      children: [
                        if (_currentStep < 2)
                          ElevatedButton(
                            onPressed: details.onStepContinue,
                            child: Text(_currentStep == 1 ? 'Xác nhận' : 'Tiếp tục'),
                          ),
                        if (_currentStep == 2)
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : details.onStepContinue,
                            child: _isSubmitting 
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Đang gửi...'),
                                    ],
                                  )
                                : Text('Tạo yêu cầu'),
                          ),
                        SizedBox(width: 8),
                        if (_currentStep > 0)
                          TextButton(
                            onPressed: details.onStepCancel,
                            child: Text('Quay lại'),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
  
  // First step: Basic Info
  Widget _buildBasicInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Location selection
        Text(
          'Địa điểm',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            hintText: 'Chọn địa điểm',
          ),
          value: _selectedDiaDiem,
          items: _diaDiemOptions.map((location) {
            return DropdownMenuItem<String>(
              value: location,
              child: Text(location),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              _onLocationSelected(value);
            }
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vui lòng chọn địa điểm';
            }
            return null;
          },
        ),
        
        SizedBox(height: 16),
        
        // If location is selected, show supervisors selection
        if (_selectedDiaDiem != null) ...[
          Text(
            'Người nghiệm thu',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          
          Container(
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: _filteredUsers.isEmpty
              ? Center(
                  child: Text(
                    'Không có người dùng phù hợp ở địa điểm này',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    return CheckboxListTile(
                      title: Text(user.taiKhoan ?? 'Unknown'),
                      subtitle: Text(user.phanLoai ?? 'Unknown'),
                      value: _selectedNguoiNghiemThu.contains(user.taiKhoan),
                      onChanged: (selected) {
                        if (user.taiKhoan != null) {
                          _toggleUserSelection(user);
                        }
                      },
                    );
                  },
                ),
          ),
          
          SizedBox(height: 16),
          
          // Address (auto-filled but editable)
          Text(
            'Địa chỉ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          
          TextFormField(
            initialValue: _diaChi,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              hintText: 'Địa chỉ chi tiết',
            ),
            onChanged: (value) {
              setState(() {
                _diaChi = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập địa chỉ';
              }
              return null;
            },
          ),
          
          SizedBox(height: 16),
          
          // Staff count
          Text(
            'Số người thực hiện',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Expanded(
                  child: RadioListTile<int>(
                    title: Text('$i'),
                    value: i,
                    groupValue: _soNguoiThucHien,
                    onChanged: (value) {
                      setState(() {
                        _soNguoiThucHien = value!;
                      });
                    },
                    dense: true,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
  
  // Second step: Schedule
  Widget _buildScheduleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Repeat type
        Text(
          'Loại lặp lại',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: Text('Một lần', style: TextStyle(fontSize: 12)),
                value: 'Một lần',
                groupValue: _lapLai,
                onChanged: (value) {
                  setState(() {
                    _lapLai = value!;
                    _selectedDates = _ngayBatDau != null ? [_ngayBatDau] : [];
                  });
                },
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: Text('Nhiều lần', style: TextStyle(fontSize: 12)),
                value: 'Nhiều lần',
                groupValue: _lapLai,
                onChanged: (value) {
                  setState(() {
                    _lapLai = value!;
                    // Reset selection for multiple days
                    _selectedDates = [];
                  });
                },
              ),
            ),
          ],
        ),
        
        SizedBox(height: 16),
        
        // Date selection
        Text(
          _lapLai == 'Một lần' ? 'Chọn ngày' : 'Chọn các ngày thực hiện',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        
        // Calendar view
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TableCalendar(
            firstDay: DateTime.now(),
            lastDay: DateTime.now().add(Duration(days: 365)),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              if (_lapLai == 'Một lần') {
                return isSameDay(_ngayBatDau, day);
              } else {
                return _selectedDates.any((selectedDay) => isSameDay(selectedDay, day));
              }
            },
            onDaySelected: _onDaySelected,
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonShowsNext: false,
            ),
          ),
        ),
        
        SizedBox(height: 16),
        
        // Date summary
        if (_lapLai == 'Một lần')
          Text(
            'Ngày được chọn: ${_ngayBatDau.day}/${_ngayBatDau.month}/${_ngayBatDau.year}',
            style: TextStyle(fontSize: 14),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Số ngày đã chọn: ${_selectedDates.length}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              if (_selectedDates.isNotEmpty) ...[
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedDates.map((date) {
                    return Chip(
                      label: Text('${date.day}/${date.month}'),
                      deleteIcon: Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _selectedDates.removeWhere((d) => isSameDay(d, date));
                          if (_selectedDates.isNotEmpty) {
                            _selectedDates.sort((a, b) => a.compareTo(b));
                            _ngayBatDau = _selectedDates.first;
                            _ngayKetThuc = _selectedDates.last;
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
      ],
    );
  }
  
  // Third step: Task Details
  Widget _buildTaskDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Completion mode
        Text(
          'Hình thức nghiệm thu',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: Text('Tự động', style: TextStyle(fontSize: 14)),
                value: 'Tự động',
                groupValue: _hinhThucNghiemThu,
                onChanged: (value) {
                  setState(() {
                    _hinhThucNghiemThu = value!;
                  });
                },
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: Text('Nghiệm thu trực tiếp', style: TextStyle(fontSize: 10)),
                value: 'Nghiệm thu trực tiếp',
                groupValue: _hinhThucNghiemThu,
                onChanged: (value) {
                  setState(() {
                    _hinhThucNghiemThu = value!;
                  });
                },
              ),
            ),
          ],
        ),
        
        SizedBox(height: 16),
        
        // Task description
        Text(
          'Mô tả công việc',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        
        TextFormField(
          controller: _moTaCongViecController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            hintText: 'Nhập mô tả công việc cần thực hiện',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vui lòng nhập mô tả công việc';
            }
            return null;
          },
        ),
        
        SizedBox(height: 16),
        
        // Task location
        Text(
          'Khu vực thực hiện',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        
        TextFormField(
          controller: _khuVucThucHienController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            hintText: 'Nhập khu vực cụ thể thực hiện',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vui lòng nhập khu vực thực hiện';
            }
            return null;
          },
        ),
        
        SizedBox(height: 16),
        
        // Work volume (sqm)
        Text(
          'Khối lượng công việc (m²)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        
        TextFormField(
          controller: _khoiLuongCongViecController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            hintText: 'Nhập số mét vuông',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vui lòng nhập khối lượng công việc';
            }
            if (int.tryParse(value) == null) {
              return 'Vui lòng nhập số';
            }
            return null;
          },
        ),
        
        SizedBox(height: 16),
        
        // Work requirements
        Text(
          'Yêu cầu công việc',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        
        TextFormField(
          controller: _yeuCauCongViecController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            hintText: 'Nhập yêu cầu công việc',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vui lòng nhập yêu cầu công việc';
            }
            return null;
          },
        ),
        
        SizedBox(height: 16),
        
        // Work time
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thời gian bắt đầu',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _thoiGianBatDauController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      hintText: 'HH:MM',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập giờ bắt đầu';
                      }
                      return null;
                    },
                    onTap: () async {
                      final TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() {
                          _thoiGianBatDauController.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thời gian kết thúc',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _thoiGianKetThucController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      hintText: 'HH:MM',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập giờ kết thúc';
                      }
                      return null;
                    },
                    onTap: () async {
                      final TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() {
                          _thoiGianKetThucController.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        
        SizedBox(height: 16),
        
        // Equipment
        Text(
          'Thiết bị và vật tư',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        
        // Machines
        TextFormField(
          controller: _loaiMaySuDungController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            labelText: 'Loại máy sử dụng',
          ),
        ),
        
        SizedBox(height: 8),
        
        // Tools
        TextFormField(
          controller: _congCuSuDungController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            labelText: 'Công cụ sử dụng',
          ),
        ),
        
        SizedBox(height: 8),
        
        // Chemicals
        TextFormField(
          controller: _hoaChatSuDungController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            labelText: 'Hóa chất sử dụng',
          ),
        ),
        
        SizedBox(height: 16),
        
        // Notes
        Text(
          'Ghi chú bổ sung',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        
        TextFormField(
          controller: _ghiChuController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            hintText: 'Nhập ghi chú bổ sung (nếu có)',
          ),
          maxLines: 3,
        ),
        
        // Show error message if any
        if (_errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
        SizedBox(height: 24),
      ],
    );
  }

  @override
  void dispose() {
    // Dispose controllers
    _moTaCongViecController.dispose();
    _khuVucThucHienController.dispose();
    _khoiLuongCongViecController.dispose();
    _yeuCauCongViecController.dispose();
    _thoiGianBatDauController.dispose();
    _thoiGianKetThucController.dispose();
    _loaiMaySuDungController.dispose();
    _congCuSuDungController.dispose();
    _hoaChatSuDungController.dispose();
    _ghiChuController.dispose();
    super.dispose();
  }
}