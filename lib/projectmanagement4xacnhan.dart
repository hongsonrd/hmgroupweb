import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'table_models.dart';
import 'db_helper.dart';
import 'dart:async';
import 'dart:io';
// Main entry point for the confirmation workflow
void showConfirmationDialog(BuildContext context, GoCleanYeuCauModel request) {
  // First step: Show initial confirmation dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => _buildInitialConfirmationDialog(context, request),
  );
}

// Step 1: Initial confirmation dialog
Widget _buildInitialConfirmationDialog(BuildContext context, GoCleanYeuCauModel request) {
  return AlertDialog(
    title: Text(
      'Xác nhận yêu cầu',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chi tiết yêu cầu:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 12),
        _buildDetailItem('ID', request.giaoViecID ?? 'N/A'),
        _buildDetailItem('Mô tả', request.moTaCongViec ?? 'Không có mô tả'),
        _buildDetailItem('Địa điểm', request.diaDiem ?? 'N/A'),
        _buildDetailItem('Địa chỉ', request.diaChi ?? 'N/A'),
        
        if (request.ngayBatDau != null)
          _buildDetailItem('Thời gian bắt đầu', 
            '${request.ngayBatDau!.day}/${request.ngayBatDau!.month}/${request.ngayBatDau!.year}'),
        
        if (request.ngayKetThuc != null)
          _buildDetailItem('Thời gian kết thúc', 
            '${request.ngayKetThuc!.day}/${request.ngayKetThuc!.month}/${request.ngayKetThuc!.year}'),
        
        _buildDetailItem('Giờ làm việc', 
            '${request.thoiGianBatDau ?? "N/A"} - ${request.thoiGianKetThuc ?? "N/A"}'),
        
        SizedBox(height: 16),
        Text(
          'Bạn muốn xác nhận yêu cầu công việc này?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () {
          // Cancel button: reject the request
          _rejectRequest(context, request);
        },
        child: Text(
          'Không',
          style: TextStyle(color: Colors.red),
        ),
      ),
      ElevatedButton(
        onPressed: () {
          // Confirm button: proceed to next step
          Navigator.pop(context); // Close current dialog
          
          // Create a new request with updated status
          GoCleanYeuCauModel updatedRequest = GoCleanYeuCauModel(
            giaoViecID: request.giaoViecID,
            nguoiTao: request.nguoiTao,
            nguoiNghiemThu: request.nguoiNghiemThu,
            diaDiem: request.diaDiem,
            diaChi: request.diaChi,
            dinhVi: request.dinhVi,
            lapLai: request.lapLai,
            ngayBatDau: request.ngayBatDau,
            ngayKetThuc: request.ngayKetThuc,
            hinhThucNghiemThu: request.hinhThucNghiemThu,
            moTaCongViec: request.moTaCongViec,
            soNguoiThucHien: request.soNguoiThucHien,
            khuVucThucHien: request.khuVucThucHien,
            khoiLuongCongViec: request.khoiLuongCongViec,
            yeuCauCongViec: request.yeuCauCongViec,
            thoiGianBatDau: request.thoiGianBatDau,
            thoiGianKetThuc: request.thoiGianKetThuc,
            loaiMaySuDung: request.loaiMaySuDung,
            congCuSuDung: request.congCuSuDung,
            hoaChatSuDung: request.hoaChatSuDung,
            ghiChu: request.ghiChu,
            xacNhan: 'Đã xác nhận', // Set status to "Đã xác nhận" (Confirmed)
            chiDinh: request.chiDinh,
            huongDan: request.huongDan ?? 'Liên hệ quản lý nếu có phát sinh', // Default value
            nhomThucHien: request.nhomThucHien,
            caNhanThucHien: request.caNhanThucHien,
            listNguoiThucHien: request.listNguoiThucHien,
          );
          
          _showHuongDanDialog(context, updatedRequest); // Proceed to next step
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
        ),
        child: Text('Có'),
      ),
    ],
  );
}

// Helper widget for detail items
Widget _buildDetailItem(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 14),
          ),
        ),
      ],
    ),
  );
}

// Handle rejection (No option in step 1)
void _rejectRequest(BuildContext context, GoCleanYeuCauModel request) {
  // Create a copy of the request with updated status
  final updatedRequest = GoCleanYeuCauModel(
    giaoViecID: request.giaoViecID,
    nguoiTao: request.nguoiTao,
    nguoiNghiemThu: request.nguoiNghiemThu,
    diaDiem: request.diaDiem,
    diaChi: request.diaChi,
    dinhVi: request.dinhVi,
    lapLai: request.lapLai,
    ngayBatDau: request.ngayBatDau,
    ngayKetThuc: request.ngayKetThuc,
    hinhThucNghiemThu: request.hinhThucNghiemThu,
    moTaCongViec: request.moTaCongViec,
    soNguoiThucHien: request.soNguoiThucHien,
    khuVucThucHien: request.khuVucThucHien,
    khoiLuongCongViec: request.khoiLuongCongViec,
    yeuCauCongViec: request.yeuCauCongViec,
    thoiGianBatDau: request.thoiGianBatDau,
    thoiGianKetThuc: request.thoiGianKetThuc,
    loaiMaySuDung: request.loaiMaySuDung,
    congCuSuDung: request.congCuSuDung,
    hoaChatSuDung: request.hoaChatSuDung,
    ghiChu: request.ghiChu,
    xacNhan: 'Huỷ', // Set status to "Huỷ" (Canceled)
    chiDinh: request.chiDinh,
    huongDan: request.huongDan,
    nhomThucHien: request.nhomThucHien,
    caNhanThucHien: request.caNhanThucHien,
    listNguoiThucHien: request.listNguoiThucHien,
  );

  // Update to server
  _updateRequestToServer(context, updatedRequest);
  
  // Close dialog and return to previous screen
  Navigator.pop(context);
  
  // Show success message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Đã huỷ yêu cầu'),
      backgroundColor: Colors.red,
      duration: Duration(seconds: 2),
    ),
  );
}

// Step 2: Edit HuongDan (Instructions) dialog
void _showHuongDanDialog(BuildContext context, GoCleanYeuCauModel request) {
  // Text controller for HuongDan field
  final TextEditingController huongDanController = TextEditingController(
    text: request.huongDan,
  );
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(
        'Hướng dẫn thực hiện',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nhập hướng dẫn cho công việc:',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 12),
          TextField(
            controller: huongDanController,
            maxLines: 4,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Nhập hướng dẫn chi tiết...',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Go back to previous step
            Navigator.pop(context);
            showConfirmationDialog(context, request);
          },
          child: Text('Quay lại'),
        ),
        ElevatedButton(
          onPressed: () {
            // Create new request with updated HuongDan
            GoCleanYeuCauModel updatedRequest = GoCleanYeuCauModel(
              giaoViecID: request.giaoViecID,
              nguoiTao: request.nguoiTao,
              nguoiNghiemThu: request.nguoiNghiemThu,
              diaDiem: request.diaDiem,
              diaChi: request.diaChi,
              dinhVi: request.dinhVi,
              lapLai: request.lapLai,
              ngayBatDau: request.ngayBatDau,
              ngayKetThuc: request.ngayKetThuc,
              hinhThucNghiemThu: request.hinhThucNghiemThu,
              moTaCongViec: request.moTaCongViec,
              soNguoiThucHien: request.soNguoiThucHien,
              khuVucThucHien: request.khuVucThucHien,
              khoiLuongCongViec: request.khoiLuongCongViec,
              yeuCauCongViec: request.yeuCauCongViec,
              thoiGianBatDau: request.thoiGianBatDau,
              thoiGianKetThuc: request.thoiGianKetThuc,
              loaiMaySuDung: request.loaiMaySuDung,
              congCuSuDung: request.congCuSuDung,
              hoaChatSuDung: request.hoaChatSuDung,
              ghiChu: request.ghiChu,
              xacNhan: request.xacNhan,
              chiDinh: request.chiDinh,
              huongDan: huongDanController.text, // Updated huongDan
              nhomThucHien: request.nhomThucHien,
              caNhanThucHien: request.caNhanThucHien,
              listNguoiThucHien: request.listNguoiThucHien,
            );
            
            Navigator.pop(context);
            _showChiDinhDialog(context, updatedRequest);
          },
          child: Text('Tiếp tục'),
        ),
      ],
    ),
  );
}

// Step 3: Select ChiDinh (Assignment Type) dialog
void _showChiDinhDialog(BuildContext context, GoCleanYeuCauModel request) {
  // Options for ChiDinh
  const List<String> chiDinhOptions = ['Nhóm', 'Cá nhân', 'Tự do'];
  String selectedChiDinh = request.chiDinh ?? chiDinhOptions[0];
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text(
            'Chỉ định thực hiện',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chọn hình thức chỉ định:',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 12),
              // Radio buttons for ChiDinh options
              ...chiDinhOptions.map((option) => RadioListTile<String>(
                title: Text(option),
                value: option,
                groupValue: selectedChiDinh,
                onChanged: (value) {
                  setState(() {
                    selectedChiDinh = value!;
                  });
                },
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Go back to previous step
                Navigator.pop(context);
                _showHuongDanDialog(context, request);
              },
              child: Text('Quay lại'),
            ),
            ElevatedButton(
              onPressed: () {
                // Create updated request with selected ChiDinh
                GoCleanYeuCauModel updatedRequest = GoCleanYeuCauModel(
                  giaoViecID: request.giaoViecID,
                  nguoiTao: request.nguoiTao,
                  nguoiNghiemThu: request.nguoiNghiemThu,
                  diaDiem: request.diaDiem,
                  diaChi: request.diaChi,
                  dinhVi: request.dinhVi,
                  lapLai: request.lapLai,
                  ngayBatDau: request.ngayBatDau,
                  ngayKetThuc: request.ngayKetThuc,
                  hinhThucNghiemThu: request.hinhThucNghiemThu,
                  moTaCongViec: request.moTaCongViec,
                  soNguoiThucHien: request.soNguoiThucHien,
                  khuVucThucHien: request.khuVucThucHien,
                  khoiLuongCongViec: request.khoiLuongCongViec,
                  yeuCauCongViec: request.yeuCauCongViec,
                  thoiGianBatDau: request.thoiGianBatDau,
                  thoiGianKetThuc: request.thoiGianKetThuc,
                  loaiMaySuDung: request.loaiMaySuDung,
                  congCuSuDung: request.congCuSuDung,
                  hoaChatSuDung: request.hoaChatSuDung,
                  ghiChu: request.ghiChu,
                  xacNhan: request.xacNhan,
                  chiDinh: selectedChiDinh, // Updated chiDinh
                  huongDan: request.huongDan,
                  nhomThucHien: request.nhomThucHien,
                  caNhanThucHien: request.caNhanThucHien,
                  listNguoiThucHien: request.listNguoiThucHien,
                );
                
                Navigator.pop(context);
                
                if (selectedChiDinh == 'Cá nhân') {
                  _loadAndShowKyThuatUsers(context, updatedRequest);
                } else if (selectedChiDinh == 'Nhóm') {
                  _loadAndShowKyThuatGroups(context, updatedRequest);
                } else { // Tự do
                  _updateRequestToServer(context, updatedRequest);
                }
              },
              child: Text('Tiếp tục'),
            ),
          ],
        );
      },
    ),
  );
}

// Load technical staff users for individual assignment
void _loadAndShowKyThuatUsers(BuildContext context, GoCleanYeuCauModel request) {
  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Center(child: CircularProgressIndicator()),
  );
  
  // Get DB helper
  final DBHelper dbHelper = DBHelper();
  
  // Load technical staff users
  dbHelper.getAllGoCleanTaiKhoan().then((allUsers) {
    // Filter for technical staff
    final techUsers = allUsers.where((user) => 
      user.phanLoai == 'Kỹ thuật' && user.taiKhoan != null
    ).toList();
    
    // Close loading indicator
    Navigator.pop(context);
    
    // Show user selection dialog
    _showCaNhanSelection(context, request, techUsers);
  }).catchError((error) {
    // Handle error
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi tải danh sách người dùng: $error'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  });
}

// Show individual staff selection dialog
void _showCaNhanSelection(BuildContext context, GoCleanYeuCauModel request, 
    List<GoCleanTaiKhoanModel> techUsers) {
  
  // Selected users
  List<String> selectedUsers = [];
  
  // If we already have selected users, pre-select them
  if (request.caNhanThucHien != null && request.caNhanThucHien!.isNotEmpty) {
    selectedUsers = request.caNhanThucHien!.split(',');
  }
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text(
            'Chọn nhân viên kỹ thuật',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn người thực hiện:',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 12),
                Container(
                  height: 300, // Fixed height for scrollable list
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: techUsers.length,
                    itemBuilder: (context, index) {
                      final user = techUsers[index];
                      final username = user.taiKhoan ?? 'Không tên';
                      final isSelected = selectedUsers.contains(username);
                      
                      return CheckboxListTile(
                        title: Text(username),
                        subtitle: Text(user.nhom ?? 'Chưa phân nhóm'),
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              selectedUsers.add(username);
                            } else {
                              selectedUsers.remove(username);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Go back to previous step
                Navigator.pop(context);
                _showChiDinhDialog(context, request);
              },
              child: Text('Quay lại'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedUsers.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Vui lòng chọn ít nhất một nhân viên'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  // Create updated request with selected users
                  GoCleanYeuCauModel updatedRequest = GoCleanYeuCauModel(
                    giaoViecID: request.giaoViecID,
                    nguoiTao: request.nguoiTao,
                    nguoiNghiemThu: request.nguoiNghiemThu,
                    diaDiem: request.diaDiem,
                    diaChi: request.diaChi,
                    dinhVi: request.dinhVi,
                    lapLai: request.lapLai,
                    ngayBatDau: request.ngayBatDau,
                    ngayKetThuc: request.ngayKetThuc,
                    hinhThucNghiemThu: request.hinhThucNghiemThu,
                    moTaCongViec: request.moTaCongViec,
                    soNguoiThucHien: request.soNguoiThucHien,
                    khuVucThucHien: request.khuVucThucHien,
                    khoiLuongCongViec: request.khoiLuongCongViec,
                    yeuCauCongViec: request.yeuCauCongViec,
                    thoiGianBatDau: request.thoiGianBatDau,
                    thoiGianKetThuc: request.thoiGianKetThuc,
                    loaiMaySuDung: request.loaiMaySuDung,
                    congCuSuDung: request.congCuSuDung,
                    hoaChatSuDung: request.hoaChatSuDung,
                    ghiChu: request.ghiChu,
                    xacNhan: request.xacNhan,
                    chiDinh: request.chiDinh,
                    huongDan: request.huongDan,
                    nhomThucHien: request.nhomThucHien,
                    caNhanThucHien: selectedUsers.join(','), // Updated caNhanThucHien
                    listNguoiThucHien: request.listNguoiThucHien,
                  );
                  
                  Navigator.pop(context);
                  
                  // If only one user selected, set for all tasks
                  if (selectedUsers.length == 1) {
                    _updateSingleUserTasks(context, updatedRequest, selectedUsers[0]);
                  } else {
                    // For multiple users, show task assignment screen
                    _loadAndShowTaskAssignment(context, updatedRequest, selectedUsers);
                  }
                }
              },
              child: Text('Tiếp tục'),
            ),
          ],
        );
      },
    ),
  );
}
void _updateSingleUserTasks(BuildContext context, GoCleanYeuCauModel request, String username) {
  // Store a global key for the loading dialog
  final GlobalKey<State> _dialogKey = GlobalKey<State>();
  
  // Show loading indicator with a key
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => AlertDialog(
      key: _dialogKey,
      backgroundColor: Colors.white,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Đang cập nhật...'),
        ],
      ),
    ),
  );
  
  // Get DB helper
  final DBHelper dbHelper = DBHelper();
  
  // Load related tasks
  dbHelper.getAllGoCleanCongViec().then((allTasks) {
    // Filter for tasks related to this request
    final relatedTasks = allTasks.where((task) => 
      task.giaoViecID == request.giaoViecID
    ).toList();
    
    // Update each task
    List<GoCleanCongViecModel> updatedTasks = [];
    for (var task in relatedTasks) {
      updatedTasks.add(GoCleanCongViecModel(
        lichLamViecID: task.lichLamViecID,
        giaoViecID: task.giaoViecID,
        ngay: task.ngay,
        nguoiThucHien: username, // Set to selected user
        xacNhan: task.xacNhan,
        qrCode: task.qrCode,
        mocBatDau: task.mocBatDau,
        hinhAnhTruoc: task.hinhAnhTruoc,
        mocKetThuc: task.mocKetThuc,
        hinhAnhSau: task.hinhAnhSau,
        thucHienDanhGia: task.thucHienDanhGia,
        moTaThucHien: task.moTaThucHien,
        khachHang: task.khachHang,
        khachHangDanhGia: task.khachHangDanhGia,
        thoiGianDanhGia: task.thoiGianDanhGia,
        khachHangMoTa: task.khachHangMoTa,
        khachHangChupAnh: task.khachHangChupAnh,
        trangThai: task.trangThai,
      ));
    }
    
    // Create updated request with ListNguoiThucHien set to selected user
    GoCleanYeuCauModel finalRequest = GoCleanYeuCauModel(
      giaoViecID: request.giaoViecID,
      nguoiTao: request.nguoiTao,
      nguoiNghiemThu: request.nguoiNghiemThu,
      diaDiem: request.diaDiem,
      diaChi: request.diaChi,
      dinhVi: request.dinhVi,
      lapLai: request.lapLai,
      ngayBatDau: request.ngayBatDau,
      ngayKetThuc: request.ngayKetThuc,
      hinhThucNghiemThu: request.hinhThucNghiemThu,
      moTaCongViec: request.moTaCongViec,
      soNguoiThucHien: request.soNguoiThucHien,
      khuVucThucHien: request.khuVucThucHien,
      khoiLuongCongViec: request.khoiLuongCongViec,
      yeuCauCongViec: request.yeuCauCongViec,
      thoiGianBatDau: request.thoiGianBatDau,
      thoiGianKetThuc: request.thoiGianKetThuc,
      loaiMaySuDung: request.loaiMaySuDung,
      congCuSuDung: request.congCuSuDung,
      hoaChatSuDung: request.hoaChatSuDung,
      ghiChu: request.ghiChu,
      xacNhan: request.xacNhan,
      chiDinh: request.chiDinh,
      huongDan: request.huongDan,
      nhomThucHien: request.nhomThucHien,
      caNhanThucHien: request.caNhanThucHien,
      listNguoiThucHien: username, // Set ListNguoiThucHien to selected user
    );
    
    // Update process with proper dialog handling
    _performUpdates(context, _dialogKey, finalRequest, updatedTasks);
  }).catchError((error) {
    // Handle error - safely close dialog
    _safelyCloseDialog(_dialogKey);
    
    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi tải danh sách công việc: $error'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  });
}
// Load tasks for multiple user assignment
void _loadAndShowTaskAssignment(BuildContext context, GoCleanYeuCauModel request, 
    List<String> selectedUsers) {
  
  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Center(child: CircularProgressIndicator()),
  );
  
  // Get DB helper
  final DBHelper dbHelper = DBHelper();
  
  // Load related tasks
  dbHelper.getAllGoCleanCongViec().then((allTasks) {
    // Filter for tasks related to this request
    final relatedTasks = allTasks.where((task) => 
      task.giaoViecID == request.giaoViecID
    ).toList();
    
    // Sort tasks by date
    relatedTasks.sort((a, b) {
      if (a.ngay == null) return 1;
      if (b.ngay == null) return -1;
      return a.ngay!.compareTo(b.ngay!);
    });
    
    // Close loading indicator
    Navigator.pop(context);
    
    // Show task assignment dialog
    _showTaskAssignmentDialog(context, request, relatedTasks, selectedUsers);
  }).catchError((error) {
    // Handle error
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi tải danh sách công việc: $error'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  });
}

void _showTaskAssignmentDialog(BuildContext context, GoCleanYeuCauModel request,
    List<GoCleanCongViecModel> tasks, List<String> selectedUsers) {
  
  // Map to store task assignments: TaskID -> Assigned User
  Map<String?, String> taskAssignments = {};
  
  // Initialize assignments with current values or default to first user
  for (var task in tasks) {
    if (task.lichLamViecID != null) {
      // If current assignment exists and is in the selectedUsers list, keep it
      if (task.nguoiThucHien != null && 
          task.nguoiThucHien!.isNotEmpty && 
          selectedUsers.contains(task.nguoiThucHien)) {
        taskAssignments[task.lichLamViecID] = task.nguoiThucHien!;
      } else {
        // Default to first user
        taskAssignments[task.lichLamViecID] = selectedUsers.first;
      }
    }
  }
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return Dialog(
          insetPadding: EdgeInsets.all(16),
          child: Container(
            width: double.maxFinite,
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phân công công việc',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(
                  'Chọn người thực hiện cho từng công việc:',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 12),
                Container(
                  height: 400, // Fixed height for scrollable list
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final taskId = task.lichLamViecID;
                      final taskDate = task.ngay != null 
                          ? '${task.ngay!.day}/${task.ngay!.month}/${task.ngay!.year}'
                          : 'N/A';
                      
                      // Ensure the value is set and valid
                      if (taskId == null || !taskAssignments.containsKey(taskId)) {
                        return SizedBox.shrink(); // Skip this item if taskId is null
                      }
                      
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'ID: ${task.lichLamViecID}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Ngày: $taskDate',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              // Use a simpler dropdown implementation
                              DropdownButton<String>(
                                isExpanded: true,
                                value: taskAssignments[taskId],
                                hint: Text("Chọn người thực hiện"),
                                underline: Container(
                                  height: 1,
                                  color: Colors.grey,
                                ),
                                items: selectedUsers.map((username) {
                                  return DropdownMenuItem<String>(
                                    value: username,
                                    child: Text(username),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      taskAssignments[taskId] = value;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        // Go back to previous step
                        Navigator.pop(context);
                        _showCaNhanSelection(context, request, []);
                      },
                      child: Text('Quay lại'),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Create updated tasks list
                        List<GoCleanCongViecModel> updatedTasks = [];
                        
                        for (var task in tasks) {
                          if (task.lichLamViecID != null && 
                              taskAssignments.containsKey(task.lichLamViecID)) {
                            updatedTasks.add(GoCleanCongViecModel(
                              lichLamViecID: task.lichLamViecID,
                              giaoViecID: task.giaoViecID,
                              ngay: task.ngay,
                              nguoiThucHien: taskAssignments[task.lichLamViecID],
                              xacNhan: task.xacNhan,
                              qrCode: task.qrCode,
                              mocBatDau: task.mocBatDau,
                              hinhAnhTruoc: task.hinhAnhTruoc,
                              mocKetThuc: task.mocKetThuc,
                              hinhAnhSau: task.hinhAnhSau,
                              thucHienDanhGia: task.thucHienDanhGia,
                              moTaThucHien: task.moTaThucHien,
                              khachHang: task.khachHang,
                              khachHangDanhGia: task.khachHangDanhGia,
                              thoiGianDanhGia: task.thoiGianDanhGia,
                              khachHangMoTa: task.khachHangMoTa,
                              khachHangChupAnh: task.khachHangChupAnh,
                              trangThai: task.trangThai,
                            ));
                          }
                        }
                        
                        // Get unique list of assigned users
                        final uniqueAssignedUsers = taskAssignments.values.toSet().toList();
                        
                        // Create updated request with ListNguoiThucHien set to unique assigned users
                        GoCleanYeuCauModel finalRequest = GoCleanYeuCauModel(
                          giaoViecID: request.giaoViecID,
                          nguoiTao: request.nguoiTao,
                          nguoiNghiemThu: request.nguoiNghiemThu,
                          diaDiem: request.diaDiem,
                          diaChi: request.diaChi,
                          dinhVi: request.dinhVi,
                          lapLai: request.lapLai,
                          ngayBatDau: request.ngayBatDau,
                          ngayKetThuc: request.ngayKetThuc,
                          hinhThucNghiemThu: request.hinhThucNghiemThu,
                          moTaCongViec: request.moTaCongViec,
                          soNguoiThucHien: request.soNguoiThucHien,
                          khuVucThucHien: request.khuVucThucHien,
                          khoiLuongCongViec: request.khoiLuongCongViec,
                          yeuCauCongViec: request.yeuCauCongViec,
                          thoiGianBatDau: request.thoiGianBatDau,
                          thoiGianKetThuc: request.thoiGianKetThuc,
                          loaiMaySuDung: request.loaiMaySuDung,
                          congCuSuDung: request.congCuSuDung,
                          hoaChatSuDung: request.hoaChatSuDung,
                          ghiChu: request.ghiChu,
                          xacNhan: request.xacNhan,
                          chiDinh: request.chiDinh,
                          huongDan: request.huongDan,
                          nhomThucHien: request.nhomThucHien,
                          caNhanThucHien: request.caNhanThucHien,
                          listNguoiThucHien: uniqueAssignedUsers.join(','), // Updated ListNguoiThucHien
                        );
                        
                        // Close dialog
                        Navigator.pop(context);
                        
                        // Store a global key for the loading dialog
                        final GlobalKey<State> _dialogKey = GlobalKey<State>();
                        
                        // Show loading dialog with key
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext dialogContext) => AlertDialog(
                            key: _dialogKey,
                            backgroundColor: Colors.white,
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Đang cập nhật...'),
                              ],
                            ),
                          ),
                        );
                        
                        // Use helper function for updates
                        _performUpdates(context, _dialogKey, finalRequest, updatedTasks);
                      },
                      child: Text('Hoàn tất'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
Future<void> _performUpdates(BuildContext context, GlobalKey<State> dialogKey, 
    GoCleanYeuCauModel request, List<GoCleanCongViecModel> tasks) async {
  try {
    // First update the request
    await _updateRequestToServer(context, request, showSnackbar: false);
    
    // Then update all tasks
    await _updateTasksToServer(context, tasks);
    
    // Safely close dialog
    _safelyCloseDialog(dialogKey);
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã cập nhật yêu cầu và phân công công việc thành công'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  } catch (error) {
    // Safely close dialog
    _safelyCloseDialog(dialogKey);
    
    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi cập nhật: $error'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }
}
// Load technical staff groups
void _loadAndShowKyThuatGroups(BuildContext context, GoCleanYeuCauModel request) {
  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Center(child: CircularProgressIndicator()),
  );
  
  // Get DB helper
  final DBHelper dbHelper = DBHelper();
  
  // Load technical staff users to get groups
  dbHelper.getAllGoCleanTaiKhoan().then((allUsers) {
    // Filter for technical staff
    final techUsers = allUsers.where((user) => 
      user.phanLoai == 'Kỹ thuật' && user.nhom != null && user.nhom!.isNotEmpty
    ).toList();
    
    // Extract unique groups
    final Set<String> uniqueGroups = {};
    for (var user in techUsers) {
      if (user.nhom != null && user.nhom!.isNotEmpty) {
        uniqueGroups.add(user.nhom!);
      }
    }
    
    // Close loading indicator
    Navigator.pop(context);
    
    // Show group selection dialog
    _showNhomSelection(context, request, uniqueGroups.toList());
  }).catchError((error) {
    // Handle error
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi tải danh sách nhóm: $error'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  });
}

// Show group selection dialog
void _showNhomSelection(BuildContext context, GoCleanYeuCauModel request, List<String> groups) {
  // Selected group
  String? selectedGroup = request.nhomThucHien;
  
  // If no group is selected or selected group is not in the list
  if (selectedGroup == null || !groups.contains(selectedGroup)) {
    selectedGroup = groups.isNotEmpty ? groups[0] : null;
  }
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text(
            'Chọn nhóm thực hiện',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chọn nhóm kỹ thuật thực hiện:',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 12),
              groups.isEmpty
                  ? Text(
                      'Không có nhóm kỹ thuật nào.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : Container(
                      width: double.maxFinite,
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Nhóm thực hiện',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        value: selectedGroup,
                        items: groups.map((group) {
                          return DropdownMenuItem<String>(
                            value: group,
                            child: Text(group),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedGroup = value;
                          });
                        },
                      ),
                    ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Go back to previous step
                Navigator.pop(context);
                _showChiDinhDialog(context, request);
              },
              child: Text('Quay lại'),
            ),
            ElevatedButton(
              onPressed: groups.isEmpty || selectedGroup == null
                  ? null // Disable button if no groups available
                  : () {
                      // Update NhomThucHien field
                      request.nhomThucHien = selectedGroup;
                      Navigator.pop(context);
                      
                      // Update users in the group as ListNguoiThucHien
                      _updateListNguoiThucHienForGroup(context, request, selectedGroup!);
                    },
              child: Text('Hoàn tất'),
            ),
          ],
        );
      },
    ),
  );
}

// Update ListNguoiThucHien based on selected group
void _updateListNguoiThucHienForGroup(BuildContext context, GoCleanYeuCauModel request, String groupName) {
  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Center(child: CircularProgressIndicator()),
  );
  
  // Get DB helper
  final DBHelper dbHelper = DBHelper();
  
  // Load technical staff users in selected group
  dbHelper.getAllGoCleanTaiKhoan().then((allUsers) {
    // Filter for users in the selected group
    final usersInGroup = allUsers.where((user) => 
      user.phanLoai == 'Kỹ thuật' && 
      user.nhom == groupName &&
      user.taiKhoan != null
    ).map((user) => user.taiKhoan!).toList();
    
    // Update ListNguoiThucHien field
    request.listNguoiThucHien = usersInGroup.join(',');
    
    // Update request to server
    _updateRequestToServer(context, request);
  }).catchError((error) {
    // Handle error
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi cập nhật nhóm: $error'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  });
}

// Update request to server
Future<void> _updateRequestToServer(BuildContext context, GoCleanYeuCauModel request, {bool showSnackbar = true}) async {
  try {
    print('Sending request update to server: ${request.giaoViecID}');
    
    // Send request to server
    final response = await http.post(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/cleanyeucauupdate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toMap()),
    );
    
    // Check response
    if (response.statusCode == 200) {
      print('Request update successful: ${response.body}');
      
      // Show success message if required
      if (showSnackbar) {
        // Make sure to pop the loading dialog
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context); 
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật yêu cầu thành công'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      print('Error response: ${response.statusCode}, ${response.body}');
      throw Exception('Lỗi cập nhật dữ liệu: ${response.statusCode}, ${response.body}');
    }
  } catch (e) {
    print('Exception during request update: $e');
    
    if (showSnackbar) {
      // Make sure to pop the loading dialog
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kết nối đến máy chủ: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      throw e; // Rethrow for caller to handle
    }
  }
}
void _safelyCloseDialog(GlobalKey<State> dialogKey) {
  if (dialogKey.currentContext != null && Navigator.of(dialogKey.currentContext!).canPop()) {
    Navigator.of(dialogKey.currentContext!).pop();
  }
}
Future<void> _updateTasksToServer(BuildContext context, List<GoCleanCongViecModel> tasks) async {
  try {
    print('Updating ${tasks.length} tasks to server');
    
    // Update each task
    for (var task in tasks) {
      print('Sending task update: ${task.lichLamViecID}');
      
      // Send request to server
      final response = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/cleancongviecupdate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(task.toMap()),
      );
      
      // Check response
      if (response.statusCode == 200) {
        print('Task update successful: ${response.body}');
      } else {
        print('Error response: ${response.statusCode}, ${response.body}');
        throw Exception('Lỗi cập nhật công việc: ${response.statusCode}, ${response.body}');
      }
    }
  } catch (e) {
    print('Exception during tasks update: $e');
    throw e; // Rethrow for caller to handle
  }
}
// This function can be used in other files to get the status color
Color getStatusColor(String? status) {
  if (status == null) return Colors.grey;
  
  switch (status.toLowerCase()) {
    case 'đã hoàn thành':
      return Colors.green;
    case 'đang thực hiện':
      return Colors.orange;
    case 'chờ xác nhận':
      return Colors.purple;
    case 'đã xác nhận':
      return Colors.blue;
    case 'chưa bắt đầu':
      return Colors.blue;
    case 'huỷ':
      return Colors.red;
    default:
      return Colors.grey;
  }
}