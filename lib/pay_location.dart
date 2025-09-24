import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PayLocationScreen extends StatefulWidget {
  final String username;
  final String userRole;
  final List<Map<String, dynamic>> locationData;

  const PayLocationScreen({
    Key? key,
    required this.username,
    required this.userRole,
    required this.locationData,
  }) : super(key: key);

  @override
  _PayLocationScreenState createState() => _PayLocationScreenState();
}

class _PayLocationScreenState extends State<PayLocationScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedPhanLoai = 'Tất cả';
  List<Map<String, dynamic>> _filteredData = [];
  bool _buttonsEnabled = true;
  static const String baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';

  @override
  void initState() {
    super.initState();
    _filteredData = List.from(widget.locationData);
    _searchController.addListener(_filterData);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterData() {
    final searchQuery = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredData = widget.locationData.where((location) {
        final nguoiDung = location['NguoiDung']?.toString().toLowerCase() ?? '';
        final phanLoai = location['PhanLoai']?.toString() ?? '';
        
        final matchesSearch = searchQuery.isEmpty || nguoiDung.contains(searchQuery);
        final matchesPhanLoai = _selectedPhanLoai == 'Tất cả' || phanLoai == _selectedPhanLoai;
        
        return matchesSearch && matchesPhanLoai;
      }).toList();
    });
  }

  bool _isValidLatLng(String value) {
    try {
      final parts = value.split(',');
      if (parts.length != 2) return false;
      
      final lat = double.parse(parts[0].trim());
      final lng = double.parse(parts[1].trim());
      
      return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
    } catch (e) {
      return false;
    }
  }

  void _showAddLocationDialog() {
    if (!_buttonsEnabled) return;
    
    final formKey = GlobalKey<FormState>();
    final controllers = {
      'NguoiDung': TextEditingController(),
      'TenGoi': TextEditingController(),
      'DinhVi': TextEditingController(),
    };
    String selectedPhanLoai = 'Chấm 24G';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm vị trí chấm công'),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['NguoiDung']!,
                        decoration: const InputDecoration(
                          labelText: 'Người dùng',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.isEmpty == true ? 'Trường này là bắt buộc' : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        value: selectedPhanLoai,
                        decoration: const InputDecoration(
                          labelText: 'Phân loại',
                          border: OutlineInputBorder(),
                        ),
                        items: ['Chấm 24G', 'Công thường'].map((value) {
                          return DropdownMenuItem(value: value, child: Text(value));
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedPhanLoai = value!;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['TenGoi']!,
                        decoration: const InputDecoration(
                          labelText: 'Tên gọi (Tên địa điểm)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.isEmpty == true ? 'Trường này là bắt buộc' : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['DinhVi']!,
                        decoration: const InputDecoration(
                          labelText: 'Định vị (lat,lng)',
                          hintText: 'Ví dụ: 21.0285,105.8542',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value?.isEmpty == true) {
                            return 'Trường này là bắt buộc';
                          }
                          if (!_isValidLatLng(value!)) {
                            return 'Định vị không hợp lệ. Định dạng: lat,lng';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  _createLocation(controllers, selectedPhanLoai);
                }
              },
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditLocationDialog(Map<String, dynamic> location) {
    if (!_buttonsEnabled) return;
    
    final formKey = GlobalKey<FormState>();
    final controllers = {
      'NguoiDung': TextEditingController(text: location['NguoiDung']?.toString() ?? ''),
      'TenGoi': TextEditingController(text: location['TenGoi']?.toString() ?? ''),
      'DinhVi': TextEditingController(text: location['DinhVi']?.toString() ?? ''),
    };
    String selectedPhanLoai = location['PhanLoai']?.toString() ?? 'Chấm 24G';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Chỉnh sửa vị trí'),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['NguoiDung']!,
                        decoration: const InputDecoration(
                          labelText: 'Người dùng',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.isEmpty == true ? 'Trường này là bắt buộc' : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        value: selectedPhanLoai,
                        decoration: const InputDecoration(
                          labelText: 'Phân loại',
                          border: OutlineInputBorder(),
                        ),
                        items: ['Chấm 24G', 'Công thường'].map((value) {
                          return DropdownMenuItem(value: value, child: Text(value));
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedPhanLoai = value!;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['TenGoi']!,
                        decoration: const InputDecoration(
                          labelText: 'Tên gọi (Tên địa điểm)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.isEmpty == true ? 'Trường này là bắt buộc' : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['DinhVi']!,
                        decoration: const InputDecoration(
                          labelText: 'Định vị (lat,lng)',
                          hintText: 'Ví dụ: 21.0285,105.8542',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value?.isEmpty == true) {
                            return 'Trường này là bắt buộc';
                          }
                          if (!_isValidLatLng(value!)) {
                            return 'Định vị không hợp lệ. Định dạng: lat,lng';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  _updateLocation(location['id']?.toString() ?? '', controllers, selectedPhanLoai);
                }
              },
              child: const Text('Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> location) {
    if (!_buttonsEnabled) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa vị trí: ${location['TenGoi']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteLocation(location['id']?.toString() ?? '');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _createLocation(Map<String, TextEditingController> controllers, String phanLoai) async {
    try {
      final data = {
        'NguoiDung': controllers['NguoiDung']!.text,
        'PhanLoai': phanLoai,
        'TenGoi': controllers['TenGoi']!.text,
        'DinhVi': controllers['DinhVi']!.text,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/payconglamtao'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo vị trí thành công')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi kết nối')),
      );
    }
  }

  Future<void> _updateLocation(String id, Map<String, TextEditingController> controllers, String phanLoai) async {
    try {
      final data = {
        'id': id,
        'NguoiDung': controllers['NguoiDung']!.text,
        'PhanLoai': phanLoai,
        'TenGoi': controllers['TenGoi']!.text,
        'DinhVi': controllers['DinhVi']!.text,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/payconglamcapnhat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật vị trí thành công')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi kết nối')),
      );
    }
  }

  Future<void> _deleteLocation(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/payconglamxoa/$id'),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa vị trí thành công')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi kết nối')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Vị trí chấm công - ${widget.username}'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          if ((widget.userRole == 'Admin' || widget.userRole == 'HR') && _buttonsEnabled)
            IconButton(
              icon: const Icon(Icons.add_location),
              onPressed: _showAddLocationDialog,
              tooltip: 'Thêm vị trí mới',
            ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 12),
            _buildFilterRow(),
            const SizedBox(height: 16),
            _buildDataTable(),
          ],
        ),
      ),
      floatingActionButton: ((widget.userRole == 'Admin' || widget.userRole == 'HR') && _buttonsEnabled)
          ? FloatingActionButton(
              onPressed: _showAddLocationDialog,
              backgroundColor: Colors.green[600],
              child: const Icon(Icons.add_location, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.green[600], size: 24),
              const SizedBox(width: 8),
              Text(
                'Thông tin vị trí chấm công',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('Người dùng', widget.username, Icons.person),
              ),
              Expanded(
                child: _buildInfoItem('Vai trò', widget.userRole, Icons.security),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('Tổng vị trí', '${widget.locationData.length}', Icons.pin_drop),
              ),
              Expanded(
                child: _buildInfoItem('Hiển thị', '${_filteredData.length}', Icons.visibility),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm theo tên người dùng...',
          prefixIcon: Icon(Icons.search, color: Colors.green[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPhanLoai,
          items: ['Tất cả', 'Chấm 24G', 'Công thường'].map((value) {
            return DropdownMenuItem(
              value: value,
              child: Text('Phân loại: $value', style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedPhanLoai = value!;
              _filterData();
            });
          },
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.map, color: Colors.green[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Danh sách vị trí chấm công',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[600],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_filteredData.length} vị trí',
                    style: TextStyle(
                      color: Colors.green[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _filteredData.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(0),
                      itemCount: _filteredData.length,
                      itemBuilder: (context, index) {
                        final location = _filteredData[index];
                        return _buildLocationItem(location, index);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Không có dữ liệu vị trí chấm công',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          if ((widget.userRole == 'Admin' || widget.userRole == 'HR') && _buttonsEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: _showAddLocationDialog,
                icon: const Icon(Icons.add_location),
                label: const Text('Thêm vị trí mới'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationItem(Map<String, dynamic> location, int index) {
    final nguoiDung = location['NguoiDung']?.toString() ?? 'N/A';
    final phanLoai = location['PhanLoai']?.toString() ?? 'N/A';
    final tenGoi = location['TenGoi']?.toString() ?? 'N/A';
    final dinhVi = location['DinhVi']?.toString() ?? 'N/A';
    final id = location['id']?.toString() ?? 'N/A';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getLocationTypeColor(phanLoai),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getLocationTypeIcon(phanLoai),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          '$nguoiDung - $tenGoi',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                dinhVi,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getLocationTypeColor(phanLoai).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getLocationTypeColor(phanLoai),
                  width: 1,
                ),
              ),
              child: Text(
                phanLoai,
                style: TextStyle(
                  color: _getLocationTypeColor(phanLoai),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: ((widget.userRole == 'Admin' || widget.userRole == 'HR') && _buttonsEnabled)
            ? PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16),
                        SizedBox(width: 8),
                        Text('Chỉnh sửa'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Xóa', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditLocationDialog(location);
                  } else if (value == 'delete') {
                    _showDeleteConfirmation(location);
                  }
                },
              )
            : null,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(2),
              },
              children: [
                _buildTableRow('ID', id),
                _buildTableRow('Người dùng', nguoiDung),
                _buildTableRow('Phân loại', phanLoai),
                _buildTableRow('Tên gọi', tenGoi),
                _buildTableRow('Định vị', dinhVi),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Color _getLocationTypeColor(String type) {
    switch (type) {
      case 'Chấm 24G':
        return Colors.blue;
      case 'Công thường':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getLocationTypeIcon(String type) {
    switch (type) {
      case 'Chấm 24G':
        return Icons.access_time;
      case 'Công thường':
        return Icons.work;
      default:
        return Icons.location_on;
    }
  }
}