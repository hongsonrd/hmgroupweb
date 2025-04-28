import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'dart:async';
import 'dart:math';

class HSDSHangScreen extends StatefulWidget {
  const HSDSHangScreen({Key? key}) : super(key: key);

  @override
  _HSDSHangScreenState createState() => _HSDSHangScreenState();
}

class _HSDSHangScreenState extends State<HSDSHangScreen> with SingleTickerProviderStateMixin {
  final DBHelper _dbHelper = DBHelper();
  late TabController _tabController;
  
  // Danh sách hàng tab variables
  List<DSHangModel> _allDSHang = [];
  List<DSHangModel> _filteredDSHang = [];
  bool _isLoadingDSHang = true;
  String _searchQueryDSHang = '';
  
  // Tồn kho tab variables
  List<TonKhoModel> _allTonKho = [];
  List<TonKhoModel> _filteredTonKho = [];
  bool _isLoadingTonKho = true;
  String _searchQueryTonKho = '';
  List<String> _warehouseList = [];
  String? _selectedWarehouse;
  
  // Filter values for DSHang tab
  String? _selectedNhaCungCap;
  String? _selectedThuongHieu;
  String? _selectedTrangThai;
  String? _selectedThoiHan;
  
  // Lists for filter dropdowns
  List<String> _nhaCungCapList = [];
  List<String> _thuongHieuList = [];
  List<String> _trangThaiList = ['Đang kinh doanh', 'Ngừng kinh doanh', 'Hết hàng'];
  List<String> _thoiHanList = ['Có thời hạn', 'Không thời hạn'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadDSHangData();
  }

  void _handleTabChange() {
    if (_tabController.index == 1 && _isLoadingTonKho) {
      _loadTonKhoData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDSHangData() async {
    setState(() {
      _isLoadingDSHang = true;
    });

    try {
      final dshangList = await _dbHelper.getAllDSHang();
      print("Loaded ${dshangList.length} DSHang items from database");
      
      if (dshangList.isNotEmpty) {
        // Print a few records for debugging
        for (int i = 0; i < min(5, dshangList.length); i++) {
          print("DSHang item $i - UID: ${dshangList[i].uid}, tenSanPham: ${dshangList[i].tenSanPham}");
        }
      }
      
      // Extract unique supplier and brand values for filters
      final nhaCungCapSet = <String>{};
      final thuongHieuSet = <String>{};
      
      for (var item in dshangList) {
        if (item.nhaCungCap != null && item.nhaCungCap!.isNotEmpty) {
          nhaCungCapSet.add(item.nhaCungCap!);
        }
        if (item.thuongHieu != null && item.thuongHieu!.isNotEmpty) {
          thuongHieuSet.add(item.thuongHieu!);
        }
      }
      
      setState(() {
        _allDSHang = dshangList;
        _applyDSHangFilters();
        _nhaCungCapList = nhaCungCapSet.toList()..sort();
        _thuongHieuList = thuongHieuSet.toList()..sort();
        _isLoadingDSHang = false;
      });
    } catch (e) {
      print('Error loading DSHang data: $e');
      setState(() {
        _isLoadingDSHang = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải dữ liệu: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadTonKhoData() async {
    setState(() {
      _isLoadingTonKho = true;
    });

    try {
      final tonKhoList = await _dbHelper.getAllTonKho();
      print("Loaded ${tonKhoList.length} TonKho items from database");
      
      // Extract unique warehouse IDs for filters
      final warehouseSet = <String>{};
      for (var item in tonKhoList) {
        if (item.khoHangID != null && item.khoHangID!.isNotEmpty) {
          warehouseSet.add(item.khoHangID!);
        }
      }
      
      setState(() {
        _allTonKho = tonKhoList;
        _applyTonKhoFilters();
        _warehouseList = warehouseSet.toList()..sort();
        _isLoadingTonKho = false;
      });
    } catch (e) {
      print('Error loading TonKho data: $e');
      setState(() {
        _isLoadingTonKho = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải dữ liệu tồn kho: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _applyDSHangFilters() {
    setState(() {
      _filteredDSHang = _allDSHang.where((item) {
        // Apply search filter
        final matchesSearch = _searchQueryDSHang.isEmpty ||
            (item.tenSanPham?.toLowerCase().contains(_searchQueryDSHang.toLowerCase()) ?? false) ||
            (item.sku?.toLowerCase().contains(_searchQueryDSHang.toLowerCase()) ?? false) ||
            (item.maNhapKho?.toLowerCase().contains(_searchQueryDSHang.toLowerCase()) ?? false);
        
        // Apply supplier filter
        final matchesNhaCungCap = _selectedNhaCungCap == null ||
            item.nhaCungCap == _selectedNhaCungCap;
        
        // Apply brand filter
        final matchesThuongHieu = _selectedThuongHieu == null ||
            item.thuongHieu == _selectedThuongHieu;
        
        // Apply status filter (simplified for demonstration)
        bool matchesTrangThai = true;
        if (_selectedTrangThai != null) {
          // This is a simplification - you would need to map your actual status values
          if (_selectedTrangThai == 'Đang kinh doanh') {
            matchesTrangThai = true; // Replace with actual condition
          } else if (_selectedTrangThai == 'Ngừng kinh doanh') {
            matchesTrangThai = false; // Replace with actual condition
          } else if (_selectedTrangThai == 'Hết hàng') {
            matchesTrangThai = false; // Replace with actual condition
          }
        }
        
        // Apply expiration filter
        bool matchesThoiHan = true;
        if (_selectedThoiHan != null) {
          if (_selectedThoiHan == 'Có thời hạn') {
            matchesThoiHan = item.coThoiHan == true;
          } else if (_selectedThoiHan == 'Không thời hạn') {
            matchesThoiHan = item.coThoiHan == false;
          }
        }
        
        return matchesSearch && matchesNhaCungCap && matchesThuongHieu && 
               matchesTrangThai && matchesThoiHan;
      }).toList();
    });
  }

  void _applyTonKhoFilters() {
    setState(() {
      _filteredTonKho = _allTonKho.where((item) {
        // Apply search filter
        bool matchesSearch = true;
        if (_searchQueryTonKho.isNotEmpty) {
          // Get product details to search by product name
          DSHangModel? product = _getProductById(item.maHangID);
          matchesSearch = item.maHangID?.toLowerCase().contains(_searchQueryTonKho.toLowerCase()) ?? false ||
                         (product?.tenSanPham?.toLowerCase().contains(_searchQueryTonKho.toLowerCase()) ?? false);
        }
        
        // Apply warehouse filter
        final matchesWarehouse = _selectedWarehouse == null ||
            item.khoHangID == _selectedWarehouse;
        
        return matchesSearch && matchesWarehouse;
      }).toList();
      
      // Sort by lowest stock first
      _filteredTonKho.sort((a, b) => (a.soLuongHienTai ?? 0).compareTo(b.soLuongHienTai ?? 0));
    });
  }

  // Helper method to get product details by ID
  DSHangModel? _getProductById(String? productId) {
    if (productId == null) return null;
    try {
      return _allDSHang.firstWhere((element) => element.uid == productId);
    } catch (e) {
      return null;
    }
  }

  void _resetDSHangFilters() {
    setState(() {
      _searchQueryDSHang = '';
      _selectedNhaCungCap = null;
      _selectedThuongHieu = null;
      _selectedTrangThai = null;
      _selectedThoiHan = null;
      _applyDSHangFilters();
    });
  }

  void _resetTonKhoFilters() {
    setState(() {
      _searchQueryTonKho = '';
      _selectedWarehouse = null;
      _applyTonKhoFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Colors with hex values
    final Color appBarTop = Color(0xFF534b0d);
    final Color appBarBottom = Color(0xFFb2a41f);
    final Color tabBarColor = Color(0xFF5a530f);
    final Color buttonColor = Color(0xFF837826);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Hàng & Tồn kho', style: TextStyle(color: Colors.white),),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [appBarTop, appBarBottom],
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          tabs: [
            Tab(text: 'Danh sách hàng'),
            Tab(text: 'Tồn kho'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white,),
            onPressed: () {
              _tabController.index == 0 ? _loadDSHangData() : _loadTonKhoData();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Danh sách hàng
          _buildDanhSachHangTab(),
          
          // Tab 2: Tồn kho
          _buildTonKhoTab(),
        ],
      ),
    );
  }

  Color _getColorFromName(String color) {
    final colorName = color.toLowerCase();
    if (colorName.contains('đỏ')) return Colors.red;
    if (colorName.contains('xanh') && colorName.contains('dương')) return Colors.blue;
    if (colorName.contains('xanh') && colorName.contains('lá')) return Colors.green;
    if (colorName.contains('xanh')) return Colors.blue;
    if (colorName.contains('vàng')) return Colors.yellow;
    if (colorName.contains('cam')) return Colors.orange;
    if (colorName.contains('tím')) return Colors.purple;
    if (colorName.contains('hồng')) return Colors.pink;
    if (colorName.contains('nâu')) return Colors.brown;
    if (colorName.contains('đen')) return Colors.black;
    if (colorName.contains('trắng')) return Colors.white;
    if (colorName.contains('xám')) return Colors.grey;
    // Default color
    return Colors.grey.shade300;
  }

  Widget _buildDanhSachHangTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Tìm kiếm tên sản phẩm, mã hàng...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              _searchQueryDSHang = value;
              _applyDSHangFilters();
            },
          ),
        ),
        
        // Filter section
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Brand filter
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: DropdownButton<String>(
                        hint: Text('Thương hiệu'),
                        value: _selectedThuongHieu,
                        items: [null, ..._thuongHieuList].map((value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value ?? 'Tất cả thương hiệu'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedThuongHieu = value;
                            _applyDSHangFilters();
                          });
                        },
                      ),
                    ),
                    
                    // Supplier filter
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: DropdownButton<String>(
                        hint: Text('Nhà cung cấp'),
                        value: _selectedNhaCungCap,
                        items: [null, ..._nhaCungCapList].map((value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value ?? 'Tất cả nhà cung cấp'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedNhaCungCap = value;
                            _applyDSHangFilters();
                          });
                        },
                      ),
                    ),
                    
                    // Status filter
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: DropdownButton<String>(
                        hint: Text('Trạng thái'),
                        value: _selectedTrangThai,
                        items: [null, ..._trangThaiList].map((value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value ?? 'Tất cả trạng thái'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTrangThai = value;
                            _applyDSHangFilters();
                          });
                        },
                      ),
                    ),
                    
                    // Expiration filter
                    DropdownButton<String>(
                      hint: Text('Thời hạn'),
                      value: _selectedThoiHan,
                      items: [null, ..._thoiHanList].map((value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value ?? 'Tất cả loại hạn'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedThoiHan = value;
                          _applyDSHangFilters();
                        });
                      },
                    ),
                  ],
                ),
              ),
              
              // Reset filters button
              if (_selectedNhaCungCap != null || _selectedThuongHieu != null || 
                  _selectedTrangThai != null || _selectedThoiHan != null || _searchQueryDSHang.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextButton.icon(
                  icon: Icon(Icons.clear, size: 16),
                  label: Text('Xóa bộ lọc'),
                  onPressed: _resetDSHangFilters,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    backgroundColor: Colors.red.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        Divider(),
        
        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kết quả: ${_filteredDSHang.length} / ${_allDSHang.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'Cập nhật: ${DateFormat('HH:mm, dd/MM/yyyy').format(DateTime.now())}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        
        Divider(),
        
        // Product list
        Expanded(
          child: _isLoadingDSHang
              ? Center(child: CircularProgressIndicator())
              : _filteredDSHang.isEmpty
                  ? Center(
                      child: Text(
                        'Không tìm thấy sản phẩm',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredDSHang.length,
                      itemBuilder: (context, index) {
                        final item = _filteredDSHang[index];
                        return buildItemCard(item);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildTonKhoTab() {
    if (_isLoadingTonKho && _allTonKho.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }
    
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Tìm kiếm tên sản phẩm, mã hàng...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              _searchQueryTonKho = value;
              _applyTonKhoFilters();
            },
          ),
        ),
        
        // Filter section
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Warehouse filter
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: DropdownButton<String>(
                        hint: Text('Kho hàng'),
                        value: _selectedWarehouse,
                        items: [null, ..._warehouseList].map((value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value ?? 'Tất cả kho hàng'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedWarehouse = value;
                            _applyTonKhoFilters();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              // Reset filters button
              if (_selectedWarehouse != null || _searchQueryTonKho.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextButton.icon(
                  icon: Icon(Icons.clear, size: 16),
                  label: Text('Xóa bộ lọc'),
                  onPressed: _resetTonKhoFilters,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    backgroundColor: Colors.red.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        Divider(),
        
        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kết quả: ${_filteredTonKho.length} / ${_allTonKho.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'Cập nhật: ${DateFormat('HH:mm, dd/MM/yyyy').format(DateTime.now())}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        
        Divider(),
        
        // Ton kho list
        Expanded(
          child: _isLoadingTonKho
              ? Center(child: CircularProgressIndicator())
              : _filteredTonKho.isEmpty
                  ? Center(
                      child: Text(
                        'Không tìm thấy sản phẩm',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredTonKho.length,
                      itemBuilder: (context, index) {
                        final tonKhoItem = _filteredTonKho[index];
                        final productInfo = _getProductById(tonKhoItem.maHangID);
                        return buildTonKhoCard(tonKhoItem, productInfo);
                      },
                    ),
        ),
      ],
    );
  }

  Widget buildItemCard(DSHangModel item) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ListTile(
        title: Text(
          item.tenSanPham ?? 'Không có tên',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            // Show XuatXu instead of mã
            Text('Xuất xứ: ${item.xuatXu ?? 'Chưa có thông tin'}'),
            SizedBox(height: 2),
            Text('Phân loại: ${item.phanLoai1 ?? 'Chưa phân loại'}'),
          ],
        ),
        trailing: item.mauSac != null && item.mauSac!.isNotEmpty
            ? Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                  color: _getColorFromName(item.mauSac!),
                ),
              )
            : null,
        onTap: () => _showItemDetails(item),
      ),
    );
  }

  Widget buildTonKhoCard(TonKhoModel tonKhoItem, DSHangModel? productInfo) {
    // Determine color based on stock level
    Color stockLevelColor = Colors.green;
    if (tonKhoItem.soLuongHienTai == null || tonKhoItem.soLuongHienTai == 0) {
      stockLevelColor = Colors.red;
    } else if (tonKhoItem.soLuongHienTai! < (tonKhoItem.soLuongDuTru ?? 5)) {
      stockLevelColor = Colors.orange;
    }
    
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ListTile(
        title: Text(
          productInfo?.tenSanPham ?? 'Sản phẩm không xác định',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text('Mã hàng: ${tonKhoItem.maHangID ?? 'N/A'}'),
            SizedBox(height: 2),
            Text('Kho: ${tonKhoItem.khoHangID ?? 'Không xác định'}'),
          ],
        ),
        trailing: Container(
          width: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'SL: ${tonKhoItem.soLuongHienTai?.toString() ?? '0'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: stockLevelColor,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Dự trữ: ${tonKhoItem.soLuongDuTru?.toString() ?? 'N/A'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        onTap: () => _showTonKhoDetails(tonKhoItem, productInfo),
      ),
    );
  }

  // Method to display LoHang (batch) information for a product
  Future<void> _showTonKhoDetails(TonKhoModel tonKhoItem, DSHangModel? productInfo) async {
    setState(() {
      _isLoadingTonKho = true;
    });
    
    try {
      // Fetch batches for this product in this warehouse
      final batches = await _dbHelper.getLoHangForProduct(tonKhoItem.maHangID!, tonKhoItem.khoHangID!);
      
      // Sort batches by current quantity (lowest first)
      batches.sort((a, b) => (a.soLuongHienTai ?? 0).compareTo(b.soLuongHienTai ?? 0));
      
      setState(() {
        _isLoadingTonKho = false;
      });
      
      _showTonKhoDetailsBottomSheet(tonKhoItem, productInfo, batches);
    } catch (e) {
      print('Error loading batch data: $e');
      setState(() {
        _isLoadingTonKho = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải dữ liệu lô hàng: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _showTonKhoDetailsBottomSheet(TonKhoModel tonKhoItem, DSHangModel? productInfo, List<LoHangModel> batches) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: EdgeInsets.only(bottom: 16),
                    ),
                  ),
                  
                  // Product header
                  if (productInfo != null && productInfo.hinhAnh != null && productInfo.hinhAnh!.isNotEmpty)
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            productInfo.hinhAnh!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                             child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                           ),
                         ),
                       ),
                     ),
                   ),
                 
                 // Product name
                 Text(
                   productInfo?.tenSanPham ?? 'Sản phẩm không xác định',
                   style: TextStyle(
                     fontSize: 22,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
                 
                 SizedBox(height: 8),
                 
                 // Product code and SKU
                 Row(
                   children: [
                     Expanded(
                       child: Text(
                         'Mã: ${productInfo?.uid ?? 'N/A'}',
                         style: TextStyle(
                           color: Colors.grey[600],
                         ),
                       ),
                     ),
                     if (productInfo?.sku != null)
                       Text(
                         'SKU: ${productInfo!.sku}',
                         style: TextStyle(
                           color: Colors.grey[600],
                         ),
                       ),
                   ],
                 ),
                 
                 SizedBox(height: 16),
                 
                 // Inventory summary
                 Container(
                   padding: EdgeInsets.all(12),
                   decoration: BoxDecoration(
                     color: Colors.grey[100],
                     borderRadius: BorderRadius.circular(8),
                   ),
                   child: Column(
                     children: [
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text(
                             'Kho hàng:',
                             style: TextStyle(fontWeight: FontWeight.w500),
                           ),
                           Text(
                             tonKhoItem.khoHangID ?? 'Không xác định',
                             style: TextStyle(fontWeight: FontWeight.bold),
                           ),
                         ],
                       ),
                       SizedBox(height: 8),
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text(
                             'Số lượng hiện tại:',
                             style: TextStyle(fontWeight: FontWeight.w500),
                           ),
                           Text(
                             '${tonKhoItem.soLuongHienTai?.toString() ?? '0'}',
                             style: TextStyle(
                               fontWeight: FontWeight.bold,
                               fontSize: 18,
                               color: _getStockLevelColor(tonKhoItem),
                             ),
                           ),
                         ],
                       ),
                       SizedBox(height: 8),
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text(
                             'Dự trữ tối thiểu:',
                             style: TextStyle(fontWeight: FontWeight.w500),
                           ),
                           Text(
                             '${tonKhoItem.soLuongDuTru?.toString() ?? 'N/A'}',
                             style: TextStyle(fontWeight: FontWeight.w500),
                           ),
                         ],
                       ),
                       if (tonKhoItem.soLuongCanXuat != null) ...[
                         SizedBox(height: 8),
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Text(
                               'Cần xuất:',
                               style: TextStyle(fontWeight: FontWeight.w500),
                             ),
                             Text(
                               '${tonKhoItem.soLuongCanXuat}',
                               style: TextStyle(
                                 fontWeight: FontWeight.w500,
                                 color: Colors.orange,
                               ),
                             ),
                           ],
                         ),
                       ],
                     ],
                   ),
                 ),
                 
                 SizedBox(height: 24),
                 
                 // Batches section header
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text(
                       'Chi tiết lô hàng',
                       style: TextStyle(
                         fontSize: 18,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                     Text(
                       '${batches.length} lô',
                       style: TextStyle(
                         color: Colors.grey[600],
                         fontWeight: FontWeight.w500,
                       ),
                     ),
                   ],
                 ),
                 
                 SizedBox(height: 12),
                 
                 // No batches message
                 if (batches.isEmpty)
                   Container(
                     padding: EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       color: Colors.grey[100],
                       borderRadius: BorderRadius.circular(8),
                     ),
                     child: Center(
                       child: Text(
                         'Không có lô hàng nào',
                         style: TextStyle(
                           color: Colors.grey[600],
                           fontStyle: FontStyle.italic,
                         ),
                       ),
                     ),
                   ),
                 
                 // Batch list
                 ...batches.map((batch) => _buildBatchItem(batch)),
                 
                 SizedBox(height: 32),
               ],
             ),
           );
         },
       );
     },
   );
 }
 
 Color _getStockLevelColor(TonKhoModel tonKhoItem) {
   if (tonKhoItem.soLuongHienTai == null || tonKhoItem.soLuongHienTai == 0) {
     return Colors.red;
   } else if (tonKhoItem.soLuongHienTai! < (tonKhoItem.soLuongDuTru ?? 5)) {
     return Colors.orange;
   }
   return Colors.green;
 }
 
 Widget _buildBatchItem(LoHangModel batch) {
   // Format the dates
   final dateFormat = DateFormat('dd/MM/yyyy');
   final importDate = batch.ngayNhap != null 
       ? dateFormat.format(DateTime.parse(batch.ngayNhap!))
       : 'N/A';
   
   final updateDate = batch.ngayCapNhat != null 
       ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(batch.ngayCapNhat!))
       : 'N/A';
   
   // Determine if batch is expired or close to expiry
   Color expiryColor = Colors.black;
   bool isExpired = false;
   bool isCloseToExpiry = false;
   
   if (batch.hanSuDung != null) {
     final expiryDate = DateTime.parse(batch.ngayNhap!).add(Duration(days: batch.hanSuDung!));
     final now = DateTime.now();
     final daysToExpiry = expiryDate.difference(now).inDays;
     
     if (daysToExpiry < 0) {
       isExpired = true;
       expiryColor = Colors.red;
     } else if (daysToExpiry < 30) {
       isCloseToExpiry = true;
       expiryColor = Colors.orange;
     }
   }
   
   return Card(
     margin: EdgeInsets.symmetric(vertical: 6),
     elevation: 1,
     child: Padding(
       padding: EdgeInsets.all(12),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text(
                 'Lô: ${batch.loHangID ?? 'N/A'}',
                 style: TextStyle(
                   fontWeight: FontWeight.bold,
                 ),
               ),
               Container(
                 padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                 decoration: BoxDecoration(
                   color: _getBatchStatusColor(batch.trangThai),
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Text(
                   batch.trangThai ?? 'Không xác định',
                   style: TextStyle(
                     color: Colors.white,
                     fontSize: 12,
                     fontWeight: FontWeight.w500,
                   ),
                 ),
               ),
             ],
           ),
           SizedBox(height: 8),
           Row(
             children: [
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text('SL ban đầu: ${batch.soLuongBanDau ?? 'N/A'}'),
                     SizedBox(height: 4),
                     Text(
                       'SL hiện tại: ${batch.soLuongHienTai ?? '0'}',
                       style: TextStyle(
                         fontWeight: FontWeight.bold,
                         color: batch.soLuongHienTai == 0 ? Colors.red : Colors.black,
                       ),
                     ),
                   ],
                 ),
               ),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text('Ngày nhập: $importDate'),
                     SizedBox(height: 4),
                     if (batch.hanSuDung != null)
                       Text(
                         'Hạn SD: ${batch.hanSuDung} ngày',
                         style: TextStyle(color: expiryColor),
                       ),
                   ],
                 ),
               ),
             ],
           ),
           if (isExpired || isCloseToExpiry) ...[
             SizedBox(height: 8),
             Container(
               padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
               decoration: BoxDecoration(
                 color: isExpired ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(4),
                 border: Border.all(
                   color: isExpired ? Colors.red : Colors.orange,
                   width: 1,
                 ),
               ),
               child: Text(
                 isExpired ? 'Đã hết hạn' : 'Sắp hết hạn',
                 style: TextStyle(
                   color: isExpired ? Colors.red : Colors.orange,
                   fontWeight: FontWeight.w500,
                 ),
               ),
             ),
           ],
           SizedBox(height: 8),
           Text(
             'Cập nhật: $updateDate',
             style: TextStyle(
               fontSize: 11,
               color: Colors.grey[600],
               fontStyle: FontStyle.italic,
             ),
           ),
           if (batch.khuVucKhoID != null) ...[
             SizedBox(height: 4),
             Text(
               'Khu vực: ${batch.khuVucKhoID}',
               style: TextStyle(
                 fontSize: 11,
                 color: Colors.grey[600],
               ),
             ),
           ],
         ],
       ),
     ),
   );
 }
 
 Color _getBatchStatusColor(String? status) {
   if (status == null) return Colors.grey;
   
   switch (status.toLowerCase()) {
     case 'hoạt động':
     case 'active':
       return Colors.green;
     case 'đã xuất':
     case 'exported':
       return Colors.blue;
     case 'hết hàng':
     case 'out of stock':
       return Colors.red;
     case 'hết hạn':
     case 'expired':
       return Colors.purple;
     case 'chờ xuất':
     case 'pending':
       return Colors.orange;
     default:
       return Colors.grey;
   }
 }

 void _showItemDetails(DSHangModel item) {
   showModalBottomSheet(
     context: context,
     isScrollControlled: true,
     shape: RoundedRectangleBorder(
       borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
     ),
     builder: (context) {
       return DraggableScrollableSheet(
         initialChildSize: 0.8,
         maxChildSize: 0.95,
         minChildSize: 0.5,
         expand: false,
         builder: (_, scrollController) {
           return SingleChildScrollView(
             controller: scrollController,
             padding: EdgeInsets.all(16),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Center(
                   child: Container(
                     width: 40,
                     height: 5,
                     decoration: BoxDecoration(
                       color: Colors.grey.shade300,
                       borderRadius: BorderRadius.circular(8),
                     ),
                     margin: EdgeInsets.only(bottom: 16),
                   ),
                 ),
                 
                 // Header with image if available
                 if (item.hinhAnh != null && item.hinhAnh!.isNotEmpty)
                   Center(
                     child: Container(
                       width: 200,
                       height: 200,
                       margin: EdgeInsets.only(bottom: 16),
                       decoration: BoxDecoration(
                         border: Border.all(color: Colors.grey.shade300),
                         borderRadius: BorderRadius.circular(8),
                       ),
                       child: ClipRRect(
                         borderRadius: BorderRadius.circular(8),
                         child: Image.network(
                           item.hinhAnh!,
                           fit: BoxFit.cover,
                           errorBuilder: (_, __, ___) => Center(
                             child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                           ),
                         ),
                       ),
                     ),
                   ),
                 
                 // Product name
                 Text(
                   item.tenSanPham ?? 'Không có tên',
                   style: TextStyle(
                     fontSize: 22,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
                 
                 SizedBox(height: 16),
                 
                 // Basic info section
                 _buildInfoRow('Mã sản phẩm', item.uid),
                 _buildInfoRow('SKU', item.sku),
                 _buildInfoRow('Phân loại', item.phanLoai1),
                 _buildInfoRow('Màu sắc', item.mauSac),
                 _buildInfoRow('Chất liệu', item.chatLieu),
                 _buildInfoRow('Xuất xứ', item.xuatXu),
                 _buildInfoRow('Thương hiệu', item.thuongHieu),
                 
                 SizedBox(height: 16),
                 
                 // Specifications section
                 Text(
                   'Thông số kỹ thuật',
                   style: TextStyle(
                     fontSize: 18,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
                 SizedBox(height: 8),
                 _buildInfoRow('Kích thước', item.kichThuoc),
                 _buildInfoRow('Dung tích', item.dungTich),
                 _buildInfoRow('Khối lượng', item.khoiLuong),
                 _buildInfoRow('Quy cách đóng gói', item.quyCachDongGoi),
                 _buildInfoRow('Số lượng đóng gói', item.soLuongDongGoi),
                 _buildInfoRow('Kích thước đóng gói', item.kichThuocDongGoi),
                 _buildInfoRow('Đơn vị', item.donVi),
                 
                 SizedBox(height: 16),
                 
                 // Additional details section
                 Text(
                   'Thông tin bổ sung',
                   style: TextStyle(
                     fontSize: 18,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
                 SizedBox(height: 8),
                 _buildInfoRow('Công dụng', item.congDung),
                 _buildInfoRow('Nhà cung cấp', item.nhaCungCap),
                 _buildInfoRow('Hàng tiêu hao', item.hangTieuHao == 1 ? 'Có' : 'Không'),
                 _buildInfoRow('Có thời hạn', item.coThoiHan == 1 ? 'Có' : 'Không'),
                 _buildInfoRow('Thời hạn sử dụng', item.thoiHanSuDung),
                 
                 // Description if available
                 if (item.moTa != null && item.moTa!.isNotEmpty) ...[
                   SizedBox(height: 16),
                   Text(
                     'Mô tả',
                     style: TextStyle(
                       fontSize: 18,
                       fontWeight: FontWeight.bold,
                     ),
                   ),
                   SizedBox(height: 8),
                   Text(item.moTa!),
                 ],
                 
                 SizedBox(height: 32),
               ],
             ),
           );
         },
       );
     },
   );
 }

 Widget _buildInfoRow(String label, dynamic value) {
   // Skip if value is null or empty
   if (value == null || (value is String && value.isEmpty)) return SizedBox.shrink();
   
   return Padding(
     padding: const EdgeInsets.symmetric(vertical: 4),
     child: Row(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         SizedBox(
           width: 140,
           child: Text(
             '$label:',
             style: TextStyle(
               color: Colors.grey.shade700,
               fontWeight: FontWeight.w500,
             ),
           ),
         ),
         Expanded(
           child: Text(
             value.toString(),
             style: TextStyle(
               fontWeight: FontWeight.w500,
             ),
           ),
         ),
       ],
     ),
   );
 }
}