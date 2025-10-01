import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PayPolicyScreen extends StatefulWidget {
  final String username;
  final String userRole;
  final List<Map<String, dynamic>> policyData;
  final List<Map<String, dynamic>> accountData;

  const PayPolicyScreen({
    Key? key,
    required this.username,
    required this.userRole,
    required this.policyData,
    required this.accountData,
  }) : super(key: key);

  @override
  _PayPolicyScreenState createState() => _PayPolicyScreenState();
}

class _PayPolicyScreenState extends State<PayPolicyScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedLoaiCong = 'Tất cả';
  final List<String> _loaiCongOptions = ['Tất cả', 'Vp', 'Cn', 'Gs', 'Khac'];
  double _minSalary = 0;
  double _maxSalary = double.infinity;
  static const String baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getUserName(String userId) {
    try {
      final account = widget.accountData.firstWhere(
        (acc) => acc['Username']?.toString() == userId,
        orElse: () => {},
      );
      return account['Name']?.toString() ?? 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  String _getUserCode(String userId) {
    try {
      final account = widget.accountData.firstWhere(
        (acc) => acc['Username']?.toString() == userId,
        orElse: () => {},
      );
      return account['UserID']?.toString() ?? 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.userRole == 'Admin' || widget.userRole == 'AC';
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Chế độ lương - ${widget.username}'),
        backgroundColor: Colors.deepPurple[600],
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.add_business),
              onPressed: _showAddPolicyDialog,
              tooltip: 'Thêm chế độ mới',
            ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildSearchAndFilterCard(),
            const SizedBox(height: 16),
            _buildDataTable(),
          ],
        ),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: _showAddPolicyDialog,
              backgroundColor: Colors.deepPurple[600],
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHeaderCard() {
    final latestRecords = _getLatestRecords();
    
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
              Icon(Icons.policy, color: Colors.deepPurple[600], size: 24),
              const SizedBox(width: 8),
              Text(
                'Thông tin chế độ lương',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple[600],
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
              Expanded(
                child: _buildInfoItem('Số bản ghi', '${latestRecords.length}', Icons.assignment),
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

  Widget _buildSearchAndFilterCard() {
    return Container(
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
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Tìm kiếm',
                    hintText: 'UserID, Tên, Mã NV...',
                    prefixIcon: Icon(Icons.search, color: Colors.deepPurple[600]),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _selectedLoaiCong,
                  decoration: InputDecoration(
                    labelText: 'Loại công',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _loaiCongOptions.map((option) {
                    return DropdownMenuItem(
                      value: option,
                      child: Text(option, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedLoaiCong = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _showSalaryFilterDialog,
                  icon: const Icon(Icons.filter_alt, size: 16),
                  label: const Text('Lọc lương', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSalaryFilterDialog() {
    final minController = TextEditingController(text: _minSalary == 0 ? '' : _minSalary.toString());
    final maxController = TextEditingController(text: _maxSalary == double.infinity ? '' : _maxSalary.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lọc theo mức lương'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Lương tối thiểu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: maxController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Lương tối đa',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _minSalary = 0;
                _maxSalary = double.infinity;
              });
              Navigator.pop(context);
            },
            child: const Text('Xóa lọc'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _minSalary = double.tryParse(minController.text) ?? 0;
                _maxSalary = double.tryParse(maxController.text) ?? double.infinity;
              });
              Navigator.pop(context);
            },
            child: const Text('Áp dụng'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getLatestRecords() {
    final Map<String, Map<String, dynamic>> latestByUser = {};
    
    for (final policy in widget.policyData) {
      final userId = policy['userId']?.toString() ?? '';
      if (userId.isEmpty) continue;
      
      try {
        final date = DateTime.parse(policy['ngay']?.toString() ?? '');
        
        if (!latestByUser.containsKey(userId)) {
          latestByUser[userId] = policy;
        } else {
          final existingDate = DateTime.parse(latestByUser[userId]!['ngay']?.toString() ?? '');
          if (date.isAfter(existingDate)) {
            latestByUser[userId] = policy;
          }
        }
      } catch (e) {
        if (!latestByUser.containsKey(userId)) {
          latestByUser[userId] = policy;
        }
      }
    }
    
    final result = latestByUser.values.toList();
    result.sort((a, b) {
      try {
        final dateA = DateTime.parse(a['ngay']?.toString() ?? '');
        final dateB = DateTime.parse(b['ngay']?.toString() ?? '');
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });
    
    return result;
  }

  List<Map<String, dynamic>> _getFilteredData() {
    var filtered = _getLatestRecords();
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((policy) {
        final userId = policy['userId']?.toString().toLowerCase() ?? '';
        final userName = _getUserName(policy['userId']?.toString() ?? '').toLowerCase();
        final userCode = _getUserCode(policy['userId']?.toString() ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();
        return userId.contains(query) || userName.contains(query) || userCode.contains(query);
      }).toList();
    }
    
    if (_selectedLoaiCong != 'Tất cả') {
      filtered = filtered.where((policy) {
        return policy['loaiCong']?.toString() == _selectedLoaiCong;
      }).toList();
    }
    
    filtered = filtered.where((policy) {
      final mucLuong = (policy['mucLuong'] ?? 0) as num;
      final mucLuongChinh = (policy['mucLuongChinh'] ?? 0) as num;
      final maxSalary = mucLuong > mucLuongChinh ? mucLuong : mucLuongChinh;
      return maxSalary >= _minSalary && maxSalary <= _maxSalary;
    }).toList();
    
    return filtered;
  }

  Widget _buildDataTable() {
    final filteredData = _getFilteredData();
    
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
                color: Colors.deepPurple[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.table_chart, color: Colors.deepPurple[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Danh sách chế độ lương',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple[600],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${filteredData.length} bản ghi',
                    style: TextStyle(
                      color: Colors.deepPurple[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: filteredData.isEmpty
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                          columns: const [
                            DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('User ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Tên', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Mã NV', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Loại công', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Lương thử việc', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Lương chính thức', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Đang thử việc', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: filteredData.map((policy) {
                            final userId = policy['userId']?.toString() ?? 'N/A';
                            final userName = _getUserName(userId);
                            final userCode = _getUserCode(userId);
                            final loaiCong = policy['loaiCong']?.toString() ?? 'N/A';
                            final mucLuong = policy['mucLuong'] ?? 0;
                            final mucLuongChinh = policy['mucLuongChinh'] ?? 0;
                            final dangThuViec = policy['dangThuViec']?.toString().toLowerCase() == 'true' || 
                                               policy['dangThuViec']?.toString() == 'Y';
                            
                            return DataRow(
                              cells: [
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.visibility, size: 20),
                                    onPressed: () => _showPolicyDetailDialog(policy),
                                    tooltip: 'Xem chi tiết',
                                  ),
                                ),
                                DataCell(Text(userId, style: const TextStyle(fontSize: 12))),
                                DataCell(Text(userName, style: const TextStyle(fontSize: 12))),
                                DataCell(Text(userCode, style: const TextStyle(fontSize: 12))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getLoaiCongColor(loaiCong),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      loaiCong,
                                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                DataCell(Text(
                                  NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(mucLuong),
                                  style: const TextStyle(fontSize: 12),
                                )),
                                DataCell(Text(
                                  NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(mucLuongChinh),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                )),
                                DataCell(
                                  Icon(
                                    dangThuViec ? Icons.check_circle : Icons.cancel,
                                    color: dangThuViec ? Colors.orange : Colors.green,
                                    size: 20,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getLoaiCongColor(String loaiCong) {
    switch (loaiCong) {
      case 'Vp':
        return Colors.blue;
      case 'Cn':
        return Colors.orange;
      case 'Gs':
        return Colors.purple;
      case 'Khac':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.policy, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Không có dữ liệu phù hợp',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showPolicyDetailDialog(Map<String, dynamic> policy) {
    final userId = policy['userId']?.toString() ?? '';
    
    // Get all records for this user
    final userRecords = widget.policyData
        .where((p) => p['userId']?.toString() == userId)
        .toList();
    
    userRecords.sort((a, b) {
      try {
        final dateA = DateTime.parse(a['ngay']?.toString() ?? '');
        final dateB = DateTime.parse(b['ngay']?.toString() ?? '');
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });

    Map<String, dynamic> selectedRecord = policy;
    final canEdit = widget.userRole == 'Admin' || widget.userRole == 'AC';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Chi tiết chế độ lương - $userId'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (userRecords.length > 1) ...[
                    const Text('Chọn bản ghi:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: userRecords.map((record) {
                        final isSelected = record['uid'] == selectedRecord['uid'];
                        String formattedDate = 'N/A';
                        try {
                          final date = DateTime.parse(record['ngay']?.toString() ?? '');
                          formattedDate = DateFormat('dd/MM/yyyy').format(date);
                        } catch (e) {}
                        
                        return FilterChip(
                          label: Text(formattedDate),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                selectedRecord = record;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const Divider(),
                  ],
                  _buildDetailTable(selectedRecord),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
            if (canEdit)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showEditPolicyDialog(selectedRecord);
                },
                icon: const Icon(Icons.edit),
                label: const Text('Chỉnh sửa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple[600],
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void _showAddPolicyDialog() {
    _showEditPolicyDialog(null);
  }

  void _showEditPolicyDialog(Map<String, dynamic>? existingPolicy) {
    final isEdit = existingPolicy != null;
    final formKey = GlobalKey<FormState>();
    
    // Calculate default values
    int defaultSoNguoiPhuThuoc = existingPolicy?['soNguoiPhuThuoc'] ?? 0;
    int defaultThueGiamTruPhuThuoc = isEdit 
        ? (existingPolicy?['thueGiamTruPhuThuoc'] ?? 4400000 * defaultSoNguoiPhuThuoc)
        : 4400000 * defaultSoNguoiPhuThuoc;
    
    final controllers = {
      'userId': TextEditingController(text: existingPolicy?['userId']?.toString() ?? ''),
      'loaiCong': existingPolicy?['loaiCong']?.toString() ?? 'Vp',
      'mucLuong': TextEditingController(text: existingPolicy?['mucLuong']?.toString() ?? '0'),
      'dangThuViec': existingPolicy?['dangThuViec']?.toString().toLowerCase() == 'true' || 
                     existingPolicy?['dangThuViec']?.toString() == 'Y',
      'mucLuongChinh': TextEditingController(text: existingPolicy?['mucLuongChinh']?.toString() ?? '0'),
      'mucBhxh': TextEditingController(text: existingPolicy?['mucBhxh']?.toString() ?? '0'),
      'truBhxh': TextEditingController(text: existingPolicy?['truBhxh']?.toString() ?? '0'),
      'mucCongDoan': TextEditingController(text: existingPolicy?['mucCongDoan']?.toString() ?? '0'),
      'truCongDoan': TextEditingController(text: existingPolicy?['truCongDoan']?.toString() ?? '0'),
      'phuCapDienThoai': TextEditingController(text: existingPolicy?['phuCapDienThoai']?.toString() ?? '0'),
      'phuCapGuiXe': TextEditingController(text: existingPolicy?['phuCapGuiXe']?.toString() ?? '0'),
      'phuCapAnUong': TextEditingController(text: existingPolicy?['phuCapAnUong']?.toString() ?? '0'),
      'phuCapTrangPhuc': TextEditingController(text: existingPolicy?['phuCapTrangPhuc']?.toString() ?? '0'),
      'hoTroKhac': TextEditingController(text: existingPolicy?['hoTroKhac']?.toString() ?? '0'),
      'dieuChinhKhac': TextEditingController(text: existingPolicy?['dieuChinhKhac']?.toString() ?? '0'),
      'hinhThucTangCa': existingPolicy?['hinhThucTangCa']?.toString() ?? 'BHXH',
      'mucCoDinhTangCa': TextEditingController(text: existingPolicy?['mucCoDinhTangCa']?.toString() ?? '0'),
      'soNguoiPhuThuoc': TextEditingController(text: defaultSoNguoiPhuThuoc.toString()),
      'thueGiamTruPhuThuoc': TextEditingController(text: defaultThueGiamTruPhuThuoc.toString()),
      'thueGiamTruBanThan': TextEditingController(text: existingPolicy?['thueGiamTruBanThan']?.toString() ?? '11000000'),
      'thueGiamTruTrangPhuc': TextEditingController(text: isEdit ? (existingPolicy?['thueGiamTruTrangPhuc']?.toString() ?? '') : '416667'),
      'thueGiamTruDienThoai': TextEditingController(text: existingPolicy?['thueGiamTruDienThoai']?.toString() ?? '0'),
      'thueGiamTruAn': TextEditingController(text: isEdit ? (existingPolicy?['thueGiamTruAn']?.toString() ?? '') : '730000'),
      'thueGiamTruXangXe': TextEditingController(text: existingPolicy?['thueGiamTruXangXe']?.toString() ?? '0'),
    };

    String selectedLoaiCong = controllers['loaiCong'] as String;
    bool selectedDangThuViec = controllers['dangThuViec'] as bool;
    String selectedHinhThucTangCa = controllers['hinhThucTangCa'] as String;
    String? selectedMucCoDinh;

    final predefinedOvertimeRates = ['20000', '22000', '25000', '27000', '30000', '35000'];

    // Auto-calculate functions
    void calculateTruBhxh() {
      final mucBhxh = double.tryParse((controllers['mucBhxh'] as TextEditingController).text) ?? 0;
      (controllers['truBhxh'] as TextEditingController).text = (mucBhxh * 0.105).round().toString();
    }

    void calculateCongDoan() {
      final mucBhxh = double.tryParse((controllers['mucBhxh'] as TextEditingController).text) ?? 0;
      (controllers['mucCongDoan'] as TextEditingController).text = (mucBhxh * 0.01).round().toString();
      (controllers['truCongDoan'] as TextEditingController).text = (mucBhxh * 0.01).round().toString();
    }

    void calculateThueGiamTruPhuThuoc() {
      final soNguoi = int.tryParse((controllers['soNguoiPhuThuoc'] as TextEditingController).text) ?? 0;
      (controllers['thueGiamTruPhuThuoc'] as TextEditingController).text = (4400000 * soNguoi).toString();
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Chỉnh sửa chế độ lương' : 'Thêm chế độ lương mới'),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isEdit) ...[
                      TextFormField(
                        initialValue: existingPolicy['uid']?.toString() ?? '',
                        decoration: const InputDecoration(
                          labelText: 'UID',
                          border: OutlineInputBorder(),
                        ),
                        enabled: false,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: controllers['userId'] as TextEditingController,
                      decoration: const InputDecoration(
                        labelText: 'User ID *',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !isEdit,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'User ID là bắt buộc';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedLoaiCong,
                      decoration: const InputDecoration(
                        labelText: 'Loại công *',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Vp', 'Cn', 'Gs', 'Khac'].map((option) {
                        return DropdownMenuItem(
                          value: option,
                          child: Text(option),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedLoaiCong = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers['mucLuong'] as TextEditingController,
                      decoration: const InputDecoration(
                        labelText: 'Mức lương (Lương thử việc)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Đang thử việc'),
                      value: selectedDangThuViec,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedDangThuViec = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers['mucLuongChinh'] as TextEditingController,
                      decoration: const InputDecoration(
                        labelText: 'Mức lương chính *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Mức lương chính là bắt buộc';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers['mucBhxh'] as TextEditingController,
                      decoration: const InputDecoration(
                        labelText: 'Mức BHXH',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        calculateTruBhxh();
                        calculateCongDoan();
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers['truBhxh'] as TextEditingController,
                      decoration: const InputDecoration(
                        labelText: 'Trừ BHXH (10.5% - tự động)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers['mucCongDoan'] as TextEditingController,
                      decoration: const InputDecoration(
                        labelText: 'Mức công đoàn (1% - tự động)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers['truCongDoan'] as TextEditingController,
                      decoration: const InputDecoration(
                        labelText: 'Trừ công đoàn (1% - tự động)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers['phuCapDienThoai'] as TextEditingController,
                      decoration: const InputDecoration(
                        labelText: 'Phụ cấp điện thoại',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers['phuCapGuiXe'] as TextEditingController,
                      decoration: const InputDecoration(
                        labelText: 'Phụ cấp gửi xe',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers['phuCapAnUong'] as TextEditingController,
                      decoration: const InputDecoration(
                        labelText: 'Phụ cấp ăn uống',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers['phuCapTrangPhuc'] as TextEditingController,
                      decoration: const InputDecoration(
                        labelText: 'Phụ cấp trang phục',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers['hoTroKhac'] as TextEditingController,
                      decoration: const InputDecoration(
                        labelText: 'Hỗ trợ khác',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers['dieuChinhKhac'] as TextEditingController,
                      decoration: const InputDecoration(
                        labelText: 'Điều chỉnh khác',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedHinhThucTangCa,
                      decoration: const InputDecoration(
                        labelText: 'Hình thức tăng ca *',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Cố Định', 'BHXH', 'Luong'].map((option) {
                        return DropdownMenuItem(
                          value: option,
                          child: Text(option),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedHinhThucTangCa = value!;
                          if (value != 'Cố Định') {
                            (controllers['mucCoDinhTangCa'] as TextEditingController).text = '0';
                            selectedMucCoDinh = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (selectedHinhThucTangCa == 'Cố Định') ...[
                      DropdownButtonFormField<String>(
                        value: selectedMucCoDinh,
                        decoration: const InputDecoration(
                          labelText: 'Mức cố định tăng ca *',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Chọn mức có sẵn')),
                          ...predefinedOvertimeRates.map((rate) {
                            return DropdownMenuItem(
                              value: rate,
                              child: Text(NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(int.parse(rate))),
                            );
                          }),
                          const DropdownMenuItem(value: 'custom', child: Text('Nhập tùy chỉnh')),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedMucCoDinh = value;
                            if (value != null && value != 'custom') {
                              (controllers['mucCoDinhTangCa'] as TextEditingController).text = value;
                            } else if (value == 'custom') {
                              (controllers['mucCoDinhTangCa'] as TextEditingController).text = '';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (selectedMucCoDinh == 'custom')
                        TextFormField(
                          controller: controllers['mucCoDinhTangCa'] as TextEditingController,
                          decoration: const InputDecoration(
                            labelText: 'Nhập mức tăng ca (tối đa 200,000)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (selectedHinhThucTangCa == 'Cố Định') {
                              if (value == null || value.isEmpty) {
                                return 'Mức cố định tăng ca là bắt buộc';
                              }
                              final amount = int.tryParse(value);
                              if (amount == null || amount > 200000) {
                                return 'Giá trị không hợp lệ (tối đa 200,000)';
                              }
                            }
                            return null;
                          },
                        ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers['soNguoiPhuThuoc'] as TextEditingController,
                      decoration: const InputDecoration(
                        labelText: 'Số người phụ thuộc',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        calculateThueGiamTruPhuThuoc();
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers['thueGiamTruPhuThuoc'] as TextEditingController,
                      decoration: const InputDecoration(
                        labelText: 'Thuế giảm trừ phụ thuộc (4,400,000/người - tự động)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers['thueGiamTruBanThan'] as TextEditingController,
                      decoration: const InputDecoration(
                        labelText: 'Thuế giảm trừ bản thân (mặc định: 11,000,000)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers['thueGiamTruTrangPhuc'] as TextEditingController,
                      decoration: InputDecoration(
                        labelText: isEdit ? 'Thuế giảm trừ trang phục' : 'Thuế giảm trừ trang phục (mặc định: 416,667)',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers['thueGiamTruDienThoai'] as TextEditingController,
                      decoration: const InputDecoration(
                        labelText: 'Thuế giảm trừ điện thoại',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers['thueGiamTruAn'] as TextEditingController,
                      decoration: InputDecoration(
                        labelText: isEdit ? 'Thuế giảm trừ ăn' : 'Thuế giảm trừ ăn (mặc định: 730,000)',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers['thueGiamTruXangXe'] as TextEditingController,
                      decoration: const InputDecoration(
                        labelText: 'Thuế giảm trừ xăng xe',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
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
                  _submitPolicy(controllers, selectedLoaiCong, selectedDangThuViec, selectedHinhThucTangCa, isEdit, existingPolicy);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple[600],
                foregroundColor: Colors.white,
              ),
              child: Text(isEdit ? 'Cập nhật' : 'Tạo mới'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTable(Map<String, dynamic> policy) {
    String formattedDate = 'N/A';
    try {
      final date = DateTime.parse(policy['ngay']?.toString() ?? '');
      formattedDate = DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {}

    final userId = policy['userId']?.toString() ?? 'N/A';
    final userName = _getUserName(userId);
    final userCode = _getUserCode(userId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bold user info at top
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.deepPurple[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Tên: ', style: TextStyle(fontSize: 14)),
                  Text(userName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('Mã NV: ', style: TextStyle(fontSize: 14)),
                  Text(userCode, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1.5),
            1: FlexColumnWidth(2),
          },
          children: [
            _buildTableRow('UID', policy['uid']?.toString() ?? 'N/A'),
            _buildTableRow('User ID', userId),
            _buildTableRow('Ngày áp dụng', formattedDate),
            _buildTableRow('Loại công', policy['loaiCong']?.toString() ?? 'N/A'),
            _buildTableRow('Mức lương', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['mucLuong'] ?? 0)),
            _buildTableRow('Đang thử việc', (policy['dangThuViec']?.toString().toLowerCase() == 'true' || policy['dangThuViec']?.toString() == 'Y') ? 'Có' : 'Không'),
            _buildTableRow('Mức lương chính', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['mucLuongChinh'] ?? 0)),
            _buildTableRow('Mức BHXH', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['mucBhxh'] ?? 0)),
            _buildTableRow('Trừ BHXH', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['truBhxh'] ?? 0)),
            _buildTableRow('Mức công đoàn', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['mucCongDoan'] ?? 0)),
            _buildTableRow('Trừ công đoàn', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['truCongDoan'] ?? 0)),
            _buildTableRow('PC điện thoại', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['phuCapDienThoai'] ?? 0)),
            _buildTableRow('PC gửi xe', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['phuCapGuiXe'] ?? 0)),
            _buildTableRow('PC ăn uống', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['phuCapAnUong'] ?? 0)),
            _buildTableRow('PC trang phục', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['phuCapTrangPhuc'] ?? 0)),
            _buildTableRow('Hỗ trợ khác', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['hoTroKhac'] ?? 0)),
            _buildTableRow('Điều chỉnh khác', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['dieuChinhKhac'] ?? 0)),
            _buildTableRow('Hình thức tăng ca', policy['hinhThucTangCa']?.toString() ?? 'N/A'),
            _buildTableRow('Mức cố định tăng ca', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['mucCoDinhTangCa'] ?? 0)),
            _buildTableRow('Số người phụ thuộc', policy['soNguoiPhuThuoc']?.toString() ?? '0'),
            _buildTableRow('Thuế giảm trừ phụ thuộc', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['thueGiamTruPhuThuoc'] ?? 0)),
            _buildTableRow('Thuế giảm trừ bản thân', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['thueGiamTruBanThan'] ?? 0)),
            _buildTableRow('Thuế giảm trừ trang phục', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['thueGiamTruTrangPhuc'] ?? 0)),
            _buildTableRow('Thuế giảm trừ điện thoại', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['thueGiamTruDienThoai'] ?? 0)),
            _buildTableRow('Thuế giảm trừ ăn', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['thueGiamTruAn'] ?? 0)),
            _buildTableRow('Thuế giảm trừ xăng xe', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['thueGiamTruXangXe'] ?? 0)),
          ],
        ),
      ],
    );
  }

  Future<void> _submitPolicy(
    Map<String, dynamic> controllers,
    String loaiCong,
    bool dangThuViec,
    String hinhThucTangCa,
    bool isEdit,
    Map<String, dynamic>? existingPolicy,
  ) async {
    try {
      final data = {
        if (isEdit) 'uid': existingPolicy!['uid'],
        'userId': (controllers['userId'] as TextEditingController).text,
        'ngay': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'loaiCong': loaiCong,
        'mucLuong': int.tryParse((controllers['mucLuong'] as TextEditingController).text) ?? 0,
        'dangThuViec': dangThuViec.toString(),
        'mucLuongChinh': int.tryParse((controllers['mucLuongChinh'] as TextEditingController).text) ?? 0,
        'mucBhxh': int.tryParse((controllers['mucBhxh'] as TextEditingController).text) ?? 0,
        'truBhxh': int.tryParse((controllers['truBhxh'] as TextEditingController).text) ?? 0,
        'mucCongDoan': int.tryParse((controllers['mucCongDoan'] as TextEditingController).text) ?? 0,
        'truCongDoan': int.tryParse((controllers['truCongDoan'] as TextEditingController).text) ?? 0,
        'phuCapDienThoai': int.tryParse((controllers['phuCapDienThoai'] as TextEditingController).text) ?? 0,
        'phuCapGuiXe': int.tryParse((controllers['phuCapGuiXe'] as TextEditingController).text) ?? 0,
        'phuCapAnUong': int.tryParse((controllers['phuCapAnUong'] as TextEditingController).text) ?? 0,
        'phuCapTrangPhuc': int.tryParse((controllers['phuCapTrangPhuc'] as TextEditingController).text) ?? 0,
        'hoTroKhac': int.tryParse((controllers['hoTroKhac'] as TextEditingController).text) ?? 0,
        'dieuChinhKhac': int.tryParse((controllers['dieuChinhKhac'] as TextEditingController).text) ?? 0,
        'hinhThucTangCa': hinhThucTangCa,
        'mucCoDinhTangCa': int.tryParse((controllers['mucCoDinhTangCa'] as TextEditingController).text) ?? 0,
        'soNguoiPhuThuoc': int.tryParse((controllers['soNguoiPhuThuoc'] as TextEditingController).text) ?? 0,
        'thueGiamTruPhuThuoc': int.tryParse((controllers['thueGiamTruPhuThuoc'] as TextEditingController).text) ?? 0,
        'thueGiamTruBanThan': int.tryParse((controllers['thueGiamTruBanThan'] as TextEditingController).text) ?? 0,
        'thueGiamTruTrangPhuc': int.tryParse((controllers['thueGiamTruTrangPhuc'] as TextEditingController).text) ?? 0,
        'thueGiamTruDienThoai': int.tryParse((controllers['thueGiamTruDienThoai'] as TextEditingController).text) ?? 0,
        'thueGiamTruAn': int.tryParse((controllers['thueGiamTruAn'] as TextEditingController).text) ?? 0,
        'thueGiamTruXangXe': int.tryParse((controllers['thueGiamTruXangXe'] as TextEditingController).text) ?? 0,
      };

      final response = await http.post(
        Uri.parse(isEdit ? '$baseUrl/paypolicy/update' : '$baseUrl/paypolicy/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEdit ? 'Cập nhật chế độ lương thành công' : 'Tạo chế độ lương thành công'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {});
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEdit ? 'Lỗi khi cập nhật chế độ lương' : 'Lỗi khi tạo chế độ lương'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi kết nối'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}