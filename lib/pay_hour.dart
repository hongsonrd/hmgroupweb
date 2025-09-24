import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PayHourScreen extends StatefulWidget {
  final String username;
  final String userRole;
  final List<Map<String, dynamic>> hourData;

  const PayHourScreen({
    Key? key,
    required this.username,
    required this.userRole,
    required this.hourData,
  }) : super(key: key);

  @override
  _PayHourScreenState createState() => _PayHourScreenState();
}

class _PayHourScreenState extends State<PayHourScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedPhanLoai = 'Tất cả';
  List<Map<String, dynamic>> _filteredData = [];
  bool _buttonsEnabled = true;
  static const String baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';

  @override
  void initState() {
    super.initState();
    _filteredData = List.from(widget.hourData);
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
      _filteredData = widget.hourData.where((hour) {
        final nguoiDung = hour['NguoiDung']?.toString().toLowerCase() ?? '';
        final phanLoai = hour['PhanLoai']?.toString() ?? '';
        
        final matchesSearch = searchQuery.isEmpty || nguoiDung.contains(searchQuery);
        final matchesPhanLoai = _selectedPhanLoai == 'Tất cả' || phanLoai == _selectedPhanLoai;
        
        return matchesSearch && matchesPhanLoai;
      }).toList();
    });
  }

  int _calculateMinutes(String startTime, String endTime) {
    try {
      final start = TimeOfDay(
        hour: int.parse(startTime.split(':')[0]),
        minute: int.parse(startTime.split(':')[1]),
      );
      final end = TimeOfDay(
        hour: int.parse(endTime.split(':')[0]),
        minute: int.parse(endTime.split(':')[1]),
      );
      
      int startMinutes = start.hour * 60 + start.minute;
      int endMinutes = end.hour * 60 + end.minute;
      
      if (endMinutes < startMinutes) {
        endMinutes += 24 * 60;
      }
      
      return endMinutes - startMinutes;
    } catch (e) {
      return 0;
    }
  }

  void _showAddHourDialog() {
    if (!_buttonsEnabled) return;
    
    final formKey = GlobalKey<FormState>();
    final controllers = {
      'NguoiDung': TextEditingController(),
      'GioBatDau': TextEditingController(),
      'GioKetThuc': TextEditingController(),
      'SoCong': TextEditingController(text: '1'),
      'SoPhut': TextEditingController(),
    };
    String selectedPhanLoai = 'T2T6';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm quy định giờ làm'),
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
                        items: ['T2T6', 'T7', 'CN'].map((value) {
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
                        controller: controllers['GioBatDau']!,
                        decoration: const InputDecoration(
                          labelText: 'Giờ bắt đầu (HH:mm)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.isEmpty == true ? 'Trường này là bắt buộc' : null,
                        onChanged: (value) {
                          if (value.isNotEmpty && controllers['GioKetThuc']!.text.isNotEmpty) {
                            final minutes = _calculateMinutes(value, controllers['GioKetThuc']!.text);
                            controllers['SoPhut']!.text = minutes.toString();
                            setDialogState(() {});
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['GioKetThuc']!,
                        decoration: const InputDecoration(
                          labelText: 'Giờ kết thúc (HH:mm)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.isEmpty == true ? 'Trường này là bắt buộc' : null,
                        onChanged: (value) {
                          if (value.isNotEmpty && controllers['GioBatDau']!.text.isNotEmpty) {
                            final minutes = _calculateMinutes(controllers['GioBatDau']!.text, value);
                            controllers['SoPhut']!.text = minutes.toString();
                            setDialogState(() {});
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['SoCong']!,
                        decoration: const InputDecoration(
                          labelText: 'Số công',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) => value?.isEmpty == true ? 'Trường này là bắt buộc' : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['SoPhut']!,
                        decoration: const InputDecoration(
                          labelText: 'Số phút',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) => value?.isEmpty == true ? 'Trường này là bắt buộc' : null,
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
                  _createHour(controllers, selectedPhanLoai);
                }
              },
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditHourDialog(Map<String, dynamic> hour) {
    if (!_buttonsEnabled) return;
    
    final formKey = GlobalKey<FormState>();
    final controllers = {
      'NguoiDung': TextEditingController(text: hour['NguoiDung']?.toString() ?? ''),
      'GioBatDau': TextEditingController(text: hour['GioBatDau']?.toString() ?? ''),
      'GioKetThuc': TextEditingController(text: hour['GioKetThuc']?.toString() ?? ''),
      'SoCong': TextEditingController(text: hour['SoCong']?.toString() ?? '1'),
      'SoPhut': TextEditingController(text: hour['SoPhut']?.toString() ?? ''),
    };
    String selectedPhanLoai = hour['PhanLoai']?.toString() ?? 'T2T6';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Chỉnh sửa quy định'),
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
                        items: ['T2T6', 'T7', 'CN'].map((value) {
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
                        controller: controllers['GioBatDau']!,
                        decoration: const InputDecoration(
                          labelText: 'Giờ bắt đầu (HH:mm)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.isEmpty == true ? 'Trường này là bắt buộc' : null,
                        onChanged: (value) {
                          if (value.isNotEmpty && controllers['GioKetThuc']!.text.isNotEmpty) {
                            final minutes = _calculateMinutes(value, controllers['GioKetThuc']!.text);
                            controllers['SoPhut']!.text = minutes.toString();
                            setDialogState(() {});
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['GioKetThuc']!,
                        decoration: const InputDecoration(
                          labelText: 'Giờ kết thúc (HH:mm)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.isEmpty == true ? 'Trường này là bắt buộc' : null,
                        onChanged: (value) {
                          if (value.isNotEmpty && controllers['GioBatDau']!.text.isNotEmpty) {
                            final minutes = _calculateMinutes(controllers['GioBatDau']!.text, value);
                            controllers['SoPhut']!.text = minutes.toString();
                            setDialogState(() {});
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['SoCong']!,
                        decoration: const InputDecoration(
                          labelText: 'Số công',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) => value?.isEmpty == true ? 'Trường này là bắt buộc' : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['SoPhut']!,
                        decoration: const InputDecoration(
                          labelText: 'Số phút',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) => value?.isEmpty == true ? 'Trường này là bắt buộc' : null,
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
                  _updateHour(hour['id']?.toString() ?? '', controllers, selectedPhanLoai);
                }
              },
              child: const Text('Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> hour) {
    if (!_buttonsEnabled) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa quy định ID: ${hour['id']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteHour(hour['id']?.toString() ?? '');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _createHour(Map<String, TextEditingController> controllers, String phanLoai) async {
    try {
      final data = {
        'NguoiDung': controllers['NguoiDung']!.text,
        'PhanLoai': phanLoai,
        'GioBatDau': controllers['GioBatDau']!.text,
        'GioKetThuc': controllers['GioKetThuc']!.text,
        'SoCong': controllers['SoCong']!.text,
        'SoPhut': controllers['SoPhut']!.text,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/paygiolamthem'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo quy định thành công')),
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

  Future<void> _updateHour(String id, Map<String, TextEditingController> controllers, String phanLoai) async {
    try {
      final data = {
        'id': id,
        'NguoiDung': controllers['NguoiDung']!.text,
        'PhanLoai': phanLoai,
        'GioBatDau': controllers['GioBatDau']!.text,
        'GioKetThuc': controllers['GioKetThuc']!.text,
        'SoCong': controllers['SoCong']!.text,
        'SoPhut': controllers['SoPhut']!.text,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/paygiolamcapnhat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật quy định thành công')),
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

  Future<void> _deleteHour(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/paygiolamxoa/$id'),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa quy định thành công')),
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
        title: Text('Quy định giờ làm - ${widget.username}'),
        backgroundColor: Colors.indigo[600],
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          if ((widget.userRole == 'Admin' || widget.userRole == 'HR') && _buttonsEnabled)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddHourDialog,
              tooltip: 'Thêm quy định mới',
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
              onPressed: _showAddHourDialog,
              backgroundColor: Colors.indigo[600],
              child: const Icon(Icons.add, color: Colors.white),
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
              Icon(Icons.access_time, color: Colors.indigo[600], size: 24),
              const SizedBox(width: 8),
              Text(
                'Thông tin giờ làm việc',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Người dùng hiện tại',
                  widget.username,
                  Icons.person,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  'Vai trò',
                  widget.userRole,
                  Icons.security,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Tổng số quy định',
                  '${widget.hourData.length}',
                  Icons.schedule,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  'Hiển thị',
                  '${_filteredData.length}',
                  Icons.visibility,
                ),
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
          prefixIcon: Icon(Icons.search, color: Colors.indigo[600]),
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
        border: Border.all(color: Colors.indigo[200]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPhanLoai,
          items: ['Tất cả', 'T2T6', 'T7', 'CN'].map((value) {
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
                color: Colors.indigo[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.table_chart, color: Colors.indigo[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Danh sách quy định giờ làm',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo[600],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_filteredData.length} quy định',
                    style: TextStyle(
                      color: Colors.indigo[600],
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
                        final hour = _filteredData[index];
                        return _buildHourItem(hour, index);
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
          Icon(Icons.access_time_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Không có dữ liệu quy định giờ làm',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          if ((widget.userRole == 'Admin' || widget.userRole == 'HR') && _buttonsEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: _showAddHourDialog,
                icon: const Icon(Icons.add),
                label: const Text('Thêm quy định mới'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHourItem(Map<String, dynamic> hour, int index) {
    final nguoiDung = hour['NguoiDung']?.toString() ?? 'N/A';
    final phanLoai = hour['PhanLoai']?.toString() ?? 'N/A';
    final gioBatDau = hour['GioBatDau']?.toString() ?? 'N/A';
    final gioKetThuc = hour['GioKetThuc']?.toString() ?? 'N/A';
    final soCong = hour['SoCong']?.toString() ?? 'N/A';
    final soPhut = hour['SoPhut']?.toString() ?? 'N/A';
    final id = hour['id']?.toString() ?? 'N/A';

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
            color: _getCategoryColor(phanLoai),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        title: Text(
          '$gioBatDau - $gioKetThuc',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.person, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              nguoiDung,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getCategoryColor(phanLoai).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getCategoryColor(phanLoai),
                  width: 1,
                ),
              ),
              child: Text(
                phanLoai,
                style: TextStyle(
                  color: _getCategoryColor(phanLoai),
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
                    _showEditHourDialog(hour);
                  } else if (value == 'delete') {
                    _showDeleteConfirmation(hour);
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
                _buildTableRow('Giờ bắt đầu', gioBatDau),
                _buildTableRow('Giờ kết thúc', gioKetThuc),
                _buildTableRow('Số công', soCong),
                _buildTableRow('Số phút', soPhut),
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

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'T2T6':
        return Colors.blue;
      case 'T7':
        return Colors.orange;
      case 'CN':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}