import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class AddKhachHangScreen extends StatefulWidget {
  final KhachHangModel? editingCustomer; 
  const AddKhachHangScreen({Key? key, this.editingCustomer}) : super(key: key);
  
  @override
  _AddKhachHangScreenState createState() => _AddKhachHangScreenState();
}

class _AddKhachHangScreenState extends State<AddKhachHangScreen> 
    with SingleTickerProviderStateMixin { 
  final _formKey = GlobalKey<FormState>();
  final _contactFormKey = GlobalKey<FormState>();
  bool get isEditMode => widget.editingCustomer != null;
  List<String> _availablemaKinhDoanhs = [];
    bool _isLoadingContracts = false;
  // Customer data
  Map<String, dynamic> newCustomer = {};
  final DBHelper _dbHelper = DBHelper();
  List<String> _userList = [];
  List<String> _selectedShare = [];
  bool _isSyncing = false;
  final String baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  
  final Map<String, List<String>> quickShareOptions = {
    'Trưởng phòng': ['hm.tranminh', 'hm.hahuong', 'hm.vuquyen'],
    'Ban lãnh đạo': ['hm.tason', 'hm.nguyengiang', 'hm.nguyenyen'],
    'Kinh doanh': ['hm.trangiang', 'hm.luukinh', 'hm.tranhanh'],
  };
  
  // Contact list
  List<KhachHangContactDraft> contacts = [];
  
  // Current contact being edited
  KhachHangContactDraft? currentContact;
  
  // Contact form controllers
  TextEditingController hoTenController = TextEditingController();
  TextEditingController chucDanhController = TextEditingController();
  TextEditingController soDienThoaiContactController = TextEditingController();
  TextEditingController emailContactController = TextEditingController();
  
  // Contact form values
  String? selectedGioiTinh;
  String? selectedNguonGoc;
  
  // Special usernames list for phanLoai auto-selection
  final List<String> thuongMaiUsers = [
    'hm.trangiang', 'hm.tranly', 'hm.nguyenhanh2', 'hm.dinhmai', 
    'hm.hoangthao', 'hm.vutoan', 'hm.lehoa', 'hm.lemanh', 
    'hm.nguyentoan', 'hm.nguyendung', 'hm.nguyennga', 'hm.conghai', 
    'hm.thuytrang', 'hm.nguyenvy', 'hm.baoha', 'hm.trantien', 
    'hm.myha', 'hm.phiminh', 'hm.thanhhao', 'hm.luongtrang', 
    'hm.damlinh', 'hm.thanhthao', 'hm.damchinh', 'hm.quocchien', 
    'hm.thuyvan', 'hotel.danang', 'hotel.nhatrang', 'hm.doanly'
  ];
  
  // Predefined subject names for Dịch vụ type
  final List<String> predefinedSubjects = [
    "1. Nhân sự", 
    "2. Tuyển dụng/ Chính sách", 
    "10. Đối thủ", 
    "5. Kiểm soát, ĐG Chất lượng DV", 
    "8. Báo giá, đấu thầu", 
    "6. Ý kiến KH", 
    "4. Máy móc", 
    "3. Vật tư", 
    "7. HĐ, PL, Giải trình, CV", 
    "9. Công nợ", 
    "11. Khảo sát", 
    "12. Phát triển TT", 
    "14. Đánh giá KH"
  ];
  
  // Main form controllers
  TextEditingController tenDuAnController = TextEditingController();
  TextEditingController ghiChuController = TextEditingController();
  TextEditingController diaChiController = TextEditingController();
  TextEditingController maSoThueController = TextEditingController();
  TextEditingController soDienThoaiController = TextEditingController();
  TextEditingController faxController = TextEditingController();
  TextEditingController websiteController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController soTaiKhoanController = TextEditingController();
  TextEditingController nganHangController = TextEditingController();
  TextEditingController tinhThanhController = TextEditingController();
  TextEditingController quanHuyenController = TextEditingController();
  TextEditingController phuongXaController = TextEditingController();
  TextEditingController duKienTrienKhaiController = TextEditingController();
  TextEditingController tiemNangDVTMController = TextEditingController();
  TextEditingController yeuCauNhanSuController = TextEditingController();
  TextEditingController cachThucTuyenController = TextEditingController();
  TextEditingController mucLuongTuyenController = TextEditingController();
  TextEditingController luongBPController = TextEditingController();
  TextEditingController diaChiVanPhongController = TextEditingController();

  // Dropdown values
  String? selectedDanhDau = '';
  String? selectedVungMien;
  String selectedLoaiHinh = 'Dự án';
  String? selectedLoaiCongTrinh;
  String? selectedTrangThaiHopDong;
  String? selectedLoaiMuaHang;
  String? selectedKenhTiepCan;
  String? selectedDiaChiVanPhong;

  // App theme colors
  final Color appBarTop = Color(0xFF024965);
  final Color appBarBottom = Color(0xFF81D2E7);
  final Color buttonColor = Color(0xFF33a7ce);
  
  // Tab controller for switching between customer and contact info
  late TabController _tabController;
  
  // Loading state for API calls
  bool _isSubmitting = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedUserList(); 
    if (isEditMode) {
      _loadExistingCustomerData();
    } else {
      _initializeNewCustomer();
    }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadAvailableContracts();
  });
}
Future<void> _loadAvailableContracts() async {
  if (newCustomer['phanLoai'] != 'Dịch vụ') return;
  
  setState(() {
    _isLoadingContracts = true;
  });
  
  try {
    final allLinkHopDongs = await _dbHelper.getAllLinkHopDongs();
    final uniquemaKinhDoanhs = allLinkHopDongs
        .where((record) => record.maKinhDoanh != null && 
                          record.maKinhDoanh!.isNotEmpty &&
                          record.maKinhDoanh!.trim().isNotEmpty)
        .map((record) => record.maKinhDoanh!.trim())
        .toSet()
        .toList()
      ..sort(); 
    
    setState(() {
      _availablemaKinhDoanhs = uniquemaKinhDoanhs;
      if (selectedDiaChiVanPhong != null && 
          !uniquemaKinhDoanhs.contains(selectedDiaChiVanPhong)) {
        selectedDiaChiVanPhong = null;
      }
    });
  } catch (e) {
    print('Error loading contracts: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi khi tải danh sách hợp đồng: $e'))
    );
  } finally {
    setState(() {
      _isLoadingContracts = false;
    });
  }
}
Future<void> _onContractSelected(String? selectedmaKinhDoanh) async {
  if (selectedmaKinhDoanh == null) {
    setState(() {
      selectedDiaChiVanPhong = null;
      selectedTrangThaiHopDong = null;
      maSoThueController.text = '';
    });
    return;
  }
  
  try {
    final allLinkHopDongs = await _dbHelper.getAllLinkHopDongs();
    final matchingRecords = allLinkHopDongs
        .where((record) => record.maKinhDoanh == selectedmaKinhDoanh)
        .toList();
    if (matchingRecords.isNotEmpty) {
      matchingRecords.sort((a, b) {
        final aThang = a.thang ?? '';
        final bThang = b.thang ?? '';
        return bThang.compareTo(aThang); 
      });
      final latestRecord = matchingRecords.first;
      setState(() {
        selectedDiaChiVanPhong = selectedmaKinhDoanh;
        if (latestRecord.trangThai != null && latestRecord.trangThai!.isNotEmpty) {
          selectedTrangThaiHopDong = latestRecord.trangThai;
        }
        if (latestRecord.fileHopDong != null && latestRecord.fileHopDong!.isNotEmpty) {
          maSoThueController.text = latestRecord.fileHopDong!;
        }
      });
    }
  } catch (e) {
    print('Error processing contract selection: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi khi xử lý hợp đồng: $e'))
    );
  }
}
  Future<void> _loadSavedUserList() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userList = prefs.getStringList('userList') ?? [];
    });
  }

  Future<void> _syncUserData() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final userCredentials = Provider.of<UserCredentials>(context, listen: false);
      
      final userListResponse = await http.get(
        Uri.parse('$baseUrl/userlist'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (userListResponse.statusCode != 200) {
        throw Exception('Failed to load user list');
      }
      
      final List<dynamic> userListData = json.decode(userListResponse.body);
      setState(() => _userList = List<String>.from(userListData));
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('userList', _userList);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đồng bộ danh sách người dùng thành công'))
      );
    } catch (e) {
      print('Error syncing user data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi đồng bộ: ${e.toString()}'))
      );
    } finally {
      setState(() => _isSyncing = false);
    }
  }
  
  void _initializeNewCustomer() {
    final userCredentials = Provider.of<UserCredentials>(context, listen: false);
    final username = userCredentials.username;
    
    newCustomer['uid'] = _generateUuid();
    newCustomer['nguoiDung'] = username;
    
    if (thuongMaiUsers.contains(username)) {
      newCustomer['phanLoai'] = 'Thương mại';
    } else {
      newCustomer['phanLoai'] = 'Dịch vụ';
    }
    
    newCustomer['loaiHinh'] = 'Dự án';
    
    final now = DateTime.now();
    String formattedDateTime = _formatDateTimeForDb(now);
    newCustomer['ngayCapNhatCuoi'] = formattedDateTime;
    newCustomer['ngayKhoiTao'] = formattedDateTime;
  }
  
  void _loadExistingCustomerData() async {
    if (widget.editingCustomer == null) return;
    
    final customer = widget.editingCustomer!;
    if (customer.chiaSe != null && customer.chiaSe!.isNotEmpty) {
      setState(() {
        _selectedShare = customer.chiaSe!.split(',').map((e) => e.trim()).toList();
      });
    }
    
    newCustomer['uid'] = customer.uid;
    newCustomer['nguoiDung'] = customer.nguoiDung;
    newCustomer['phanLoai'] = customer.phanLoai;
    newCustomer['loaiHinh'] = customer.loaiHinh;
    newCustomer['ngayKhoiTao'] = customer.ngayKhoiTao != null 
        ? _formatDateTimeForDb(customer.ngayKhoiTao!) 
        : _formatDateTimeForDb(DateTime.now());
    
    final now = DateTime.now();
    newCustomer['ngayCapNhatCuoi'] = _formatDateTimeForDb(now);
    diaChiVanPhongController.text = customer.diaChiVanPhong ?? '';
    // Populate form controllers
    tenDuAnController.text = customer.tenDuAn ?? '';
    ghiChuController.text = customer.ghiChu ?? '';
    diaChiController.text = customer.diaChi ?? '';
    maSoThueController.text = customer.maSoThue ?? '';
    soDienThoaiController.text = customer.soDienThoai ?? '';
    faxController.text = customer.fax ?? '';
    websiteController.text = customer.website ?? '';
    emailController.text = customer.email ?? '';
    soTaiKhoanController.text = customer.soTaiKhoan ?? '';
    nganHangController.text = customer.nganHang ?? '';
    tinhThanhController.text = customer.tinhThanh ?? '';
    quanHuyenController.text = customer.quanHuyen ?? '';
    phuongXaController.text = customer.phuongXa ?? '';
    duKienTrienKhaiController.text = customer.duKienTrienKhai ?? '';
    tiemNangDVTMController.text = customer.tiemNangDVTM ?? '';
    yeuCauNhanSuController.text = customer.yeuCauNhanSu ?? '';
    cachThucTuyenController.text = customer.cachThucTuyen ?? '';
    mucLuongTuyenController.text = customer.mucLuongTuyen ?? '';
    luongBPController.text = customer.luongBP ?? '';
    
    setState(() {
      selectedDanhDau = customer.danhDau;
      selectedVungMien = customer.vungMien;
      selectedLoaiHinh = customer.loaiHinh ?? 'Dự án';
      selectedLoaiCongTrinh = customer.loaiCongTrinh;
      selectedTrangThaiHopDong = customer.trangThaiHopDong;
      selectedLoaiMuaHang = customer.loaiMuaHang;
      selectedKenhTiepCan = customer.kenhTiepCan;
    selectedDiaChiVanPhong = customer.diaChiVanPhong?.isNotEmpty == true ? customer.diaChiVanPhong : null;
    });
    
    await _loadExistingContacts(customer.uid!);
    await _loadAvailableContracts();
  }
  
  Future<void> _loadExistingContacts(String customerUid) async {
    try {
      final contactList = await _dbHelper.getContactsByCustomerUid(customerUid);
      
      setState(() {
        contacts = contactList.map((contact) => KhachHangContactDraft(
          uid: contact.uid ?? _generateContactUuid(),
          boPhan: contact.boPhan ?? customerUid,
          nguoiDung: contact.nguoiDung ?? '',
          ngayTao: contact.ngayTao?.toString() ?? _formatDateTimeForDb(DateTime.now()),
          ngayCapNhat: _formatDateTimeForDb(DateTime.now()),
          hoTen: contact.hoTen ?? '',
          gioiTinh: contact.gioiTinh ?? '',
          chucDanh: contact.chucDanh ?? '',
          soDienThoai: contact.soDienThoai ?? '',
          email: contact.email ?? '',
          nguonGoc: contact.nguonGoc ?? '',
        )).toList();
      });
    } catch (e) {
      print('Error loading existing contacts: $e');
    }
  }
  
  @override
  void dispose() {
    diaChiVanPhongController.dispose();
    tenDuAnController.dispose();
    ghiChuController.dispose();
    diaChiController.dispose();
    maSoThueController.dispose();
    soDienThoaiController.dispose();
    faxController.dispose();
    websiteController.dispose();
    emailController.dispose();
    soTaiKhoanController.dispose();
    nganHangController.dispose();
    tinhThanhController.dispose();
    quanHuyenController.dispose();
    phuongXaController.dispose();
    duKienTrienKhaiController.dispose();
    tiemNangDVTMController.dispose();
    yeuCauNhanSuController.dispose();
    cachThucTuyenController.dispose();
    mucLuongTuyenController.dispose();
    luongBPController.dispose();
    
    hoTenController.dispose();
    chucDanhController.dispose();
    soDienThoaiContactController.dispose();
    emailContactController.dispose();
    
    _tabController.dispose();
    
    super.dispose();
  }
  
  String _generateUuid() {
    var random = Random();
    return 'cus_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(10000)}';
  }
  
  String _generateContactUuid() {
    var random = Random();
    return 'con_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(10000)}';
  }
  
  String _formatDateTimeForDb(DateTime dateTime) {
    return "${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)} "
           "${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}:${_twoDigits(dateTime.second)}";
  }
  
  String _twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }
  
  void _saveCustomerForm() {
    if (_formKey.currentState!.validate()) {
        if (newCustomer['phanLoai'] == 'Dịch vụ' && 
        (selectedDiaChiVanPhong == null || selectedDiaChiVanPhong!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng chọn số hợp đồng cho khách hàng dịch vụ'))
      );
      return;
    }
      newCustomer['tenDuAn'] = tenDuAnController.text;
      newCustomer['ghiChu'] = ghiChuController.text;
      newCustomer['diaChi'] = diaChiController.text;
      newCustomer['maSoThue'] = maSoThueController.text;
      newCustomer['soDienThoai'] = soDienThoaiController.text;
      newCustomer['fax'] = faxController.text;
      newCustomer['website'] = websiteController.text;
      newCustomer['email'] = emailController.text;
      newCustomer['soTaiKhoan'] = soTaiKhoanController.text;
      newCustomer['nganHang'] = nganHangController.text;
      newCustomer['tinhThanh'] = tinhThanhController.text;
      newCustomer['quanHuyen'] = quanHuyenController.text;
      newCustomer['phuongXa'] = phuongXaController.text;
      newCustomer['duKienTrienKhai'] = duKienTrienKhaiController.text;
      newCustomer['tiemNangDVTM'] = tiemNangDVTMController.text;
      newCustomer['yeuCauNhanSu'] = yeuCauNhanSuController.text;
      newCustomer['cachThucTuyen'] = cachThucTuyenController.text;
      newCustomer['mucLuongTuyen'] = mucLuongTuyenController.text;
      newCustomer['luongBP'] = luongBPController.text;
    newCustomer['diaChiVanPhong'] = selectedDiaChiVanPhong ?? '';
      newCustomer['danhDau'] = selectedDanhDau;
      newCustomer['vungMien'] = selectedVungMien;
      newCustomer['loaiCongTrinh'] = selectedLoaiCongTrinh;
      newCustomer['trangThaiHopDong'] = selectedTrangThaiHopDong;
      newCustomer['loaiMuaHang'] = selectedLoaiMuaHang;
      newCustomer['kenhTiepCan'] = selectedKenhTiepCan;
      newCustomer['chiaSe'] = _selectedShare.join(',');

      _tabController.animateTo(1);
      
      if (newCustomer['phanLoai'] == 'Dịch vụ' && contacts.isEmpty) {
        _offerPredefinedSubjects();
      }
    }
  }

  Widget _buildSharingField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Chia sẻ với',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Spacer(),
              if (_isSyncing)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: Icon(Icons.sync, size: 16),
                  onPressed: _syncUserData,
                  tooltip: 'Đồng bộ danh sách người dùng',
                ),
            ],
          ),
          SizedBox(height: 8),
          
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: quickShareOptions.entries.map((entry) {
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade100,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size(0, 32),
                ),
                onPressed: () {
                  setState(() {
                    for (String user in entry.value) {
                      if (!_selectedShare.contains(user)) {
                        _selectedShare.add(user);
                      }
                    }
                  });
                },
                child: Text(
                  entry.key,
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              );
            }).toList(),
          ),
          
          SizedBox(height: 8),
          
          if (_selectedShare.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _selectedShare.map((user) {
                  return Chip(
                    label: Text(user, style: TextStyle(fontSize: 12)),
                    deleteIcon: Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _selectedShare.remove(user);
                      });
                    },
                    backgroundColor: Colors.blue.shade50,
                  );
                }).toList(),
              ),
            ),
          
          SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.person_add),
                  label: Text("Thêm người chia sẻ"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _userList.isEmpty ? null : () {
                    _showUserSelectionDialog();
                  },
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.clear),
                onPressed: _selectedShare.isEmpty ? null : () {
                  setState(() {
                    _selectedShare = [];
                  });
                },
                tooltip: 'Xoá tất cả',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUserSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        List<String> tempSelected = List.from(_selectedShare);
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Chọn người chia sẻ'),
              content: Container(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm người dùng...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        // Implement search functionality if needed
                      },
                    ),
                    SizedBox(height: 16),
                    
                    Expanded(
                      child: ListView.builder(
                        itemCount: _userList.length,
                        itemBuilder: (context, index) {
                          final user = _userList[index];
                          final isSelected = tempSelected.contains(user);
                          
                          return CheckboxListTile(
                            title: Text(user),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  if (!tempSelected.contains(user)) {
                                    tempSelected.add(user);
                                  }
                                } else {
                                  tempSelected.remove(user);
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
                  child: Text('Hủy'),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  child: Text('Xác nhận', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedShare = tempSelected;
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  void _offerPredefinedSubjects() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tạo danh mục (DỊCH VỤ)'),
        content: Text(
          'Bạn có muốn tạo các danh mục chủ đề mặc định cho khách hàng dịch vụ không?'
        ),
        actions: [
          TextButton(
            child: Text('Không'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Có, tạo danh mục', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
            ),
            onPressed: () {
              Navigator.pop(context);
              _createPredefinedSubjects();
            },
          ),
        ],
      ),
    );
  }
  
  void _createPredefinedSubjects() {
    final userCredentials = Provider.of<UserCredentials>(context, listen: false);
    final username = userCredentials.username;
    final now = _formatDateTimeForDb(DateTime.now());
    
    setState(() {
      for (String subject in predefinedSubjects) {
        contacts.add(
          KhachHangContactDraft(
            uid: _generateContactUuid(),
            boPhan: newCustomer['uid'],
            nguoiDung: username,
            ngayTao: now,
            ngayCapNhat: now,
            hoTen: subject,
          )
        );
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã tạo ${predefinedSubjects.length} danh mục người liên hệ'))
    );
  }
  
  void _addNewContact() {
    hoTenController.clear();
    chucDanhController.clear();
    soDienThoaiContactController.clear();
    emailContactController.clear();
    selectedGioiTinh = null;
    selectedNguonGoc = null;
    
    setState(() {
      currentContact = null;
    });
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Thêm người liên hệ mới'),
        content: SingleChildScrollView(
          child: Form(
            key: _contactFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(
                  'Họ tên *',
                  hoTenController,
                  validator: (value) => value == null || value.isEmpty ? 'Vui lòng nhập họ tên' : null,
                ),
                
                _buildDropdownField(
                  'Giới tính',
                  ['Nam', 'Nữ'],
                  selectedGioiTinh,
                  (value) => setState(() => selectedGioiTinh = value),
                ),
                
                _buildTextField('Chức danh', chucDanhController),
                
                _buildTextField(
                  'Số điện thoại', 
                  soDienThoaiContactController,
                  keyboardType: TextInputType.phone
                ),
                
                _buildTextField(
                  'Email', 
                  emailContactController,
                  keyboardType: TextInputType.emailAddress
                ),
                
                _buildDropdownField(
                  'Nguồn gốc',
                  [
                    'Trực tiếp', 'Giới thiệu', 'Facebook', 'Zalo', 'Website',
                    'Shopee', 'Tiki', 'Email', 'Viber', 'Telesale', 'Quảng cáo',
                    'Nhắn tin', 'Khảo sát/ Form'
                  ],
                  selectedNguonGoc,
                  (value) => setState(() => selectedNguonGoc = value),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            child: Text('Hủy'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Lưu', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
            ),
            onPressed: () {
              if (_contactFormKey.currentState!.validate()) {
                final userCredentials = Provider.of<UserCredentials>(context, listen: false);
                final username = userCredentials.username;
                final now = _formatDateTimeForDb(DateTime.now());
                
                final newContact = KhachHangContactDraft(
                  uid: _generateContactUuid(),
                  boPhan: newCustomer['uid'],
                  nguoiDung: username,
                  ngayTao: now,
                  ngayCapNhat: now,
                  hoTen: hoTenController.text,
                  gioiTinh: selectedGioiTinh ?? '',
                  chucDanh: chucDanhController.text,
                  soDienThoai: soDienThoaiContactController.text,
                  email: emailContactController.text,
                  nguonGoc: selectedNguonGoc ?? '',
                );
                
                setState(() {
                  contacts.add(newContact);
                });
                
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
  
  void _editContact(int index) {
    final contact = contacts[index];
    
    hoTenController.text = contact.hoTen;
    chucDanhController.text = contact.chucDanh;
    soDienThoaiContactController.text = contact.soDienThoai;
    emailContactController.text = contact.email;
    
    setState(() {
      selectedGioiTinh = contact.gioiTinh.isNotEmpty ? contact.gioiTinh : null;
      selectedNguonGoc = contact.nguonGoc.isNotEmpty ? contact.nguonGoc : null;
      currentContact = contact;
    });
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chỉnh sửa người liên hệ'),
        content: SingleChildScrollView(
          child: Form(
            key: _contactFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(
                 'Họ tên *',
                 hoTenController,
                 validator: (value) => value == null || value.isEmpty ? 'Vui lòng nhập họ tên' : null,
               ),
               
               _buildDropdownField(
                 'Giới tính',
                 ['Nam', 'Nữ'],
                 selectedGioiTinh,
                 (value) => setState(() => selectedGioiTinh = value),
               ),
               
               _buildTextField('Chức danh', chucDanhController),
               
               _buildTextField(
                 'Số điện thoại', 
                 soDienThoaiContactController,
                 keyboardType: TextInputType.phone
               ),
               
               _buildTextField(
                 'Email', 
                 emailContactController,
                 keyboardType: TextInputType.emailAddress
               ),
               
               _buildDropdownField(
                 'Nguồn gốc',
                 [
                   'Trực tiếp', 'Giới thiệu', 'Facebook', 'Zalo', 'Website',
                   'Shopee', 'Tiki', 'Email', 'Viber', 'Telesale', 'Quảng cáo',
                   'Nhắn tin', 'Khảo sát/ Form'
                 ],
                 selectedNguonGoc,
                 (value) => setState(() => selectedNguonGoc = value),
               ),
             ],
           ),
         ),
       ),
       actions: [
         TextButton(
           child: Text('Hủy'),
           onPressed: () => Navigator.pop(context),
         ),
         ElevatedButton(
           child: Text('Cập nhật', style: TextStyle(color: Colors.white)),
           style: ElevatedButton.styleFrom(
             backgroundColor: buttonColor,
           ),
           onPressed: () {
             if (_contactFormKey.currentState!.validate()) {
               final now = _formatDateTimeForDb(DateTime.now());
               
               setState(() {
                 contact.hoTen = hoTenController.text;
                 contact.gioiTinh = selectedGioiTinh ?? '';
                 contact.chucDanh = chucDanhController.text;
                 contact.soDienThoai = soDienThoaiContactController.text;
                 contact.email = emailContactController.text;
                 contact.nguonGoc = selectedNguonGoc ?? '';
                 contact.ngayCapNhat = now;
                 
                 contacts[index] = contact;
               });
               
               Navigator.pop(context);
             }
           },
         ),
       ],
     ),
   );
 }
 
 void _deleteContact(int index) {
   showDialog(
     context: context,
     builder: (context) => AlertDialog(
       title: Text('Xóa người liên hệ'),
       content: Text('Bạn có chắc chắn muốn xóa "${contacts[index].hoTen}"?'),
       actions: [
         TextButton(
           child: Text('Hủy'),
           onPressed: () => Navigator.pop(context),
         ),
         ElevatedButton(
           child: Text('Xóa'),
           style: ElevatedButton.styleFrom(
             backgroundColor: Colors.red,
           ),
           onPressed: () {
             setState(() {
               contacts.removeAt(index);
             });
             Navigator.pop(context);
           },
         ),
       ],
     ),
   );
 }
 
 Future<void> _submitData() async {
   if (contacts.isEmpty) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('Vui lòng thêm ít nhất một người liên hệ'))
     );
     return;
   }
   
   setState(() {
     _isSubmitting = true;
   });
   
   try {
     final customerResponse = await _submitCustomer();
     final contactResponses = await _submitContacts();
     
     _showSubmitRecapDialog(customerResponse, contactResponses);
   } catch (e) {
     print('Error submitting data: $e');
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('Lỗi khi gửi dữ liệu: $e'))
     );
   } finally {
     setState(() {
       _isSubmitting = false;
     });
   }
 }
 
 Future<Map<String, dynamic>> _submitCustomer() async {
   final String endpoint = isEditMode 
     ? 'https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelkhachhangupdate'
     : 'https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelkhachhangmoi';
   
   final response = await http.post(
     Uri.parse(endpoint),
     headers: {'Content-Type': 'application/json'},
     body: json.encode(newCustomer),
   );
   
   print('Customer request body: ${json.encode(newCustomer)}');
   print('Customer response code: ${response.statusCode}');
   print('Customer response body: ${response.body}');
   
   if (response.statusCode == 200) {
     return {
       'success': true,
       'message': isEditMode 
         ? 'Dữ liệu khách hàng đã được cập nhật thành công'
         : 'Dữ liệu khách hàng đã được gửi thành công',
       'response': response.body,
     };
   } else {
     throw Exception('Failed to ${isEditMode ? "update" : "submit"} customer data: ${response.statusCode}, ${response.body}');
   }
 }

 Future<List<Map<String, dynamic>>> _submitContacts() async {
  List<Map<String, dynamic>> results = [];
  
  for (var contact in contacts) {
    // Check if this is a new contact or existing one
    bool isNewContact = await _isNewContact(contact.uid);
    
    final String endpoint = isNewContact
      ? 'https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelcontactmoi'
      : 'https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelcontactupdate';
      
    final requestBody = contact.toMap();
    
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(requestBody),
    );
    
    print('Contact request body: ${json.encode(requestBody)}');
    print('Contact response code: ${response.statusCode}');
    print('Contact response body: ${response.body}');
    
    results.add({
      'contact': contact.hoTen,
      'success': response.statusCode == 200,
      'message': response.statusCode == 200 
        ? (isNewContact ? 'Tạo mới thành công' : 'Cập nhật thành công')
        : 'Lỗi: ${response.statusCode}',
      'response': response.body,
    });
  }
  
  return results;
}

Future<bool> _isNewContact(String contactUid) async {
  try {
    // Check if the contact exists in the local database
    final existingContacts = await _dbHelper.getContactsByCustomerUid(widget.editingCustomer?.uid ?? '');
    return !existingContacts.any((contact) => contact.uid == contactUid);
  } catch (e) {
    print('Error checking contact existence: $e');
    // If we can't determine, assume it's new to be safe
    return true;
  }
}
 
 void _showSubmitRecapDialog(
   Map<String, dynamic> customerResult,
   List<Map<String, dynamic>> contactResults
 ) {
   showDialog(
     context: context,
     barrierDismissible: false,
     builder: (context) => AlertDialog(
       title: Text('Kết quả đồng bộ dữ liệu'),
       content: SingleChildScrollView(
         child: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text(
               'Khách hàng: ${customerResult['success'] ? '✅ Thành công' : '❌ Thất bại'}',
               style: TextStyle(fontWeight: FontWeight.bold),
             ),
             Text(customerResult['message']),
             SizedBox(height: 16),
             
             Text(
               'Người liên hệ:',
               style: TextStyle(fontWeight: FontWeight.bold),
             ),
             ...contactResults.map((result) => Padding(
               padding: const EdgeInsets.only(bottom: 8.0),
               child: Text(
                 '${result['contact']}: ${result['success'] ? '✅' : '❌'} ${result['message']}',
               ),
             )),
           ],
         ),
       ),
       actions: [
         ElevatedButton(
           child: Text('Hoàn tất', style: TextStyle(color: Colors.white)),
           style: ElevatedButton.styleFrom(
             backgroundColor: buttonColor,
           ),
           onPressed: () {
             Navigator.pop(context); 
             Navigator.pop(context, true); 
           },
         ),
       ],
     ),
   );
 }
 
 void _showTenDuAnConfirmDialog() {
   showDialog(
     context: context,
     builder: (context) => AlertDialog(
       title: Text('Xác nhận tên dự án'),
       content: Text(
         'Tên dự án "${tenDuAnController.text}" sẽ không thể thay đổi sau khi lưu. Bạn có chắc chắn muốn sử dụng tên này không?'
       ),
       actions: [
         TextButton(
           child: Text('Chỉnh sửa lại'),
           onPressed: () => Navigator.pop(context),
         ),
         ElevatedButton(
           child: Text('Xác nhận'),
           style: ElevatedButton.styleFrom(
             backgroundColor: buttonColor,
           ),
           onPressed: () => Navigator.pop(context),
         ),
       ],
     ),
   );
 }
 
 @override
 Widget build(BuildContext context) {
   return DefaultTabController(
     length: 2,
     child: Scaffold(
       appBar: AppBar(
         flexibleSpace: Container(
           decoration: BoxDecoration(
             gradient: LinearGradient(
               begin: Alignment.topCenter,
               end: Alignment.bottomCenter,
               colors: [appBarTop, appBarBottom],
             ),
           ),
         ),
         title: Text(
           isEditMode ? 'Chỉnh sửa khách hàng' : 'Thêm khách hàng mới',
           style: TextStyle(color: Colors.white)
         ),
         bottom: TabBar(
           controller: _tabController,
           indicatorColor: Colors.orange,
           labelColor: Colors.white,
           tabs: [
             Tab(text: 'Thông tin khách hàng'),
             Tab(text: 'Người liên hệ'),
           ],
         ),
       ),
       body: TabBarView(
         controller: _tabController,
         children: [
           // Tab 1: Customer Information Form
           SingleChildScrollView(
             padding: EdgeInsets.all(16.0),
             child: Form(
               key: _formKey,
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.stretch,
                 children: [
                   _buildInfoField('UID (tự động)', newCustomer['uid'] ?? '', enabled: false),
                   SizedBox(height: 16),
                   
                   _buildInfoField('Người dùng', newCustomer['nguoiDung'] ?? '', enabled: false),
                   SizedBox(height: 16),
                   
                   _buildDropdownField(
                     'Đánh dấu',
                     ['', '1'],
                     selectedDanhDau,
                     (value) => setState(() => selectedDanhDau = value),
                   ),
                   
                   _buildDropdownField(
                     'Vùng miền *',
                     ['Bắc', 'Trung', 'Nam'],
                     selectedVungMien,
                     (value) => setState(() => selectedVungMien = value),
                     validator: (value) => value == null ? 'Vui lòng chọn vùng miền' : null,
                   ),
                   
                   _buildInfoField('Phân loại', newCustomer['phanLoai'] ?? '', enabled: false),
                   SizedBox(height: 16),
                   
                   _buildInfoField('Loại hình', selectedLoaiHinh, enabled: false),
                   SizedBox(height: 16),
                   
                   _buildDropdownField(
                     'Loại công trình *',
                     [
                       'Đại lý', 'Khách hàng lẻ', 'Khách sạn 5*', 'Khách sạn 4*',
                       'Khách sạn 3*', 'Nhà hàng', 'Giặt là', 'Resort', 'Nhà máy KCN',
                       'Bệnh viện', 'Tòa nhà', 'Trường học', 'Sân bay Bến xe',
                       'Khách thương mại', 'Du thuyền', 'Cty Dịch vụ', 'Căn hộ dịch vụ',
                       'Khu đô thị', 'Chung cư', 'Tòa nhà cao cấp', 'VP lẻ',
                       'Trung tâm thương mại', 'Homestay', 'Khách sạn'
                     ],
                     selectedLoaiCongTrinh,
                     (value) => setState(() => selectedLoaiCongTrinh = value),
                     validator: (value) => value == null ? 'Vui lòng chọn loại công trình' : null,
                   ),
                   if (newCustomer['phanLoai'] == 'Dịch vụ') ...[
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Số hợp đồng *',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      SizedBox(height: 4),
      DropdownButtonFormField<String>(
        value: selectedDiaChiVanPhong,
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          suffixIcon: _isLoadingContracts 
            ? SizedBox(
                width: 20,
                height: 20,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
        ),
        items: _availablemaKinhDoanhs.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: _isLoadingContracts ? null : _onContractSelected,
        validator: (value) => value == null ? 'Vui lòng chọn số hợp đồng' : null,
        hint: _isLoadingContracts 
          ? Text('Đang tải hợp đồng...')
          : Text('Chọn số hợp đồng'),
      ),
      SizedBox(height: 16),
    ],
  ),
],

                   _buildDropdownField(
  'Trạng thái hợp đồng *',
  ['Tiếp cận', 'Quan tâm', 'Báo giá', 'Đã ký', 'Dừng', 'Thất bại'],
  selectedTrangThaiHopDong,
  (value) => setState(() => selectedTrangThaiHopDong = value),
  validator: (value) => value == null ? 'Vui lòng chọn trạng thái hợp đồng' : null,
),
                   
                   _buildTextField(
                     'Tên dự án *',
                     tenDuAnController,
                     validator: (value) => value == null || value.isEmpty ? 'Vui lòng nhập tên dự án' : null,
                     helperText: 'Lưu ý: Tên dự án không thể thay đổi sau khi lưu. Hãy kiểm tra kỹ trước khi nhập.',
                     onEditingComplete: () {
                       if (tenDuAnController.text.isNotEmpty) {
                         _showTenDuAnConfirmDialog();
                       }
                     },
                   ),
                   
                   _buildTextField('Ghi chú', ghiChuController, maxLines: 3),
                   _buildSharingField(),

                   _buildTextField('Địa chỉ', diaChiController),
                   _buildTextField('Mã số thuế', maSoThueController),
                   _buildTextField(
                     'Số điện thoại', 
                     soDienThoaiController,
                     keyboardType: TextInputType.phone
                   ),
                   _buildTextField('Fax', faxController),
                   _buildTextField('Website', websiteController),
                   _buildTextField(
                     'Email', 
                     emailController,
                     keyboardType: TextInputType.emailAddress
                   ),
                   _buildTextField('Số tài khoản', soTaiKhoanController),
                   _buildTextField('Ngân hàng', nganHangController),
                   
                   _buildDropdownField(
                     'Loại mua hàng',
                     ['C1 Khách hàng mở mới', 'C1 Khách dự án', 'C1 Khách chăm sóc lại', 'C2 Khách truyền thống'],
                     selectedLoaiMuaHang,
                     (value) => setState(() => selectedLoaiMuaHang = value),
                   ),
                   
                   _buildTextField('Tỉnh thành', tinhThanhController),
                   _buildTextField('Quận huyện', quanHuyenController),
                   _buildTextField('Phường xã', phuongXaController),
                   
                   _buildDropdownField(
                     'Kênh tiếp cận',
                     [
                       'Trực tiếp', 'Giới thiệu', 'Facebook', 'Zalo', 'Website',
                       'Shopee', 'Tiki', 'Email', 'Viber', 'Telesale', 'Quảng cáo',
                       'Nhắn tin', 'Khảo sát/ Form'
                     ],
                     selectedKenhTiepCan,
                     (value) => setState(() => selectedKenhTiepCan = value),
                   ),
                   
                   _buildTextField('Dự kiến triển khai', duKienTrienKhaiController),
                   _buildTextField('Tiềm năng DVTM', tiemNangDVTMController),
                   _buildTextField('Yêu cầu nhân sự', yeuCauNhanSuController),
                   _buildTextField('Cách thức tuyển', cachThucTuyenController),
                   _buildTextField('Mức lương tuyển', mucLuongTuyenController),
                   _buildTextField('Lương BP', luongBPController),
                   
                   SizedBox(height: 24),
                   
                   ElevatedButton(
                     style: ElevatedButton.styleFrom(
                       backgroundColor: buttonColor,
                       padding: EdgeInsets.symmetric(vertical: 16),
                     ),
                     onPressed: _saveCustomerForm,
                     child: Text(
                       'Lưu và tiếp tục',
                       style: TextStyle(fontSize: 16, color: Colors.white),
                     ),
                   ),
                 ],
               ),
             ),
           ),
           
           // Tab 2: Contact Management
           Stack(
             children: [
               Column(
                 children: [
                   Expanded(
                     child: _buildContactsList(),
                   ),
                   
                   Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Row(
                       children: [
                         if (newCustomer['phanLoai'] == 'Dịch vụ')
                           Expanded(
                             flex: 1,
                             child: ElevatedButton.icon(
                               icon: Icon(Icons.list),
                               label: Text('Tạo danh mục', style: TextStyle(color: Colors.black)),
                               style: ElevatedButton.styleFrom(
                                 backgroundColor: Colors.amber[500],
                                 padding: EdgeInsets.symmetric(vertical: 12),
                               ),
                               onPressed: contacts.isEmpty ? _offerPredefinedSubjects : null,
                             ),
                           ),
                         
                         SizedBox(width: 8),
                         
                         Expanded(
                           flex: 1,
                           child: ElevatedButton.icon(
                             icon: Icon(Icons.person_add, color: Colors.white),
                             label: Text('Thêm liên hệ', style: TextStyle(color: Colors.white)),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: buttonColor,
                               padding: EdgeInsets.symmetric(vertical: 12),
                             ),
                             onPressed: _addNewContact,
                           ),
                         ),
                       ],
                     ),
                   ),
                   
                   Padding(
                     padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                     child: ElevatedButton(
                       style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.green,
                         padding: EdgeInsets.symmetric(vertical: 16),
                       ),
                       onPressed: _isSubmitting ? null : _submitData,
                       child: _isSubmitting 
                         ? Row(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               SizedBox(
                                 width: 20,
                                 height: 20,
                                 child: CircularProgressIndicator(
                                   color: Colors.white,
                                   strokeWidth: 2,
                                 ),
                               ),
                               SizedBox(width: 10),
                               Text(
                                 isEditMode ? 'Đang cập nhật dữ liệu...' : 'Đang gửi dữ liệu...',
                                 style: TextStyle(fontSize: 14),
                               ),
                             ],
                           )
                         : Text(
                             isEditMode ? 'Cập nhật dữ liệu' : 'Gửi dữ liệu lên server',
                             style: TextStyle(fontSize: 14, color: Colors.white),
                           ),
                     ),
                   ),
                 ],
               ),
               
               if (_isSubmitting)
                 Container(
                   color: Colors.black.withOpacity(0.3),
                   child: Center(
                     child: Card(
                       elevation: 8,
                       child: Padding(
                         padding: const EdgeInsets.all(20.0),
                         child: Column(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             CircularProgressIndicator(color: buttonColor),
                             SizedBox(height: 16),
                             Text('Đang gửi dữ liệu...', style: TextStyle(fontSize: 16)),
                           ],
                         ),
                       ),
                     ),
                   ),
                 ),
             ],
           ),
         ],
       ),
     ),
   );
 }
 
 Widget _buildContactsList() {
   if (contacts.isEmpty) {
     return Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(Icons.people_alt_outlined, size: 64, color: Colors.grey),
           SizedBox(height: 16),
           Text(
             'Chưa có người liên hệ',
             style: TextStyle(fontSize: 18, color: Colors.grey),
           ),
           Text(
             'Vui lòng thêm ít nhất một người liên hệ',
             style: TextStyle(fontSize: 14, color: Colors.grey),
           ),
         ],
       ),
     );
   }
   
   return ListView.builder(
     itemCount: contacts.length,
     itemBuilder: (context, index) {
       final contact = contacts[index];
       
       return Card(
         margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
         child: ListTile(
           title: Text(
             contact.hoTen,
             style: TextStyle(fontWeight: FontWeight.bold),
           ),
           subtitle: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               if (contact.chucDanh.isNotEmpty)
                 Text(contact.chucDanh),
               if (contact.soDienThoai.isNotEmpty || contact.email.isNotEmpty)
                 Text(
                   [
                     if (contact.soDienThoai.isNotEmpty) contact.soDienThoai,
                     if (contact.email.isNotEmpty) contact.email,
                   ].join(' • '),
                   style: TextStyle(fontSize: 12),
                 ),
             ],
           ),
           trailing: Row(
             mainAxisSize: MainAxisSize.min,
             children: [
               IconButton(
                 icon: Icon(Icons.edit, color: buttonColor),
                 onPressed: () => _editContact(index),
               ),
               IconButton(
                 icon: Icon(Icons.delete, color: Colors.red),
                 onPressed: () => _deleteContact(index),
               ),
             ],
           ),
         ),
       );
     },
   );
 }
 
 Widget _buildInfoField(String label, String value, {bool enabled = true}) {
   return Column(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
       Text(
         label,
         style: TextStyle(
           fontWeight: FontWeight.bold,
           fontSize: 14,
         ),
       ),
       SizedBox(height: 4),
       TextField(
         controller: TextEditingController(text: value),
         enabled: enabled,
         decoration: InputDecoration(
           border: OutlineInputBorder(),
           contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
           filled: !enabled,
           fillColor: enabled ? null : Colors.grey[200],
         ),
       ),
     ],
   );
 }
 
 Widget _buildTextField(
   String label, 
   TextEditingController controller, {
   int maxLines = 1,
   String? Function(String?)? validator,
   String? helperText,
   TextInputType keyboardType = TextInputType.text,
   Function()? onEditingComplete,
 }) {
   return Padding(
     padding: const EdgeInsets.only(bottom: 16.0),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text(
           label,
           style: TextStyle(
             fontWeight: FontWeight.bold,
             fontSize: 14,
           ),
         ),
         SizedBox(height: 4),
         TextFormField(
           controller: controller,
           decoration: InputDecoration(
             border: OutlineInputBorder(),
             contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
             helperText: helperText,
             helperMaxLines: 3,
           ),
           maxLines: maxLines,
           validator: validator,
           keyboardType: keyboardType,
           onEditingComplete: onEditingComplete,
         ),
       ],
     ),
   );
 }
 
 Widget _buildDropdownField(
  String label,
  List<String> items,
  String? selectedValue,
  Function(String?) onChanged, {
  String? Function(String?)? validator,
}) {
  final uniqueItems = items
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList()
    ..sort(); 
  
  String? validSelectedValue = selectedValue;
  if (selectedValue != null && !uniqueItems.contains(selectedValue)) {
    validSelectedValue = null;
  }

  return Padding(
    padding: const EdgeInsets.only(bottom: 16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: validSelectedValue,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: uniqueItems.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    ),
  );
}
}

class KhachHangContactDraft {
 String uid;
 String boPhan;
 String nguoiDung;
 String ngayTao;
 String ngayCapNhat;
 String hoTen;
 String gioiTinh;
 String chucDanh;
 String soDienThoai;
 String email;
 String nguonGoc;
 
 KhachHangContactDraft({
   required this.uid,
   required this.boPhan,
   required this.nguoiDung,
   required this.ngayTao,
   required this.ngayCapNhat,
   required this.hoTen,
   this.gioiTinh = '',
   this.chucDanh = '',
   this.soDienThoai = '',
   this.email = '',
   this.nguonGoc = '',
 });
 
 Map<String, dynamic> toMap() {
   return {
     'uid': uid,
     'boPhan': boPhan,
     'nguoiDung': nguoiDung,
     'ngayTao': ngayTao,
     'ngayCapNhat': ngayCapNhat,
     'hoTen': hoTen,
     'gioiTinh': gioiTinh,
     'chucDanh': chucDanh,
     'soDienThoai': soDienThoai,
     'email': email,
     'nguonGoc': nguonGoc,
   };
 }
}