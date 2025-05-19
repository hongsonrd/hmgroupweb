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
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: buttonColor,
        child: Icon(Icons.refresh),
        onPressed: _refreshData,
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