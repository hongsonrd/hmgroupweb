import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:provider/provider.dart';
import 'user_credentials.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HSKhachHangScreen extends StatefulWidget {
  @override
  _HSKhachHangScreenState createState() => _HSKhachHangScreenState();
}

class _HSKhachHangScreenState extends State<HSKhachHangScreen> {
  final DBHelper _dbHelper = DBHelper();
  List<KhachHangModel> _khachHangList = [];
  List<KhachHangModel> _filteredList = [];
  bool _isLoading = true;
  String _searchText = '';
  String _filterBy = 'Tất cả';
  String _sortBy = 'tenDuAn';
  bool _sortAscending = true;
String? username;
  // Color scheme to match main app
  final Color appBarTop = Color(0xFF024965);
  final Color appBarBottom = Color(0xFF03a6cf);
  final Color buttonColor = Color(0xFF33a7ce);
  final Color searchBarColor = Color(0xFF35abb5);
  final Color tabBarColor = Color(0xFF034d58);
  
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadKhachHangData();
    _checkAndPerformDailySync();
  }
@override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (username == null) {
      final userCredentials = Provider.of<UserCredentials>(context, listen: false);
      username = userCredentials.username.toUpperCase();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  Future<void> _checkAndPerformDailySync() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10); 
    final lastSyncDate = prefs.getString('last_sync_date');
    
    if (lastSyncDate != today) {
      print('Performing daily auto-sync...');
      await _refreshData();
      await prefs.setString('last_sync_date', today);
      print('Daily sync completed and date saved');
    } else {
      print('Daily sync already performed today');
    }
  }
  Future<void> _loadKhachHangData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final List<KhachHangModel> khachHangData = await _dbHelper.getAllKhachHang();
      setState(() {
        _khachHangList = khachHangData;
        _filteredList = List.from(khachHangData);
        _applyFiltersAndSort();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading customer data: $e');
      setState(() {
        _isLoading = false;
      });
      
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải dữ liệu khách hàng: $e'))
      );
    }
  }

  void _applyFiltersAndSort() {
    // First apply filters
    if (_filterBy == 'Tất cả') {
      _filteredList = List.from(_khachHangList);
    } else {
      _filteredList = _khachHangList.where((customer) => 
        customer.phanLoai == _filterBy || 
        customer.loaiHinh == _filterBy || 
        customer.vungMien == _filterBy
      ).toList();
    }
    
    // Then apply search
    if (_searchText.isNotEmpty) {
      _filteredList = _filteredList.where((customer) {
        final search = _searchText.toLowerCase();
        return (customer.tenDuAn?.toLowerCase().contains(search) ?? false) ||
               (customer.tenKyThuat?.toLowerCase().contains(search) ?? false) ||
               (customer.tenRutGon?.toLowerCase().contains(search) ?? false) ||
               (customer.diaChi?.toLowerCase().contains(search) ?? false) ||
               (customer.soDienThoai?.toLowerCase().contains(search) ?? false);
      }).toList();
    }
    
    // Finally, sort the data
    _filteredList.sort((a, b) {
      dynamic valA, valB;
      
      // Handle different sort fields
      switch (_sortBy) {
        case 'tenDuAn':
          valA = a.tenDuAn ?? '';
          valB = b.tenDuAn ?? '';
          break;
        case 'vungMien':
          valA = a.vungMien ?? '';
          valB = b.vungMien ?? '';
          break;
        case 'phanLoai':
          valA = a.phanLoai ?? '';
          valB = b.phanLoai ?? '';
          break;
        case 'ngayCapNhatCuoi':
          valA = a.ngayCapNhatCuoi ?? DateTime(1900);
          valB = b.ngayCapNhatCuoi ?? DateTime(1900);
          break;
        default:
          valA = a.tenDuAn ?? '';
          valB = b.tenDuAn ?? '';
      }
      
      // Perform comparison based on value types
      int result;
      if (valA is String && valB is String) {
        result = valA.compareTo(valB);
      } else if (valA is DateTime && valB is DateTime) {
        result = valA.compareTo(valB);
      } else if (valA is num && valB is num) {
        result = valA.compareTo(valB);
      } else {
        result = 0;
      }
      
      return _sortAscending ? result : -result;
    });
  }

  void _updateSearchQuery(String query) {
    setState(() {
      _searchText = query;
      _applyFiltersAndSort();
    });
  }

  void _updateFilter(String filter) {
    setState(() {
      _filterBy = filter;
      _applyFiltersAndSort();
    });
  }

  void _updateSort(String sortField) {
    setState(() {
      if (_sortBy == sortField) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = sortField;
        _sortAscending = true;
      }
      _applyFiltersAndSort();
    });
  }

  Future<void> _refreshData() async {
  final userCredentials = Provider.of<UserCredentials>(context, listen: false);
  final username = userCredentials.username;
  
  try {
    // Show refresh indicator
    setState(() {
      _isLoading = true;
    });
    
    // Sync both KhachHang and KhachHangContact data
    await Future.wait([
      _syncKhachHang(username),
      _syncKhachHangContact(username)
    ]);
    
    // Reload data from local database
    await _loadKhachHangData();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Dữ liệu đã được cập nhật'))
    );
  } catch (e) {
    print('Error during refresh: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi khi cập nhật dữ liệu: $e'))
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

Future<void> _syncKhachHang(String username) async {
  final String requestUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelkhachhang/$username';
  print('Making request to: $requestUrl');
  
  final response = await http.get(
    Uri.parse(requestUrl),
    headers: {'Content-Type': 'application/json'},
  );
  
  if (response.statusCode == 200) {
    final List<dynamic> khachHangData = json.decode(response.body);
    
    if (khachHangData.isNotEmpty) {
      // Clear existing data
      await _dbHelper.clearKhachHangTable();
      
      // Insert new data
      for (var item in khachHangData) {
        final khachHang = KhachHangModel.fromMap(item);
        await _dbHelper.insertKhachHang(khachHang);
      }
      
      print('KhachHang sync completed successfully');
    }
  } else {
    throw Exception('Failed to sync KhachHang data: ${response.statusCode}');
  }
}

Future<void> _syncKhachHangContact(String username) async {
  final String requestUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelkhachhangcontact/$username';
  print('Making request to: $requestUrl');
  
  final response = await http.get(
    Uri.parse(requestUrl),
    headers: {'Content-Type': 'application/json'},
  );
  
  if (response.statusCode == 200) {
    final List<dynamic> contactData = json.decode(response.body);
    
    if (contactData.isNotEmpty) {
      // Clear existing data
      await _dbHelper.clearKhachHangContactTable();
      
      // Insert new data
      for (var item in contactData) {
        final contact = KhachHangContactModel.fromMap(item);
        await _dbHelper.insertKhachHangContact(contact);
      }
      
      print('KhachHangContact sync completed successfully');
    }
  } else {
    throw Exception('Failed to sync KhachHangContact data: ${response.statusCode}');
  }
}
  
  Future<void> _callCustomer(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Số điện thoại không có sẵn'))
      );
      return;
    }
    
    final Uri telUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await url_launcher.canLaunchUrl(telUri)) {
      await url_launcher.launchUrl(telUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể gọi số $phoneNumber'))
      );
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
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
      title: Text('DS khách hàng', style: TextStyle(color: Colors.white),),
      actions: [
        IconButton(
          icon: Icon(Icons.filter_list),
          onPressed: () {
            _showFilterDialog();
          },
        ),
        IconButton(
          icon: Icon(Icons.sort),
          onPressed: () {
            _showSortDialog();
          },
        ),
      ],
    ),
    body: Column(
      children: [
        _buildSearchBar(),
        _buildFilterChips(),
        Expanded(
          child: _buildCustomerList(),
        ),
      ],
    ),
    floatingActionButton: Column(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    FloatingActionButton(
      backgroundColor: Colors.blue[200],
      heroTag: "add",
      child: Icon(Icons.add),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddKhachHangScreen()),
        ).then((value) {
          if (value == true) {
            // Refresh data if customer was added successfully
            _refreshData();
          }
        });
      },
    ),
    SizedBox(height: 16),
    FloatingActionButton(
      backgroundColor: Colors.blue[200],
      heroTag: "refresh",
      child: Icon(Icons.refresh),
      onPressed: _refreshData,
    ),
  ],
),
  );
}

  Widget _buildSearchBar() {
    return Container(
      color: searchBarColor.withOpacity(0.1),
      padding: EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm theo tên, địa chỉ, số điện thoại...',
          prefixIcon: Icon(Icons.search, color: searchBarColor),
          suffixIcon: _searchText.isNotEmpty 
            ? IconButton(
                icon: Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _updateSearchQuery('');
                },
              )
            : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 0.0),
        ),
        onChanged: _updateSearchQuery,
      ),
    );
  }

  Widget _buildFilterChips() {
    // Get unique values for filter options
    final Set<String> phanLoaiSet = _khachHangList
        .where((c) => c.phanLoai != null && c.phanLoai!.isNotEmpty)
        .map((c) => c.phanLoai!)
        .toSet();
    
    final Set<String> vungMienSet = _khachHangList
        .where((c) => c.vungMien != null && c.vungMien!.isNotEmpty)
        .map((c) => c.vungMien!)
        .toSet();
    
    // Create a list of all filter values
    final List<String> filterOptions = ['Tất cả', ...phanLoaiSet, ...vungMienSet];
    
    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filterOptions.length,
        itemBuilder: (context, index) {
          final option = filterOptions[index];
          final isSelected = _filterBy == option;
          
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(option),
              selected: isSelected,
              selectedColor: buttonColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
              ),
              onSelected: (selected) {
                if (selected) {
                  _updateFilter(option);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomerList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (_filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Không tìm thấy khách hàng',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            if (_searchText.isNotEmpty || _filterBy != 'Tất cả')
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchText = '';
                    _filterBy = 'Tất cả';
                    _applyFiltersAndSort();
                  });
                },
                child: Text('Xóa bộ lọc'),
              ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        itemCount: _filteredList.length,
        itemBuilder: (context, index) {
          final customer = _filteredList[index];
          return _buildCustomerCard(customer);
        },
      ),
    );
  }

  Widget _buildCustomerCard(KhachHangModel customer) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        title: Text(
          customer.tenDuAn ?? 'Không có tên',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${customer.phanLoai ?? ''} ${customer.vungMien != null ? '• ${customer.vungMien}' : ''}',
          style: TextStyle(fontSize: 12),
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (customer.tenKyThuat != null && customer.tenKyThuat!.isNotEmpty)
                  _buildInfoRow('Tên kỹ thuật:', customer.tenKyThuat!),
                if (customer.diaChi != null && customer.diaChi!.isNotEmpty)
                  _buildInfoRow('Địa chỉ:', customer.diaChi!),
                if (customer.diaChiVanPhong != null && customer.diaChiVanPhong!.isNotEmpty)
                  _buildInfoRow('Địa chỉ VP:', customer.diaChiVanPhong!),
                if (customer.soDienThoai != null && customer.soDienThoai!.isNotEmpty)
                  _buildInfoRow('Điện thoại:', customer.soDienThoai!, isPhone: true),
                if (customer.website != null && customer.website!.isNotEmpty)
                  _buildInfoRow('Website:', customer.website!),
                if (customer.email != null && customer.email!.isNotEmpty)
                  _buildInfoRow('Email:', customer.email!),
                if (customer.maSoThue != null && customer.maSoThue!.isNotEmpty)
                  _buildInfoRow('Mã số thuế:', customer.maSoThue!),
                if (customer.giamSat != null && customer.giamSat!.isNotEmpty)
                  _buildInfoRow('Giám sát:', customer.giamSat!),
                if (customer.qldv != null && customer.qldv!.isNotEmpty)
                  _buildInfoRow('QLDV:', customer.qldv!),
                if (customer.ghiChu != null && customer.ghiChu!.isNotEmpty)
                  _buildInfoRow('Ghi chú:', customer.ghiChu!),
                if (customer.ngayCapNhatCuoi != null)
                  _buildInfoRow('Cập nhật:', DateFormat('dd/MM/yyyy').format(customer.ngayCapNhatCuoi!)),
                
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (customer.soDienThoai != null && customer.soDienThoai!.isNotEmpty)
                      ElevatedButton.icon(
                        icon: Icon(Icons.call),
                        label: Text('Gọi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                        ),
                        onPressed: () => _callCustomer(customer.soDienThoai!),
                      ),
                    ElevatedButton.icon(
                      icon: Icon(Icons.directions),
                      label: Text('Chỉ đường'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                      ),
                      onPressed: () => _openMaps(customer.diaChi ?? ''),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isPhone = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: isPhone
                ? GestureDetector(
                    onTap: () => _callCustomer(value),
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(fontSize: 14),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMaps(String address) async {
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không có địa chỉ để mở bản đồ'))
      );
      return;
    }
    
    final encodedAddress = Uri.encodeComponent(address);
    final mapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');
    
    if (await url_launcher.canLaunchUrl(mapsUrl)) {
      await url_launcher.launchUrl(mapsUrl, mode: url_launcher.LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể mở bản đồ cho địa chỉ này'))
      );
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Lọc khách hàng'),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFilterOption('Tất cả'),
                Divider(),
                Text('Phân loại:', style: TextStyle(fontWeight: FontWeight.bold)),
                ..._getUniqueValues('phanLoai').map((value) => _buildFilterOption(value)),
                SizedBox(height: 8),
                Text('Vùng miền:', style: TextStyle(fontWeight: FontWeight.bold)),
                ..._getUniqueValues('vungMien').map((value) => _buildFilterOption(value)),
                SizedBox(height: 8),
                Text('Loại hình:', style: TextStyle(fontWeight: FontWeight.bold)),
                ..._getUniqueValues('loaiHinh').map((value) => _buildFilterOption(value)),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Đóng'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  List<String> _getUniqueValues(String field) {
    final Set<String> values = Set<String>();
    
    for (var customer in _khachHangList) {
      String? value;
      
      switch (field) {
        case 'phanLoai':
          value = customer.phanLoai;
          break;
        case 'vungMien':
          value = customer.vungMien;
          break;
        case 'loaiHinh':
          value = customer.loaiHinh;
          break;
      }
      
      if (value != null && value.isNotEmpty) {
        values.add(value);
      }
    }
    
    return values.toList()..sort();
  }

  Widget _buildFilterOption(String value) {
    return RadioListTile<String>(
      title: Text(value),
      value: value,
      groupValue: _filterBy,
      onChanged: (newValue) {
        Navigator.pop(context);
        if (newValue != null) {
          _updateFilter(newValue);
        }
      },
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Sắp xếp theo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSortOption('tenDuAn', 'Tên dự án'),
              _buildSortOption('vungMien', 'Vùng miền'),
              _buildSortOption('phanLoai', 'Phân loại'),
              _buildSortOption('ngayCapNhatCuoi', 'Ngày cập nhật'),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Đóng'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSortOption(String field, String label) {
    return RadioListTile<String>(
      title: Row(
        children: [
          Text(label),
          SizedBox(width: 8),
          if (_sortBy == field)
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
            ),
        ],
      ),
      value: field,
      groupValue: _sortBy,
      onChanged: (newValue) {
        Navigator.pop(context);
        if (newValue != null) {
          _updateSort(newValue);
        }
      },
    );
  }
}
class AddKhachHangScreen extends StatefulWidget {
  @override
  _AddKhachHangScreenState createState() => _AddKhachHangScreenState();
}

class _AddKhachHangScreenState extends State<AddKhachHangScreen> 
    with SingleTickerProviderStateMixin { 
  final _formKey = GlobalKey<FormState>();
  final _contactFormKey = GlobalKey<FormState>();
  
  // Customer data
  Map<String, dynamic> newCustomer = {};
  
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
  
  // Dropdown values
  String? selectedDanhDau = '';
  String? selectedVungMien;
  String selectedLoaiHinh = 'Dự án';
  String? selectedLoaiCongTrinh;
  String? selectedTrangThaiHopDong;
  String? selectedLoaiMuaHang;
  String? selectedKenhTiepCan;
  
  // App theme colors
  final Color appBarTop = Color(0xFF024965);
  final Color appBarBottom = Color(0xFF03a6cf);
  final Color buttonColor = Color(0xFF33a7ce);
  
  // Tab controller for switching between customer and contact info
  late TabController _tabController;
  
  // Loading state for API calls
  bool _isSubmitting = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Set initial values
    final userCredentials = Provider.of<UserCredentials>(context, listen: false);
    final username = userCredentials.username;
    
    // Generate new UUID
    newCustomer['uid'] = _generateUuid();
    newCustomer['nguoiDung'] = username;
    
    // Set phanLoai based on username
    if (thuongMaiUsers.contains(username)) {
      newCustomer['phanLoai'] = 'Thương mại';
    } else {
      newCustomer['phanLoai'] = 'Dịch vụ';
    }
    
    // Set default values
    newCustomer['loaiHinh'] = 'Dự án';
    
    // Set current datetime for creation and update fields
    final now = DateTime.now();
    String formattedDateTime = _formatDateTimeForDb(now);
    newCustomer['ngayCapNhatCuoi'] = formattedDateTime;
    newCustomer['ngayKhoiTao'] = formattedDateTime;
  }
  
  @override
  void dispose() {
    // Dispose all controllers
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
    
    // Dispose contact controllers
    hoTenController.dispose();
    chucDanhController.dispose();
    soDienThoaiContactController.dispose();
    emailContactController.dispose();
    
    // Dispose tab controller
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
    // Format to MariaDB datetime format (YYYY-MM-DD HH:MM:SS)
    return "${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)} "
           "${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}:${_twoDigits(dateTime.second)}";
  }
  
  String _twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }
  
  void _saveCustomerForm() {
    if (_formKey.currentState!.validate()) {
      // Update customer data with form values
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
      
      // Add dropdown values
      newCustomer['danhDau'] = selectedDanhDau;
      newCustomer['vungMien'] = selectedVungMien;
      newCustomer['loaiCongTrinh'] = selectedLoaiCongTrinh;
      newCustomer['trangThaiHopDong'] = selectedTrangThaiHopDong;
      newCustomer['loaiMuaHang'] = selectedLoaiMuaHang;
      newCustomer['kenhTiepCan'] = selectedKenhTiepCan;
      
      // Move to contacts tab
      _tabController.animateTo(1);
      
      // If it's a "Dịch vụ" type customer and no contacts yet, offer to create predefined subjects
      if (newCustomer['phanLoai'] == 'Dịch vụ' && contacts.isEmpty) {
        _offerPredefinedSubjects();
      }
    }
  }
  
  void _offerPredefinedSubjects() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tạo danh mục (DỊCH VỤ))'),
        content: Text(
          'Bạn có muốn tạo các danh mục chủ đề mặc định cho khách hàng dịch vụ không?'
        ),
        actions: [
          TextButton(
            child: Text('Không'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Có, tạo danh mục'),
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
    // Clear form fields
    hoTenController.clear();
    chucDanhController.clear();
    soDienThoaiContactController.clear();
    emailContactController.clear();
    selectedGioiTinh = null;
    selectedNguonGoc = null;
    
    // Reset current contact
    setState(() {
      currentContact = null;
    });
    
    // Show contact form dialog
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
                // Họ tên
                _buildTextField(
                  'Họ tên *',
                  hoTenController,
                  validator: (value) => value == null || value.isEmpty ? 'Vui lòng nhập họ tên' : null,
                ),
                
                // Giới tính
                _buildDropdownField(
                  'Giới tính',
                  ['Nam', 'Nữ'],
                  selectedGioiTinh,
                  (value) => setState(() => selectedGioiTinh = value),
                ),
                
                // Chức danh
                _buildTextField('Chức danh', chucDanhController),
                
                // Số điện thoại
                _buildTextField(
                  'Số điện thoại', 
                  soDienThoaiContactController,
                  keyboardType: TextInputType.phone
                ),
                
                // Email
                _buildTextField(
                  'Email', 
                  emailContactController,
                  keyboardType: TextInputType.emailAddress
                ),
                
                // Nguồn gốc
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
            child: Text('Lưu'),
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
    
    // Set form values
    hoTenController.text = contact.hoTen;
    chucDanhController.text = contact.chucDanh;
    soDienThoaiContactController.text = contact.soDienThoai;
    emailContactController.text = contact.email;
    
    setState(() {
      selectedGioiTinh = contact.gioiTinh.isNotEmpty ? contact.gioiTinh : null;
      selectedNguonGoc = contact.nguonGoc.isNotEmpty ? contact.nguonGoc : null;
      currentContact = contact;
    });
    
    // Show contact form dialog
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
                // Họ tên
                _buildTextField(
                  'Họ tên *',
                  hoTenController,
                  validator: (value) => value == null || value.isEmpty ? 'Vui lòng nhập họ tên' : null,
                ),
                
                // Giới tính
                _buildDropdownField(
                  'Giới tính',
                  ['Nam', 'Nữ'],
                  selectedGioiTinh,
                  (value) => setState(() => selectedGioiTinh = value),
                ),
                
                // Chức danh
                _buildTextField('Chức danh', chucDanhController),
                
                // Số điện thoại
                _buildTextField(
                  'Số điện thoại', 
                  soDienThoaiContactController,
                  keyboardType: TextInputType.phone
                ),
                
                // Email
                _buildTextField(
                  'Email', 
                  emailContactController,
                  keyboardType: TextInputType.emailAddress
                ),
                
                // Nguồn gốc
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
            child: Text('Cập nhật'),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
            ),
            onPressed: () {
              if (_contactFormKey.currentState!.validate()) {
                final now = _formatDateTimeForDb(DateTime.now());
                
                setState(() {
                  // Update the contact fields
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
    // Final validation
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
      // Submit khachhang record
      final customerResponse = await _submitCustomer();
      
      // Submit khachhangcontact records
      final contactResponses = await _submitContacts();
      
      // Show recap and success message
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
    final String endpoint = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelkhachhangmoi';
    
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
        'message': 'Dữ liệu khách hàng đã được gửi thành công',
        'response': response.body,
      };
    } else {
      throw Exception('Failed to submit customer data: ${response.statusCode}, ${response.body}');
    }
  }
  
  Future<List<Map<String, dynamic>>> _submitContacts() async {
    final String endpoint = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelcontactmoi';
    List<Map<String, dynamic>> results = [];
    
    for (var contact in contacts) {
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
          ? 'Thành công' 
          : 'Lỗi: ${response.statusCode}',
        'response': response.body,
      });
    }
    
    return results;
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
              // Customer result
              Text(
                'Khách hàng: ${customerResult['success'] ? '✅ Thành công' : '❌ Thất bại'}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(customerResult['message']),
              SizedBox(height: 16),
              
              // Contact results
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
            child: Text('Hoàn tất'),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
            ),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, true); // Return to customer list with success indicator
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
          title: Text('Thêm khách hàng mới'),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
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
                    // UID field (non-editable)
                    _buildInfoField('UID (tự động)', newCustomer['uid'] ?? '', enabled: false),
                    SizedBox(height: 16),
                    
                    // Người dùng (username - non-editable)
                    _buildInfoField('Người dùng', newCustomer['nguoiDung'] ?? '', enabled: false),
                    SizedBox(height: 16),
                    
                    // Đánh dấu dropdown
                    _buildDropdownField(
                      'Đánh dấu',
                      ['', '1'],
                      selectedDanhDau,
                      (value) => setState(() => selectedDanhDau = value),
                    ),
                    
                    // Vùng miền dropdown
                    _buildDropdownField(
                      'Vùng miền *',
                      ['Bắc', 'Trung', 'Nam'],
                      selectedVungMien,
                      (value) => setState(() => selectedVungMien = value),
                      validator: (value) => value == null ? 'Vui lòng chọn vùng miền' : null,
                    ),
                    
                    // Phân loại (non-editable)
                    _buildInfoField('Phân loại', newCustomer['phanLoai'] ?? '', enabled: false),
                    SizedBox(height: 16),
                    
                    // Loại hình (non-editable)
                    _buildInfoField('Loại hình', selectedLoaiHinh, enabled: false),
                    SizedBox(height: 16),
                    
                    // Loại công trình dropdown
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
                    
                    // Trạng thái hợp đồng dropdown
                    _buildDropdownField(
                      'Trạng thái hợp đồng *',
                      ['Tiếp cận', 'Quan tâm', 'Báo giá', 'Đã ký', 'Dừng', 'Thất bại'],
                      selectedTrangThaiHopDong,
                      (value) => setState(() => selectedTrangThaiHopDong = value),
                      validator: (value) => value == null ? 'Vui lòng chọn trạng thái hợp đồng' : null,
                    ),
                    
                    // Tên dự án (with warning)
                    _buildTextField(
                      'Tên dự án *',
                      tenDuAnController,
                      validator: (value) => value == null || value.isEmpty ? 'Vui lòng nhập tên dự án' : null,
                      helperText: 'Lưu ý: Tên dự án không thể thay đổi sau khi lưu. Hãy kiểm tra kỹ trước khi nhập.',
                      onEditingComplete: () {
                        // Show confirmation dialog when user completes editing
                        if (tenDuAnController.text.isNotEmpty) {
                          _showTenDuAnConfirmDialog();
                        }
                      },
                    ),
                    
                    // Ghi chú
                    _buildTextField('Ghi chú', ghiChuController, maxLines: 3),
                    
                    // Địa chỉ
                    _buildTextField('Địa chỉ', diaChiController),
                    
                    // Mã số thuế
                    _buildTextField('Mã số thuế', maSoThueController),
                    
                    // Số điện thoại
                    _buildTextField(
                      'Số điện thoại', 
                      soDienThoaiController,
                      keyboardType: TextInputType.phone
                    ),
                    
                    // Fax
                    _buildTextField('Fax', faxController),
                    
                    // Website
                    _buildTextField('Website', websiteController),
                    
                    // Email
                    _buildTextField(
                      'Email', 
                      emailController,
                      keyboardType: TextInputType.emailAddress
                    ),
                    
                    // Số tài khoản
                    _buildTextField('Số tài khoản', soTaiKhoanController),
                    
                    // Ngân hàng
                    _buildTextField('Ngân hàng', nganHangController),
                    
                    // Loại mua hàng dropdown
                    _buildDropdownField(
                      'Loại mua hàng',
                      ['C1 Khách hàng mở mới', 'C1 Khách dự án', 'C1 Khách chăm sóc lại', 'C2 Khách truyền thống'],
                      selectedLoaiMuaHang,
                      (value) => setState(() => selectedLoaiMuaHang = value),
                    ),
                    
                    // Tỉnh thành
                    _buildTextField('Tỉnh thành', tinhThanhController),
                    
                    // Quận huyện
                    _buildTextField('Quận huyện', quanHuyenController),
                    
                    // Phường xã
                    _buildTextField('Phường xã', phuongXaController),
                    
                    // Kênh tiếp cận dropdown
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
                    
                    // Dự kiến triển khai
                    _buildTextField('Dự kiến triển khai', duKienTrienKhaiController),
                    
                    // Tiềm năng DVTM
                    _buildTextField('Tiềm năng DVTM', tiemNangDVTMController),
                    
                    // Yêu cầu nhân sự
                    _buildTextField('Yêu cầu nhân sự', yeuCauNhanSuController),
                    
                    // Cách thức tuyển
                    _buildTextField('Cách thức tuyển', cachThucTuyenController),
                    
                    // Mức lương tuyển
                    _buildTextField('Mức lương tuyển', mucLuongTuyenController),
                    
                    // Lương BP
                    _buildTextField('Lương BP', luongBPController),
                    
                    SizedBox(height: 24),
                    
                    // Save and proceed button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _saveCustomerForm,
                      child: Text(
                        'Lưu và tiếp tục',
                        style: TextStyle(fontSize: 16),
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
                    // Contacts list
                    Expanded(
                      child: _buildContactsList(),
                    ),
                    
                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          // Add predefined subjects
                          if (newCustomer['phanLoai'] == 'Dịch vụ')
                            Expanded(
                              flex: 1,
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.list),
                                label: Text('Tạo danh mục'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber[700],
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: contacts.isEmpty ? _offerPredefinedSubjects : null,
                              ),
                            ),
                          
                          SizedBox(width: 8),
                          
                          // Add new contact
                          Expanded(
                            flex: 1,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.person_add),
                              label: Text('Thêm liên hệ'),
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
                    
                    // Submit button
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
                                  'Đang gửi dữ liệu...',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            )
                          : Text(
                              'Gửi dữ liệu lên server',
                              style: TextStyle(fontSize: 16),
                            ),
                      ),
                    ),
                  ],
                ),
                
                // Loading overlay
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
            value: selectedValue,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: items.map((String value) {
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
  String boPhan; // references KhachHang uid
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

