import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PayPolicyScreen extends StatefulWidget {
  final String username;
  final String userRole;
  final List<Map<String, dynamic>> policyData;

  const PayPolicyScreen({
    Key? key,
    required this.username,
    required this.userRole,
    required this.policyData,
  }) : super(key: key);

  @override
  _PayPolicyScreenState createState() => _PayPolicyScreenState();
}

class _PayPolicyScreenState extends State<PayPolicyScreen> {
  String _selectedFilter = 'Tất cả';
  final List<String> _filterOptions = ['Tất cả', 'Đang thử việc', 'Chính thức', 'Tăng ca cố định', 'Khác'];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'Ngày mới nhất';
  final List<String> _sortOptions = ['Ngày mới nhất', 'Ngày cũ nhất', 'Lương cao nhất', 'Lương thấp nhất'];

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
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showStatisticsDialog,
            tooltip: 'Thống kê',
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildSearchAndSortCard(),
            const SizedBox(height: 16),
            _buildFilterCard(),
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
    final totalRecords = widget.policyData.length;
final avgSalary = totalRecords > 0 ? 
    widget.policyData.fold<int>(0, (sum, item) => sum + ((item['mucLuongChinh'] ?? 0) as int)) / totalRecords : 0;

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
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('Tổng chế độ', '$totalRecords', Icons.business_center),
              ),
              Expanded(
                child: _buildInfoItem(
                  'Lương TB', 
                  NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(avgSalary),
                  Icons.attach_money,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSortCard() {
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
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Tìm kiếm',
              hintText: 'Tìm theo UID, User ID...',
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
                borderSide: BorderSide(color: Colors.deepPurple[300]!),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.sort, color: Colors.deepPurple[600], size: 20),
              const SizedBox(width: 8),
              const Text('Sắp xếp:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _sortBy,
                  isExpanded: true,
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                    });
                  },
                  items: _sortOptions.map((option) {
                    return DropdownMenuItem(
                      value: option,
                      child: Text(option, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
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

  Widget _buildFilterCard() {
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
          Text(
            'Lọc theo trạng thái',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple[600],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _filterOptions.map((filter) {
              final isSelected = _selectedFilter == filter;
              return FilterChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
                selectedColor: Colors.deepPurple[100],
                checkmarkColor: Colors.deepPurple[600],
                labelStyle: TextStyle(
                  color: isSelected ? Colors.deepPurple[600] : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    final filteredData = _getFilteredAndSortedData();
    
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
                    '${filteredData.length} chế độ',
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
                  : ListView.builder(
                      padding: const EdgeInsets.all(0),
                      itemCount: filteredData.length,
                      itemBuilder: (context, index) {
                        final policy = filteredData[index];
                        return _buildPolicyItem(policy, index);
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
          Icon(Icons.policy, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Không có dữ liệu chế độ lương phù hợp',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          if (widget.userRole == 'Admin' || widget.userRole == 'AC')
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: _showAddPolicyDialog,
                icon: const Icon(Icons.add_business),
                label: const Text('Thêm chế độ mới'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPolicyItem(Map<String, dynamic> policy, int index) {
    final uid = policy['uid']?.toString() ?? 'N/A';
    final userId = policy['userId']?.toString() ?? 'N/A';
    final ngay = policy['ngay']?.toString() ?? 'N/A';
    final loaiCong = policy['loaiCong']?.toString() ?? 'N/A';
    final mucLuongChinh = (policy['mucLuongChinh'] ?? 0);
    final dangThuViec = policy['dangThuViec']?.toString() ?? 'N/A';
    final hinhThucTangCa = policy['hinhThucTangCa']?.toString() ?? 'N/A';
    
    String formattedDate = 'N/A';
    try {
      if (ngay != 'N/A') {
        final date = DateTime.parse(ngay);
        formattedDate = DateFormat('dd/MM/yyyy').format(date);
      }
    } catch (e) {
      formattedDate = ngay;
    }

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
            color: _getStatusColor(dangThuViec),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getStatusIcon(dangThuViec),
                color: Colors.white,
                size: 16,
              ),
              Text(
                _getStatusShort(dangThuViec),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        title: Text(
          'User: $userId',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.attach_money, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(mucLuongChinh),
              style: TextStyle(
                color: Colors.grey[600], 
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              formattedDate,
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ],
        ),
        trailing: (widget.userRole == 'Admin' || widget.userRole == 'AC')
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
                    value: 'copy',
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 16),
                        SizedBox(width: 8),
                        Text('Sao chép'),
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
                  switch (value) {
                    case 'edit':
                      _showEditPolicyDialog(policy);
                      break;
                    case 'copy':
                      _showCopyPolicyDialog(policy);
                      break;
                    case 'delete':
                      _showDeleteConfirmation(policy);
                      break;
                  }
                },
              )
            : null,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSalaryBreakdown(policy),
                const SizedBox(height: 16),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(2),
                  },
                  children: [
                    _buildTableRow('UID', uid),
                    _buildTableRow('User ID', userId),
                    _buildTableRow('Ngày áp dụng', formattedDate),
                    _buildTableRow('Loại công', loaiCong),
                    _buildTableRow('Mức lương chính', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(mucLuongChinh)),
                    _buildTableRow('Trạng thái', dangThuViec == 'Y' ? 'Đang thử việc' : 'Chính thức'),
                    _buildTableRow('Hình thức tăng ca', hinhThucTangCa),
                    _buildTableRow('BHXH', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['mucBhxh'] ?? 0)),
                    _buildTableRow('Công đoàn', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['mucCongDoan'] ?? 0)),
                    _buildTableRow('Phụ cấp điện thoại', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['phuCapDienThoai'] ?? 0)),
                    _buildTableRow('Phụ cấp gửi xe', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['phuCapGuiXe'] ?? 0)),
                    _buildTableRow('Phụ cấp ăn uống', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(policy['phuCapAnUong'] ?? 0)),
                    _buildTableRow('Số người phụ thuộc', '${policy['soNguoiPhuThuoc'] ?? 0}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryBreakdown(Map<String, dynamic> policy) {
    final basicSalary = (policy['mucLuongChinh'] ?? 0);
    final phoneAllowance = (policy['phuCapDienThoai'] ?? 0);
    final parkingAllowance = (policy['phuCapGuiXe'] ?? 0);
    final mealAllowance = (policy['phuCapAnUong'] ?? 0);
    final clothingAllowance = (policy['phuCapTrangPhuc'] ?? 0);
    final otherSupport = (policy['hoTroKhac'] ?? 0);
    final otherAdjustment = (policy['dieuChinhKhac'] ?? 0);
    
    final totalGross = basicSalary + phoneAllowance + parkingAllowance + 
                      mealAllowance + clothingAllowance + otherSupport + otherAdjustment;
    
    final bhxhDeduction = (policy['truBhxh'] ?? 0);
    final unionDeduction = (policy['truCongDoan'] ?? 0);
    final totalDeductions = bhxhDeduction + unionDeduction;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cấu trúc lương',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.deepPurple[600],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thu nhập:', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.green[700])),
                    Text('• Lương cơ bản: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(basicSalary)}', style: const TextStyle(fontSize: 12)),
                    Text('• PC điện thoại: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(phoneAllowance)}', style: const TextStyle(fontSize: 12)),
                    Text('• PC gửi xe: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(parkingAllowance)}', style: const TextStyle(fontSize: 12)),
                    Text('• PC ăn uống: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(mealAllowance)}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Khấu trừ:', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red[700])),
                    Text('• BHXH: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(bhxhDeduction)}', style: const TextStyle(fontSize: 12)),
                    Text('• Công đoàn: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(unionDeduction)}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng thu nhập:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
              ),
              Text(
                NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalGross),
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng khấu trừ:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700]),
              ),
              Text(
                NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalDeductions),
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700]),
              ),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Thực nhận ước tính:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple[600]),
              ),
              Text(
                NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalGross - totalDeductions),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple[600]),
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

  Color _getStatusColor(String status) {
    if (status == 'Y' || status.toLowerCase() == 'yes') {
      return Colors.orange[600]!; // Trial period
    }
    return Colors.green[600]!; // Official
  }

  IconData _getStatusIcon(String status) {
    if (status == 'Y' || status.toLowerCase() == 'yes') {
      return Icons.hourglass_empty; // Trial period
    }
    return Icons.verified; // Official
  }

  String _getStatusShort(String status) {
    if (status == 'Y' || status.toLowerCase() == 'yes') {
      return 'Thử việc';
    }
    return 'Chính thức';
  }

  List<Map<String, dynamic>> _getFilteredAndSortedData() {
    var filtered = widget.policyData;
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((policy) {
        final uid = policy['uid']?.toString().toLowerCase() ?? '';
        final userId = policy['userId']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return uid.contains(query) || userId.contains(query);
      }).toList();
    }
    
    // Apply status filter
    if (_selectedFilter != 'Tất cả') {
      filtered = filtered.where((policy) {
        final dangThuViec = policy['dangThuViec']?.toString().toLowerCase() ?? '';
        final hinhThucTangCa = policy['hinhThucTangCa']?.toString().toLowerCase() ?? '';
        
        switch (_selectedFilter) {
          case 'Đang thử việc':
            return dangThuViec == 'y' || dangThuViec == 'yes';
          case 'Chính thức':
            return dangThuViec != 'y' && dangThuViec != 'yes';
          case 'Tăng ca cố định':
            return hinhThucTangCa.contains('cố định') || hinhThucTangCa.contains('fixed');
          case 'Khác':
            return !hinhThucTangCa.contains('cố định') && !hinhThucTangCa.contains('fixed');
          default:
            return true;
        }
      }).toList();
    }
    
    // Apply sorting
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'Ngày mới nhất':
          try {
            final dateA = DateTime.parse(a['ngay']?.toString() ?? '');
            final dateB = DateTime.parse(b['ngay']?.toString() ?? '');
            return dateB.compareTo(dateA);
          } catch (e) {
            return 0;
          }
        case 'Ngày cũ nhất':
          try {
            final dateA = DateTime.parse(a['ngay']?.toString() ?? '');
            final dateB = DateTime.parse(b['ngay']?.toString() ?? '');
            return dateA.compareTo(dateB);
          } catch (e) {
            return 0;
          }
        case 'Lương cao nhất':
          final salaryA = a['mucLuongChinh'] ?? 0;
          final salaryB = b['mucLuongChinh'] ?? 0;
          return salaryB.compareTo(salaryA);
        case 'Lương thấp nhất':
          final salaryA = a['mucLuongChinh'] ?? 0;
          final salaryB = b['mucLuongChinh'] ?? 0;
          return salaryA.compareTo(salaryB);
        default:
          return 0;
      }
    });
    
    return filtered;
  }

  void _showAddPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm chế độ lương'),
        content: const Text('Chức năng thêm chế độ lương mới sẽ được phát triển trong phiên bản tiếp theo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showEditPolicyDialog(Map<String, dynamic> policy) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa chế độ lương'),
        content: Text('Chỉnh sửa chế độ cho User: ${policy['userId']}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chức năng chỉnh sửa sẽ được phát triển')),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
void _showCopyPolicyDialog(Map<String, dynamic> policy) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sao chép chế độ lương'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sao chép chế độ lương từ User: ${policy['userId']}'),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'User ID mới',
                hintText: 'Nhập User ID để áp dụng chế độ này',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chức năng sao chép sẽ được phát triển')),
              );
            },
            child: const Text('Sao chép'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> policy) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa chế độ lương của User: ${policy['userId']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã xóa chế độ lương thành công'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showStatisticsDialog() {
    final totalRecords = widget.policyData.length;
    final trialEmployees = widget.policyData.where((p) => p['dangThuViec']?.toString() == 'Y').length;
    final officialEmployees = totalRecords - trialEmployees;
    
final totalSalary = widget.policyData.fold<int>(0, (sum, item) => sum + ((item['mucLuongChinh'] ?? 0) as int));
    final avgSalary = totalRecords > 0 ? totalSalary / totalRecords : 0;
    final maxSalary = widget.policyData.isEmpty ? 0 : 
        widget.policyData.map((p) => p['mucLuongChinh'] ?? 0).reduce((a, b) => a > b ? a : b);
    final minSalary = widget.policyData.isEmpty ? 0 : 
        widget.policyData.map((p) => p['mucLuongChinh'] ?? 0).reduce((a, b) => a < b ? a : b);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thống kê chế độ lương'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📊 Tổng quan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple[600])),
              Text('• Tổng số chế độ: $totalRecords'),
              Text('• Nhân viên chính thức: $officialEmployees'),
              Text('• Nhân viên thử việc: $trialEmployees'),
              const Divider(),
              Text('💰 Thống kê lương', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple[600])),
              Text('• Lương trung bình: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(avgSalary)}'),
              Text('• Lương cao nhất: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(maxSalary)}'),
              Text('• Lương thấp nhất: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(minSalary)}'),
              Text('• Tổng chi phí lương: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalSalary)}'),
              const Divider(),
              Text('📈 Phân tích', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple[600])),
              Text('• Tỉ lệ thử việc: ${totalRecords > 0 ? (trialEmployees/totalRecords*100).toStringAsFixed(1) : 0}%'),
              Text('• Tỉ lệ chính thức: ${totalRecords > 0 ? (officialEmployees/totalRecords*100).toStringAsFixed(1) : 0}%'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
