import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PayStandardScreen extends StatefulWidget {
  final String username;
  final String userRole;
  final List<Map<String, dynamic>> standardData;

  const PayStandardScreen({
    Key? key,
    required this.username,
    required this.userRole,
    required this.standardData,
  }) : super(key: key);

  @override
  _PayStandardScreenState createState() => _PayStandardScreenState();
}

class _PayStandardScreenState extends State<PayStandardScreen> {
  String _selectedChiNhanh = 'Tất cả';
  List<Map<String, dynamic>> _filteredData = [];
  bool _buttonsEnabled = true;
  static const String baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  
  final Map<String, List<String>> _allowedUsers = {
    'HANOI': ['hm.tason', 'hm.quanganh', 'hm.nguyenthu', 'hm.nguyengiang'],
    'HCM': ['hm.tason', 'hm.quanganh'], 
    'SANXUAT': ['hm.tason', 'hm.quanganh'],
    'LYCHEE': ['hm.tason', 'hm.quanganh'],
    'MIENTRUNG': ['hm.tason', 'hm.quanganh'],
  };

  @override
  void initState() {
    super.initState();
    _filteredData = List.from(widget.standardData);
    _sortData();
  }

void _sortData() {
  _filteredData.sort((a, b) {
    try {
      final dateA = _fixDateDisplay(a['giaiDoan']?.toString() ?? '');
      final dateB = _fixDateDisplay(b['giaiDoan']?.toString() ?? '');
      return dateB.compareTo(dateA);
    } catch (e) {
      return 0;
    }
  });
}

  void _filterData() {
    setState(() {
      _filteredData = widget.standardData.where((standard) {
        final chiNhanh = standard['chiNhanh']?.toString() ?? '';
        return _selectedChiNhanh == 'Tất cả' || chiNhanh == _selectedChiNhanh;
      }).toList();
      _sortData();
    });
  }

  bool _canUserAccessChiNhanh(String chiNhanh) {
    final allowedList = _allowedUsers[chiNhanh] ?? [];
    return allowedList.contains(widget.username);
  }

  bool _canEditRecord(Map<String, dynamic> record) {
  final chiNhanh = record['chiNhanh']?.toString() ?? '';
  if (!_canUserAccessChiNhanh(chiNhanh)) return false;

  try {
    final giaiDoan = _fixDateDisplay(record['giaiDoan']?.toString() ?? '');
    final now = DateTime.now();
    final recordMonth = DateTime(giaiDoan.year, giaiDoan.month);
    final currentMonth = DateTime(now.year, now.month);
    
    if (recordMonth == currentMonth) return true;
    if (recordMonth.isBefore(currentMonth)) {
      final daysSince = now.difference(DateTime(recordMonth.year, recordMonth.month + 1)).inDays;
      return daysSince <= 10;
    }
    
    return false;
  } catch (e) {
    return false;
  }
}

  bool _canCreateRecord(String chiNhanh, DateTime targetMonth) {
  if (!_canUserAccessChiNhanh(chiNhanh)) return false;
  
  final now = DateTime.now();
  final currentMonth = DateTime(now.year, now.month);
  final nextMonth = DateTime(now.year, now.month + 1);
  final target = DateTime(targetMonth.year, targetMonth.month);
  
  if (target != currentMonth && target != nextMonth) return false;
  
  return !widget.standardData.any((record) {
    final recordChiNhanh = record['chiNhanh']?.toString() ?? '';
    if (recordChiNhanh != chiNhanh) return false;
    
    try {
      final recordDate = _fixDateDisplay(record['giaiDoan']?.toString() ?? '');
      final recordMonth = DateTime(recordDate.year, recordDate.month);
      return recordMonth == target;
    } catch (e) {
      return false;
    }
  });
}

  List<String> _getChiNhanhOptions() {
    final chiNhanhSet = <String>{'Tất cả'};
    for (final standard in widget.standardData) {
      final chiNhanh = standard['chiNhanh']?.toString() ?? '';
      if (chiNhanh.isNotEmpty) {
        chiNhanhSet.add(chiNhanh);
      }
    }
    return chiNhanhSet.toList();
  }

  void _showEditStandardDialog(Map<String, dynamic> standard) {
    if (!_buttonsEnabled || !_canEditRecord(standard)) return;
    
    final formKey = GlobalKey<FormState>();
    final controllers = {
      'uid': TextEditingController(text: standard['uid']?.toString() ?? ''),
      'congGs': TextEditingController(text: standard['congGs']?.toString() ?? '0'),
      'congVp': TextEditingController(text: standard['congVp']?.toString() ?? '0'),
      'congCn': TextEditingController(text: standard['congCn']?.toString() ?? '0'),
      'congKhac': TextEditingController(text: standard['congKhac']?.toString() ?? '0'),
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa công chuẩn'),
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
                      controller: controllers['uid']!,
                      decoration: const InputDecoration(
                        labelText: 'UID',
                        border: OutlineInputBorder(),
                      ),
                      enabled: false,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Chi nhánh',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(standard['chiNhanh']?.toString() ?? ''),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Giai đoạn',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFormat('MM/yyyy').format(DateTime.parse(standard['giaiDoan']))),
                    ),
                  ),
                  ...['congGs', 'congVp', 'congCn', 'congKhac'].map((field) =>
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers[field]!,
                        decoration: InputDecoration(
                          labelText: field.replaceFirst('cong', 'Công '),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value?.isEmpty == true) return 'Trường này là bắt buộc';
                          final double? val = double.tryParse(value!);
                          if (val == null || val < 0 || val > 40) {
                            return 'Giá trị phải từ 0 đến 40';
                          }
                          return null;
                        },
                      ),
                    ),
                  ).toList(),
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
                _updateStandard(standard['uid']?.toString() ?? '', controllers);
              }
            },
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> standard) {
    if (!_buttonsEnabled || !_canEditRecord(standard)) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa công chuẩn UID: ${standard['uid']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteStandard(standard['uid']?.toString() ?? '');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
void _showAddStandardDialog() {
  if (!_buttonsEnabled) return;
  
  final formKey = GlobalKey<FormState>();
  final controllers = {
    'congGs': TextEditingController(text: '0'),
    'congVp': TextEditingController(text: '0'),
    'congCn': TextEditingController(text: '0'),
    'congKhac': TextEditingController(text: '0'),
  };
  
  String selectedChiNhanh = 'HANOI';
  DateTime selectedDate = DateTime.now();

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Thêm công chuẩn'),
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
                    child: DropdownButtonFormField<String>(
                      value: selectedChiNhanh,
                      decoration: const InputDecoration(
                        labelText: 'Chi nhánh',
                        border: OutlineInputBorder(),
                      ),
                      items: ['HANOI', 'HCM', 'SANXUAT', 'LYCHEE', 'MIENTRUNG']
                          .where((cn) => _canUserAccessChiNhanh(cn))
                          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedChiNhanh = value!;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 60)),
                        );
                        if (date != null) {
                          setDialogState(() {
                            selectedDate = date;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tháng/Năm',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(DateFormat('MM/yyyy').format(selectedDate)),
                      ),
                    ),
                  ),
                  ...['congGs', 'congVp', 'congCn', 'congKhac'].map((field) =>
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers[field]!,
                        decoration: InputDecoration(
                          labelText: field.replaceFirst('cong', 'Công '),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value?.isEmpty == true) return 'Trường này là bắt buộc';
                          final double? val = double.tryParse(value!);
                          if (val == null || val < 0 || val > 40) {
                            return 'Giá trị phải từ 0 đến 40';
                          }
                          return null;
                        },
                      ),
                    ),
                  ).toList(),
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
                // Convert to first day of month
                final firstDay = DateTime(selectedDate.year, selectedDate.month, 1);
                if (!_canCreateRecord(selectedChiNhanh, firstDay)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Không thể tạo bản ghi cho thời gian này hoặc đã tồn tại')),
                  );
                  return;
                }
                Navigator.pop(context);
                _createStandard(controllers, selectedChiNhanh, firstDay);
              }
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _createStandard(Map<String, TextEditingController> controllers, String chiNhanh, DateTime giaiDoan) async {
  try {
    // Generate UID based on chiNhanh and date
    final monthYear = DateFormat('yyyyMM').format(giaiDoan);
    final uid = '${chiNhanh}_$monthYear';
    
    final data = {
      'uid': uid,
      'giaiDoan': DateFormat('yyyy-MM-dd').format(giaiDoan), // First day of month
      'congGs': double.parse(controllers['congGs']!.text),
      'congVp': double.parse(controllers['congVp']!.text),
      'congCn': double.parse(controllers['congCn']!.text),
      'congKhac': double.parse(controllers['congKhac']!.text),
      'chiNhanh': chiNhanh,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/paycongchuantao'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tạo công chuẩn thành công')),
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
  Future<void> _updateStandard(String uid, Map<String, TextEditingController> controllers) async {
    try {
      final data = {
        'uid': uid,
        'congGs': double.parse(controllers['congGs']!.text),
        'congVp': double.parse(controllers['congVp']!.text),
        'congCn': double.parse(controllers['congCn']!.text),
        'congKhac': double.parse(controllers['congKhac']!.text),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/paycongchuancapnhat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật công chuẩn thành công')),
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

  Future<void> _deleteStandard(String uid) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/paycongchuanxoa/$uid'),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa công chuẩn thành công')),
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
        title: Text('Công chuẩn - ${widget.username}'),
        backgroundColor: Colors.teal[600],
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          if (_buttonsEnabled && _allowedUsers.values.any((list) => list.contains(widget.username)))
            IconButton(
              icon: const Icon(Icons.add_chart),
              onPressed: _showAddStandardDialog,
              tooltip: 'Thêm công chuẩn',
            ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildFilterRow(),
            const SizedBox(height: 16),
            _buildDataTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final totalRecords = _filteredData.length;
    final totalCong = _filteredData.fold<double>(
      0,
      (sum, item) => sum + 
        (item['congGs'] ?? 0).toDouble() + 
        (item['congVp'] ?? 0).toDouble() + 
        (item['congCn'] ?? 0).toDouble() + 
        (item['congKhac'] ?? 0).toDouble(),
    );

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
              Icon(Icons.work_outline, color: Colors.teal[600], size: 24),
              const SizedBox(width: 8),
              Text(
                'Thông tin công chuẩn',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[600],
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
                child: _buildInfoItem('Hiển thị', '$totalRecords', Icons.article),
              ),
              Expanded(
                child: _buildInfoItem('Tổng công', '${totalCong.toStringAsFixed(1)}', Icons.work),
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

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal[200]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedChiNhanh,
          items: _getChiNhanhOptions().map((value) {
            return DropdownMenuItem(
              value: value,
              child: Text('Chi nhánh: $value', style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedChiNhanh = value!;
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
                color: Colors.teal[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.table_chart, color: Colors.teal[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Danh sách công chuẩn',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[600],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_filteredData.length} bản ghi',
                    style: TextStyle(
                      color: Colors.teal[600],
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
                        final standard = _filteredData[index];
                        return _buildStandardItem(standard, index);
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
          Icon(Icons.work_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Không có dữ liệu công chuẩn',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          if (_buttonsEnabled && _allowedUsers.values.any((list) => list.contains(widget.username)))
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: _showAddStandardDialog,
                icon: const Icon(Icons.add_chart),
                label: const Text('Thêm công chuẩn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
DateTime _fixDateDisplay(String dateString) {
  try {
    final date = DateTime.parse(dateString);
    return date.add(const Duration(days: 1));
  } catch (e) {
    return DateTime.now();
  }
}

String _formatDateDisplay(String dateString) {
  try {
    final fixedDate = _fixDateDisplay(dateString);
    return DateFormat('MM/yyyy').format(fixedDate);
  } catch (e) {
    return dateString;
  }
}
  Widget _buildStandardItem(Map<String, dynamic> standard, int index) {
  final uid = standard['uid']?.toString() ?? 'N/A';
  final giaiDoan = standard['giaiDoan']?.toString() ?? 'N/A';
  final congGs = (standard['congGs'] ?? 0).toDouble();
  final congVp = (standard['congVp'] ?? 0).toDouble();
  final congCn = (standard['congCn'] ?? 0).toDouble();
  final congKhac = (standard['congKhac'] ?? 0).toDouble();
  final chiNhanh = standard['chiNhanh']?.toString() ?? 'N/A';
  
  final totalCong = congGs + congVp + congCn + congKhac;
  final canEdit = _canEditRecord(standard);
  
  final formattedDate = _formatDateDisplay(giaiDoan);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 50,
          height: 40,
          decoration: BoxDecoration(
            color: _getTotalCongColor(totalCong),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                totalCong.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Text(
                'công',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
        title: Text(
      '$chiNhanh - $formattedDate',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          'UID: $uid',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: (_buttonsEnabled && canEdit)
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
                    _showEditStandardDialog(standard);
                  } else if (value == 'delete') {
                    _showDeleteConfirmation(standard);
                  }
                },
              )
            : null,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildWorkTypeChart(congGs, congVp, congCn, congKhac),
                const SizedBox(height: 16),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(2),
                  },
                  children: [
                    _buildTableRow('UID', uid),
                _buildTableRow('Giai đoạn', formattedDate), 
                _buildTableRow('Công GS', '${congGs.toStringAsFixed(1)} công'),
                _buildTableRow('Công VP', '${congVp.toStringAsFixed(1)} công'),
                _buildTableRow('Công CN', '${congCn.toStringAsFixed(1)} công'),
                _buildTableRow('Công khác', '${congKhac.toStringAsFixed(1)} công'),
                _buildTableRow('Tổng công', '${totalCong.toStringAsFixed(1)} công'),
                _buildTableRow('Chi nhánh', chiNhanh),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkTypeChart(double congGs, double congVp, double congCn, double congKhac) {
    final total = congGs + congVp + congCn + congKhac;
    if (total == 0) return Container();

    return Container(
      height: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            'Phân bổ công việc',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (congGs > 0) Expanded(
                flex: (congGs * 100).round(),
                child: Container(
                  height: 20,
                  color: Colors.blue,
                  child: Center(
                    child: Text(
                      'GS\n${(congGs/total*100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white, fontSize: 8),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              if (congVp > 0) Expanded(
                flex: (congVp * 100).round(),
                child: Container(
                  height: 20,
                  color: Colors.green,
                  child: Center(
                    child: Text(
                      'VP\n${(congVp/total*100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white, fontSize: 8),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              if (congCn > 0) Expanded(
                flex: (congCn * 100).round(),
                child: Container(
                  height: 20,
                  color: Colors.orange,
                  child: Center(
                    child: Text(
                      'CN\n${(congCn/total*100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white, fontSize: 8),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              if (congKhac > 0) Expanded(
                flex: (congKhac * 100).round(),
                child: Container(
                  height: 20,
                  color: Colors.purple,
                  child: Center(
                    child: Text(
                      'Khác\n${(congKhac/total*100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white, fontSize: 8),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
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

  Color _getTotalCongColor(double totalCong) {
    if (totalCong >= 30) return Colors.green[600]!;
    if (totalCong >= 20) return Colors.orange[600]!;
    if (totalCong >= 10) return Colors.blue[600]!;
    return Colors.grey[600]!;
  }
}