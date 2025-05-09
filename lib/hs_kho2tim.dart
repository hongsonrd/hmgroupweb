import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'table_models.dart';
import 'db_helper.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:collection';

class ProductSearchScreen extends StatefulWidget {
  final DBHelper dbHelper;
  final String? khoHangID;

  const ProductSearchScreen({
    Key? key,
    required this.dbHelper,
    this.khoHangID,
  }) : super(key: key);

  @override
  _ProductSearchScreenState createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Search parameters
  String? _selectedBrand;
  String? _selectedProduct;
  String _searchQuery = '';
  String? _selectedStatus;
  
  // Data
  List<String> _brands = [];
  List<String> _products = [];
  List<String> _statuses = ['Tất cả', 'Còn hàng', 'Sắp hết', 'Hết hàng'];
  
  // Results
  List<Map<String, dynamic>> _searchResults = [];
  
  @override
  void initState() {
    super.initState();
    _loadBrands();
  }
  
  Future<void> _loadBrands() async {
  setState(() {
    _isLoading = true;
    _errorMessage = '';
  });
  
  try {
    // Get all brands from database
    print('Loading brands from database...');
    final brands = await widget.dbHelper.getAllBrands();
    print('Successfully loaded ${brands.length} brands');
    
    if (brands.isNotEmpty) {
      print('Sample brands: ${brands.take(5).join(', ')}...');
    } else {
      print('No brands found in database');
    }
    
    setState(() {
      _brands = brands;
      _isLoading = false;
      
      // Add "All brands" option
      _brands.insert(0, 'Tất cả thương hiệu');
      _selectedBrand = _brands[0];
      print('Selected brand: $_selectedBrand');
      
      // Also load products for the "All brands" option
      _loadProducts(_selectedBrand!);
    });
  } catch (e) {
    print('Error loading brands: $e');
    setState(() {
      _isLoading = false;
      _errorMessage = '';  // Clear error message to avoid blocking UI
      _brands = ['Tất cả thương hiệu'];  // Fallback
      _selectedBrand = _brands[0];
      _loadProducts(_selectedBrand!);
    });
  }
}

Future<void> _loadProducts(String brand) async {
  setState(() {
    _isLoading = true;
    _errorMessage = '';
    _selectedProduct = null;
  });
  
  try {
    List<String> products;
    
    // If "All brands" is selected
    if (brand == 'Tất cả thương hiệu') {
      print('Loading all products...');
      products = await widget.dbHelper.getAllProductNames();
      print('Successfully loaded ${products.length} products');
    } else {
      // Get products of the selected brand
      print('Loading products for brand: $brand');
      products = await widget.dbHelper.getProductNamesByBrand(brand);
      print('Successfully loaded ${products.length} products for brand $brand');
    }
    
    if (products.isNotEmpty) {
      print('Sample products: ${products.take(5).join(', ')}...');
    } else {
      print('No products found for the selected criteria');
    }
    
    setState(() {
      _products = products;
      _isLoading = false;
      
      // Add "All products" option
      _products.insert(0, 'Tất cả sản phẩm');
      _selectedProduct = _products[0];
      print('Selected product: $_selectedProduct');
    });
  } catch (e) {
    print('Error loading products: $e');
    setState(() {
      _isLoading = false;
      _errorMessage = '';  // Clear error message to avoid blocking UI
      _products = ['Tất cả sản phẩm'];  // Fallback
      _selectedProduct = _products[0];
    });
  }
}
  Future<void> _searchProducts() async {
  setState(() {
    _isLoading = true;
    _errorMessage = '';
    _searchResults = [];
  });
  
  try {
    // Check database tables first
    await widget.dbHelper.checkDatabaseTables();
    
    // Get all batches with their product and location info
    print('\n===== STARTING PRODUCT SEARCH =====');
    print('Selected filters:');
    print('- Brand: $_selectedBrand');
    print('- Product: $_selectedProduct');
    print('- Status: $_selectedStatus');
    print('- Search query: "$_searchQuery"');
    
    final allBatches = await widget.dbHelper.getFullBatchesInfo(widget.khoHangID ?? '');
    print('Fetched ${allBatches.length} batches to filter');
    
    // Apply filters
    final results = <Map<String, dynamic>>[];
    
    for (var result in allBatches) {
      final batch = result['batch'] as LoHangModel;
      final product = result['product'] as Map<String, dynamic>;
      
      // Debug the current batch/product being filtered
      print('\nFiltering batch: ${batch.loHangID}');
      print('- Product: ${product['tenSanPham']}');
      print('- Brand: ${product['thuongHieu']}');
      print('- Status: ${batch.trangThai}');
      
      // Brand filter
      if (_selectedBrand != 'Tất cả thương hiệu') {
        final thuongHieu = product['thuongHieu'];
        if (thuongHieu == null || thuongHieu != _selectedBrand) {
          print('SKIP: Brand does not match (${product['thuongHieu']} vs $_selectedBrand)');
          continue;
        }
      }
      
      // Product filter
      if (_selectedProduct != 'Tất cả sản phẩm') {
        final tenSanPham = product['tenSanPham'];
        if (tenSanPham == null || tenSanPham != _selectedProduct) {
          print('SKIP: Product does not match (${product['tenSanPham']} vs $_selectedProduct)');
          continue;
        }
      }
      
      // Status filter
      if (_selectedStatus != null && _selectedStatus != 'Tất cả') {
        if (batch.trangThai != _selectedStatus) {
          print('SKIP: Status does not match (${batch.trangThai} vs $_selectedStatus)');
          continue;
        }
      }
      
      // Search query filter (search in product name, ID, and description)
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final productName = (product['tenSanPham'] ?? '').toString().toLowerCase();
        final productID = (batch.maHangID ?? '').toLowerCase();
        final description = (product['moTa'] ?? '').toString().toLowerCase();
        
        if (!productName.contains(query) && 
            !productID.contains(query) && 
            !description.contains(query)) {
          print('SKIP: Search query not found in any field');
          continue;
        }
      }
      
      // Add to results
      print('PASSED all filters - adding to results');
      results.add(result);
    }
    
    print('\nSearch complete: Found ${results.length} matching results');
    
    setState(() {
      _searchResults = results;
      _isLoading = false;
    });
  } catch (e) {
    print('Error searching products: $e');
    setState(() {
      _isLoading = false;
      _errorMessage = 'Lỗi tìm kiếm: $e';
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bấm Tìm kiếm để bắt đầu:',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFD4AF37), // Gold
                Color(0xFF8B4513), // Brown
                Color(0xFFB8860B), // Dark gold
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)))
              : _buildBody(),
    );
  }
  
  Widget _buildBody() {
    return Column(
      children: [
        _buildSearchPanel(),
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Không có kết quả tìm kiếm',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Vui lòng thay đổi tiêu chí tìm kiếm',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    return _buildResultCard(_searchResults[index]);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildSearchPanel() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Color(0xFFF5DEB3).withOpacity(0.3),
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
          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Tìm kiếm sản phẩm...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFFD2B48C)),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          
          SizedBox(height: 16),
          
          // Filters
          Row(
            children: [
              // Brand dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thương hiệu:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFD2B48C)),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedBrand,
                            hint: Text('Chọn thương hiệu', style: TextStyle(fontSize: 12)),
                            style: TextStyle(fontSize: 12, color: Colors.black),
                            items: _brands.map((brand) {
                              return DropdownMenuItem<String>(
                                value: brand,
                                child: Text(brand),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedBrand = value;
                                });
                                _loadProducts(value);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(width: 12),
              
              // Product dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sản phẩm:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFD2B48C)),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedProduct,
                            hint: Text('Chọn sản phẩm', style: TextStyle(fontSize: 12)),
                            style: TextStyle(fontSize: 12, color: Colors.black),
                            items: _products.map((product) {
                              return DropdownMenuItem<String>(
                                value: product,
                                child: Text(
                                  product,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedProduct = value;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(width: 12),
              
              // Status dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trạng thái:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFD2B48C)),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedStatus ?? 'Tất cả',
                            hint: Text('Chọn trạng thái', style: TextStyle(fontSize: 12)),
                            style: TextStyle(fontSize: 12, color: Colors.black),
                            items: _statuses.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedStatus = value;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Search button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(Icons.search),
              label: Text('Tìm kiếm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFD4AF37),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _searchProducts,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResultCard(Map<String, dynamic> result) {
  final batch = result['batch'] as LoHangModel;
  final product = result['product'] as Map<String, dynamic>;
  final location = result['location'] as String;  // This will now contain the full location info
  
  final dateFormat = DateFormat('dd/MM/yyyy');
  final ngayNhap = batch.ngayNhap != null 
      ? dateFormat.format(DateTime.parse(batch.ngayNhap!))
      : 'N/A';
  
  final productName = product['tenSanPham'] ?? 'Không xác định';
  final brand = product['thuongHieu'] ?? 'Không xác định';
  
  // Determine status color
  Color statusColor = Colors.grey;
  if (batch.trangThai != null) {
    switch (batch.trangThai!.toLowerCase()) {
      case 'còn hàng':
        statusColor = Colors.green;
        break;
      case 'sắp hết':
        statusColor = Colors.orange;
        break;
      case 'hết hàng':
        statusColor = Colors.red;
        break;
    }
  }
  
  return Card(
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: InkWell(
      onTap: () {
        _showProductDetailsDialog(result);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name and status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    productName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    batch.trangThai ?? 'Không xác định',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 8),
            
            // Brand and batch info
            Row(
              children: [
                Icon(Icons.business, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  brand,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(width: 16),
                Icon(Icons.inventory_2, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  'Lô: ${batch.loHangID ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 4),
            
            // Quantity and date
            Row(
              children: [
                Icon(Icons.format_list_numbered, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  'SL: ${batch.soLuongHienTai?.toStringAsFixed(0) ?? 'N/A'} ${product['donVi'] ?? ''}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(width: 16),
                Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  'Nhập: $ngayNhap',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 8),
            
            // Location
            Container(
  width: double.infinity,
  padding: EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: Colors.grey.withOpacity(0.1),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: Colors.grey.withOpacity(0.3),
    ),
  ),
  child: Row(
    children: [
      Icon(Icons.location_on, color: Color(0xFFB8860B), size: 16),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          location,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
    ],
  ),
),
          ],
        ),
      ),
    ),
  );
}
  
  void _showProductDetailsDialog(Map<String, dynamic> result) {
    final batch = result['batch'] as LoHangModel;
    final product = result['product'] as Map<String, dynamic>;
    final location = result['location'] as String;
    
    final dateFormat = DateFormat('dd/MM/yyyy');
    final ngayNhap = batch.ngayNhap != null 
        ? dateFormat.format(DateTime.parse(batch.ngayNhap!))
        : 'N/A';
    final ngayCapNhat = batch.ngayCapNhat != null 
        ? dateFormat.format(DateTime.parse(batch.ngayCapNhat!))
        : 'N/A';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(16),
            width: double.infinity,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product['tenSanPham'] ?? 'Không xác định',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  
                  Divider(),
                  
                  // Product details section
                  Text(
                    'Thông tin sản phẩm',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB8860B),
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildInfoRow('Mã sản phẩm', batch.maHangID ?? 'N/A'),
                  _buildInfoRow('Thương hiệu', product['thuongHieu'] ?? 'N/A'),
                  _buildInfoRow('Phân loại', product['phanLoai1'] ?? 'N/A'),
                  _buildInfoRow('Xuất xứ', product['xuatXu'] ?? 'N/A'),
                  if (product['dungTich'] != null)
                    _buildInfoRow('Dung tích', product['dungTich']),
                  if (product['kichThuoc'] != null)
                    _buildInfoRow('Kích thước', product['kichThuoc']),
                  if (product['chatLieu'] != null)
                    _buildInfoRow('Chất liệu', product['chatLieu']),
                  if (product['mauSac'] != null)
                    _buildInfoRow('Màu sắc', product['mauSac']),
                  
                  SizedBox(height: 16),
                  
                  // Batch details section
                  Text(
                    'Thông tin lô hàng',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB8860B),
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildInfoRow('Mã lô', batch.loHangID ?? 'N/A'),
                  _buildInfoRow('Trạng thái', batch.trangThai ?? 'N/A'),
                  _buildInfoRow('Số lượng hiện tại', 
                      '${batch.soLuongHienTai?.toStringAsFixed(0) ?? 'N/A'} ${product['donVi'] ?? ''}'),
                  _buildInfoRow('Số lượng ban đầu', 
                      '${batch.soLuongBanDau?.toStringAsFixed(0) ?? 'N/A'} ${product['donVi'] ?? ''}'),
                  _buildInfoRow('Ngày nhập', ngayNhap),
                  _buildInfoRow('Ngày cập nhật', ngayCapNhat),
                  if (batch.hanSuDung != null)
                    _buildInfoRow('Hạn sử dụng', '${batch.hanSuDung} ngày'),
                  
                  SizedBox(height: 16),
                  
                  // Location details section
                  Text(
                    'Vị trí',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB8860B),
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: Color(0xFFB8860B)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Description if available
                  if (product['moTa'] != null && product['moTa'].toString().isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mô tả',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB8860B),
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            product['moTa'].toString(),
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  
                  SizedBox(height: 16),
                  
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (batch.khuVucKhoID != null)
                        TextButton.icon(
                          icon: Icon(Icons.location_searching),
                          label: Text('Xem vị trí'),
                          style: TextButton.styleFrom(
                            foregroundColor: Color(0xFFB8860B),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _navigateToLocation(batch);
                          },
                        ),
                      SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: Icon(Icons.check_circle_outline),
                        label: Text('OK'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFD4AF37),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  void _navigateToLocation(LoHangModel batch) {
    if (batch.khuVucKhoID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không tìm thấy thông tin vị trí'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Return the location information back to the HSKho2Screen
    Navigator.of(context).pop({
      'khuVucKhoID': batch.khuVucKhoID,
      'action': 'navigate',
    });
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
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