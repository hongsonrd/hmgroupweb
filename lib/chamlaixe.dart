import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:video_player/video_player.dart';
import 'location_provider.dart';
import 'table_models.dart';

class ChamLaiXeScreen extends StatefulWidget {
  final String username;
  final String userRole;
  final String approverUsername;

  const ChamLaiXeScreen({
    Key? key,
    required this.username,
    this.userRole = '',
    this.approverUsername = '',
  }) : super(key: key);

  @override
  _ChamLaiXeScreenState createState() => _ChamLaiXeScreenState();
}

class _ChamLaiXeScreenState extends State<ChamLaiXeScreen> {
  bool _isLoading = false;
  String _message = '';
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedDriver;
  List<String> _availableDrivers = [];
  late ConfettiController _confettiController;
  late VideoPlayerController _soundController;
  bool _soundInitialized = false;
  String _selectedDateOption = 'today'; // 'today' or 'yesterday'
  
  Map<String, List<String>> _adminDriversMap = {
    'hm.tason': ['hm.tason' ,'bpthunghiem','hm.daotan','hm.trangiang'],
    'hm.quanganh': ['hm.anhmanh'],
    'hm.duongloan': ['hm.nguyenson' ,'hm.nguyenthuyet' ,'hm.lelinh'],
    'hm.daotan': ['hm.taquyet' ,'hm.levien' ,'hm.dothanh' ,'hm.buivung' ,'hm.buivan' ,'hm.nguyentru' ,'hm.nguyenluyen' ,'hm.lethuy' ,'hm.nguyentruong' ,'hm.vuongtuyen' ,'hm.phungchien' ,'hm.buituan' ,'hm.xuantrinh' ,'hm.buitoan' ,'hm.buivien' ,'hm.buimanh' ,'hm.nguyenvanan' ,'hm.buiduchai' ,'hm.phambinh'],
  };

  @override
  void initState() {
    super.initState();
    _loadAvailableDrivers();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _soundController = VideoPlayerController.asset('assets/alt/success.mp3')
      ..setVolume(0.6)
      ..initialize().then((_) {
        setState(() {
          _soundInitialized = true;
        });
      });
    _updateSelectedDateFromOption();
  }

  void _loadAvailableDrivers() {
    // Get the drivers that this admin can manage
    setState(() {
      _availableDrivers = _adminDriversMap[widget.username] ?? [];
      if (_availableDrivers.isNotEmpty) {
        _selectedDriver = _availableDrivers.first;
      }
    });
  }

  void _updateSelectedDateFromOption() {
  final now = DateTime.now();
  switch (_selectedDateOption) {
    case 'today':
      _selectedDate = now;
      break;
    case 'yesterday':
      _selectedDate = now.subtract(const Duration(days: 1));
      break;
    case 'day-2':
      _selectedDate = now.subtract(const Duration(days: 2));
      break;
    case 'day-3':
      _selectedDate = now.subtract(const Duration(days: 3));
      break;
    case 'day-4':
      _selectedDate = now.subtract(const Duration(days: 4));
      break;
    default:
      _selectedDate = now;
  }
  setState(() {});
}

  void _playSuccessSound() {
    if (_soundInitialized) {
      _soundController.seekTo(Duration.zero);
      _soundController.play();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: _selectedDate,
    firstDate: DateTime.now().subtract(const Duration(days: 30)),
    lastDate: DateTime.now().add(const Duration(days: 1)),
  );
  if (picked != null && picked != _selectedDate) {
    setState(() {
      _selectedDate = picked;
      // Update radio selection based on the picked date
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final day2 = today.subtract(const Duration(days: 2));
      final day3 = today.subtract(const Duration(days: 3));
      final day4 = today.subtract(const Duration(days: 4));
      final pickedDay = DateTime(picked.year, picked.month, picked.day);
      
      if (pickedDay.isAtSameMomentAs(today)) {
        _selectedDateOption = 'today';
      } else if (pickedDay.isAtSameMomentAs(yesterday)) {
        _selectedDateOption = 'yesterday';
      } else if (pickedDay.isAtSameMomentAs(day2)) {
        _selectedDateOption = 'day-2';
      } else if (pickedDay.isAtSameMomentAs(day3)) {
        _selectedDateOption = 'day-3';
      } else if (pickedDay.isAtSameMomentAs(day4)) {
        _selectedDateOption = 'day-4';
      } else {
        _selectedDateOption = 'custom';
      }
    });
  }
}

  Future<void> _submitAttendance() async {
  if (_selectedDriver == null || _selectedDriver!.isEmpty) {
    setState(() {
      _message = 'Vui lòng chọn lái xe/kỹ thuật';
    });
    return;
  }

  setState(() {
    _isLoading = true;
    _message = 'Đang xử lý...';
  });

  try {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    // First check if the user already has a record for this date
    final checkUrl = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongls/${_selectedDriver}/$formattedDate');
    final checkResponse = await http.get(checkUrl);
    
    if (checkResponse.statusCode == 200) {
      final existingData = json.decode(checkResponse.body);
      if (existingData.isNotEmpty) {
        setState(() {
          _isLoading = false;
          _message = 'Lái xe/kỹ thuật đã có dữ liệu chấm công cho ngày này';
        });
        return;
      }
    }
    
    // Create the UID for the attendance record
    final uid = '${_selectedDriver}_${_selectedDate.millisecondsSinceEpoch}';
    
    // Create attendance data with fixed working hours (8:00 - 17:00)
    final Map<String, dynamic> checkInData = {
      'UID': uid,
      'NguoiDung': _selectedDriver,
      'Ngay': formattedDate,
      'Ngay2': formattedDate,
      'BatDau': '08:00:00',
      'KetThuc': '17:00:00',
      'PhanLoaiBatDau': 'Công thường',
      'PhanLoaiKetThuc': 'Công thường',
      'DiemChamBatDau': 'Chấm tự động - Lái xe/Kỹ thuật',
      'DiemChamKetThuc': 'Chấm tự động - Lái xe/Kỹ thuật',
      'DinhViBatDau': '0,0',
      'DinhViKetThuc': '0,0',
      'KhoangCachBatDau': 0,
      'KhoangCachKetThuc': 0,
      'HopLeBatDau': 'Hợp lệ',
      'HopLeKetThuc': 'Hợp lệ',
      'TrangThaiBatDau': 'OK',
      'TrangThaiKetThuc': 'OK',
      'NguoiDuyetBatDau': widget.username,
      'NguoiDuyetKetThuc': widget.username,
      'GioLamBatDau': '08:00:00',
      'GioLamKetThuc': '17:00:00',
      'DiMuonBatDau': 0,
      'DiMuonKetThuc': 0,
      'TongDiMuonNgay': 0,
      'TongCongNgay': 1.0,
      'HinhAnhBatDau': '',
      'HinhAnhKetThuc': '',
    };

    // Debug output
    print('Submitting attendance for driver: $_selectedDriver as admin: ${widget.username}');
    print('Attendance data: $checkInData');

    // Try the chamcongmoilx endpoint (a special endpoint for driver/tech attendance)
    final Uri apiUrl = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongmoilx');
    
    final response = await http.post(
      apiUrl,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode(checkInData),
    );
    
    if (response.statusCode == 200) {
      setState(() {
        _isLoading = false;
        _message = 'Chấm công thành công cho $_selectedDriver';
        _descriptionController.clear();
      });
      
      // Play success effects
      _confettiController.play();
      _playSuccessSound();
      
      // Show success notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã chấm công cho $_selectedDriver'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      // If the specialized endpoint fails, try the standard endpoint
      final Uri standardApiUrl = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongmoi');
      
      final standardResponse = await http.post(
        standardApiUrl,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(checkInData),
      );
      
      if (standardResponse.statusCode == 200) {
        setState(() {
          _isLoading = false;
          _message = 'Chấm công thành công cho $_selectedDriver';
          _descriptionController.clear();
        });
        
        // Play success effects
        _confettiController.play();
        _playSuccessSound();
        
        // Show success notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã chấm công cho $_selectedDriver'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
          _message = 'Lỗi chấm công: ${standardResponse.statusCode}. ${standardResponse.body}';
        });
        print('Error response: ${standardResponse.body}');
      }
    }
  } catch (e) {
    setState(() {
      _isLoading = false;
      _message = 'Lỗi: $e';
    });
    print('Error submitting attendance: $e');
  }
}

  Future<void> _submitLeaveRequest(String leaveType, double dayValue) async {
    if (_selectedDriver == null || _selectedDriver!.isEmpty) {
      setState(() {
        _message = 'Vui lòng chọn lái xe/kỹ thuật';
      });
      return;
    }

    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận'),
          content: Text(
            'Bạn có chắc chắn muốn chấm $leaveType cho $_selectedDriver vào ngày ${DateFormat('dd/MM/yyyy').format(_selectedDate)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
              ),
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
      _message = 'Đang xử lý...';
    });

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      // Create the UID for the leave record
      final uid = '${_selectedDriver}_${_selectedDate.millisecondsSinceEpoch}';
      
      // Create leave data
      final Map<String, dynamic> leaveData = {
        'UID': uid,
        'NguoiDung': _selectedDriver,
        'PhanLoai': 'Nghỉ',
        'NgayBatDau': formattedDate,
        'NgayKetThuc': formattedDate,
        'GhiChu': _descriptionController.text,
        'TruongHop': leaveType,
        'NguoiDuyet': widget.username,
        'TrangThai': 'Đồng ý',
        'GiaTriNgay': dayValue,
      };

      print('Submitting leave request for driver: $_selectedDriver');
      print('Leave data: $leaveData');

      final Uri apiUrl = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongpheplx');
      
      final response = await http.post(
        apiUrl,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(leaveData),
      );
      
      if (response.statusCode == 200) {
        setState(() {
          _isLoading = false;
          _message = 'Chấm $leaveType thành công cho $_selectedDriver';
          _descriptionController.clear();
        });
        
        // Play success effects
        _confettiController.play();
        _playSuccessSound();
        
        // Show success notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã chấm $leaveType cho $_selectedDriver'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
          _message = 'Lỗi chấm $leaveType: ${response.statusCode}. ${response.body}';
        });
        print('Error response: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = 'Lỗi: $e';
      });
      print('Error submitting leave request: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chấm công lái xe/kỹ thuật'),
        backgroundColor: Colors.blue.shade200,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Admin info card
                Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.admin_panel_settings, color: Colors.blue.shade200),
                            const SizedBox(width: 8),
                            Text(
                              'Người quản lý: ${widget.username}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Bạn có thể chấm công hộ cho lái xe/kỹ thuật trong danh sách',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Driver selection
                if (_availableDrivers.isEmpty)
                  const Card(
                    elevation: 3,
                    margin: EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Không có lái xe/kỹ thuật trong danh sách quản lý của bạn',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  )
                else
                  Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chọn lái xe/kỹ thuật:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            value: _selectedDriver,
                            items: _availableDrivers.map((driver) {
                              return DropdownMenuItem<String>(
                                value: driver,
                                child: Text(driver),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedDriver = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Date selection
                Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chọn ngày chấm công:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        Column(
  children: [
    Row(
      children: [
        Expanded(
          child: RadioListTile<String>(
            title: const Text('Hôm nay'),
            value: 'today',
            groupValue: _selectedDateOption,
            onChanged: (value) {
              setState(() {
                _selectedDateOption = value!;
                _updateSelectedDateFromOption();
              });
            },
            dense: true,
            activeColor: Colors.blue.shade200,
          ),
        ),
        Expanded(
          child: RadioListTile<String>(
            title: const Text('Hôm qua'),
            value: 'yesterday',
            groupValue: _selectedDateOption,
            onChanged: (value) {
              setState(() {
                _selectedDateOption = value!;
                _updateSelectedDateFromOption();
              });
            },
            dense: true,
            activeColor: Colors.blue.shade200,
          ),
        ),
      ],
    ),
    Row(
      children: [
        Expanded(
          child: RadioListTile<String>(
            title: const Text('2 ngày trước'),
            value: 'day-2',
            groupValue: _selectedDateOption,
            onChanged: (value) {
              setState(() {
                _selectedDateOption = value!;
                _updateSelectedDateFromOption();
              });
            },
            dense: true,
            activeColor: Colors.blue.shade200,
          ),
        ),
        Expanded(
          child: RadioListTile<String>(
            title: const Text('3 ngày trước'),
            value: 'day-3',
            groupValue: _selectedDateOption,
            onChanged: (value) {
              setState(() {
                _selectedDateOption = value!;
                _updateSelectedDateFromOption();
              });
            },
            dense: true,
            activeColor: Colors.blue.shade200,
          ),
        ),
      ],
    ),
    Row(
      children: [
        Expanded(
          child: RadioListTile<String>(
            title: const Text('4 ngày trước'),
            value: 'day-4',
            groupValue: _selectedDateOption,
            onChanged: (value) {
              setState(() {
                _selectedDateOption = value!;
                _updateSelectedDateFromOption();
              });
            },
            dense: true,
            activeColor: Colors.blue.shade200,
          ),
        ),
        Expanded(child: Container()), // Empty container for balance
      ],
    ),
  ],
),
                        
                        const SizedBox(height: 8),
                        
                        // Date picker button
                        InkWell(
                          onTap: () => _selectDate(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
  DateFormat('dd/MM/yyyy (EEEE)').format(_selectedDate),
  style: const TextStyle(fontSize: 16),
),
                                const Icon(Icons.calendar_today),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Description
                Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ghi chú (không bắt buộc):',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Nhập ghi chú...',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading || _availableDrivers.isEmpty ? null : _submitAttendance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade200,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Chấm công',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Leave buttons row
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading || _availableDrivers.isEmpty 
                            ? null 
                            : () => _submitLeaveRequest('Nghỉ phép', 1.0),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Chấm phép',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading || _availableDrivers.isEmpty 
                            ? null 
                            : () => _submitLeaveRequest('Nghỉ phép 1/2 ngày', 0.5),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Chấm phép 1/2',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Message display
                if (_message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      _message,
                      style: TextStyle(
                        color: _message.contains('thành công') ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                
                // Information card
                Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(top: 24),
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade200),
                            const SizedBox(width: 8),
                            const Text(
                              'Thông tin',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• Chấm công: Hệ thống sẽ tự động chấm công từ 8:00 đến 17:00 với 1 công đầy đủ.\n\n• Chấm phép: Đăng ký nghỉ phép 1 ngày (1.0 công).\n\n• Chấm phép 1/2: Đăng ký nghỉ phép nửa ngày (0.5 công).',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 35,
              gravity: 0.1,
              colors: const [
                Color.fromARGB(255, 49, 255, 183),
                Color.fromARGB(255, 126, 255, 128),
                Color.fromARGB(255, 255, 100, 151),
                Color.fromARGB(255, 255, 201, 119),
                Color.fromARGB(255, 255, 160, 247),
                Color.fromARGB(255, 255, 248, 181),
              ],
              createParticlePath: (size) {
                final path = Path();
                path.moveTo(0, 0);
                path.cubicTo(
                  -10, -10,
                  -15, 0,
                  0, 10,
                );
                path.cubicTo(
                  15, 0,
                  10, -10,
                  0, 0,
                );
                return path;},
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _descriptionController.dispose();
    _confettiController.dispose();
    _soundController.dispose();
    super.dispose();
  }
}