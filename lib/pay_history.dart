import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PayHistoryScreen extends StatefulWidget {
  final String username;
  final String userRole;
  final List<Map<String, dynamic>> historyData;

  const PayHistoryScreen({
    Key? key,
    required this.username,
    required this.userRole,
    required this.historyData,
  }) : super(key: key);

  @override
  _PayHistoryScreenState createState() => _PayHistoryScreenState();
}
class _PayHistoryScreenState extends State<PayHistoryScreen> {
  String _selectedPeriod = 'Tất cả';
  final List<String> _periodOptions = ['Tất cả', '3 tháng gần nhất', '6 tháng gần nhất', 'Năm nay', 'Năm trước'];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'Giai đoạn mới nhất';
  final List<String> _sortOptions = ['Giai đoạn mới nhất', 'Giai đoạn cũ nhất', 'Lương cao nhất', 'Lương thấp nhất', 'Tên A-Z'];
  String _selectedDepartment = 'Tất cả';
  List<String> _departmentOptions = ['Tất cả'];

  @override
  void initState() {
    super.initState();
    _initializeDepartments();
  }

  void _initializeDepartments() {
    final departments = widget.historyData
        .map((item) => item['phanNhom']?.toString() ?? 'Không xác định')
        .toSet()
        .toList();
    departments.sort();
    setState(() {
      _departmentOptions = ['Tất cả'] + departments;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isHR = widget.userRole == 'Admin' || widget.userRole == 'HR';
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('${isHR ? "Lịch sử lương HR" : "Lịch sử lương KT"} - ${widget.username}'),
        backgroundColor: isHR ? Colors.blue[600] : Colors.green[600],
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showStatisticsDialog,
            tooltip: 'Thống kê',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportData,
            tooltip: 'Xuất dữ liệu',
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildSearchCard(),
            const SizedBox(height: 16),
            _buildFilterCard(),
            const SizedBox(height: 16),
            _buildDataTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final totalRecords = widget.historyData.length;
final totalSalary = widget.historyData.fold<int>(0, (sum, item) => sum + ((item['tongThucNhan'] ?? 0) as int));
    final avgSalary = totalRecords > 0 ? totalSalary / totalRecords : 0;
    final isHR = widget.userRole == 'Admin' || widget.userRole == 'HR';

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
              Icon(Icons.history, color: isHR ? Colors.blue[600] : Colors.green[600], size: 24),
              const SizedBox(width: 8),
              Text(
                'Thông tin lịch sử lương',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isHR ? Colors.blue[600] : Colors.green[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInfoItem('Người dùng', widget.username, Icons.person)),
              Expanded(child: _buildInfoItem('Vai trò', widget.userRole, Icons.security)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInfoItem('Tổng bản ghi', '$totalRecords', Icons.receipt_long)),
              Expanded(child: _buildInfoItem('Lương TB', NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(avgSalary), Icons.attach_money)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
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
              hintText: 'Tìm theo tên, mã NV, tài khoản...',
              prefixIcon: Icon(Icons.search, color: widget.userRole == 'Admin' || widget.userRole == 'HR' ? Colors.blue[600] : Colors.green[600]),
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
              Icon(Icons.sort, color: widget.userRole == 'Admin' || widget.userRole == 'HR' ? Colors.blue[600] : Colors.green[600], size: 20),
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
            'Bộ lọc',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: widget.userRole == 'Admin' || widget.userRole == 'HR' ? Colors.blue[600] : Colors.green[600],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thời gian:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                    const SizedBox(height: 4),
                    DropdownButton<String>(
                      value: _selectedPeriod,
                      isExpanded: true,
                      onChanged: (value) {
                        setState(() {
                          _selectedPeriod = value!;
                        });
                      },
                      items: _periodOptions.map((option) {
                        return DropdownMenuItem(
                          value: option,
                          child: Text(option, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Phòng ban:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                    const SizedBox(height: 4),
                    DropdownButton<String>(
                      value: _selectedDepartment,
                      isExpanded: true,
                      onChanged: (value) {
                        setState(() {
                          _selectedDepartment = value!;
                        });
                      },
                      items: _departmentOptions.map((option) {
                        return DropdownMenuItem(
                          value: option,
                          child: Text(option, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
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
                color: widget.userRole == 'Admin' || widget.userRole == 'HR' ? Colors.blue[50] : Colors.green[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.table_chart, color: widget.userRole == 'Admin' || widget.userRole == 'HR' ? Colors.blue[600] : Colors.green[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Lịch sử thanh toán lương',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: widget.userRole == 'Admin' || widget.userRole == 'HR' ? Colors.blue[600] : Colors.green[600],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${filteredData.length} bản ghi',
                    style: TextStyle(
                      color: widget.userRole == 'Admin' || widget.userRole == 'HR' ? Colors.blue[600] : Colors.green[600],
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
                        final history = filteredData[index];
                        return _buildHistoryItem(history, index);
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
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Không có dữ liệu lịch sử lương phù hợp',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> history, int index) {
    final uid = history['uid']?.toString() ?? 'N/A';
    final giaiDoan = history['giaiDoan']?.toString() ?? 'N/A';
    final maNhanVien = history['maNhanVien']?.toString() ?? 'N/A';
    final tenNhanVien = history['tenNhanVien']?.toString() ?? 'N/A';
    final phanNhom = history['phanNhom']?.toString() ?? 'N/A';
    final tongThucNhan = (history['tongThucNhan'] ?? 0);
    final mucLuongChinh = (history['mucLuongChinh'] ?? 0);
    final soTaiKhoan = history['soTaiKhoan']?.toString() ?? 'N/A';
    
    String formattedDate = 'N/A';
    try {
      if (giaiDoan != 'N/A') {
        final date = DateTime.parse(giaiDoan);
        formattedDate = DateFormat('MM/yyyy').format(date);
      }
    } catch (e) {
      formattedDate = giaiDoan;
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
            color: _getSalaryRangeColor(tongThucNhan),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatCurrency(tongThucNhan),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                formattedDate,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
        title: Text(
          '$tenNhanVien ($maNhanVien)',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.business, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              phanNhom,
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
            const SizedBox(width: 12),
            Icon(Icons.account_balance, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                soTaiKhoan,
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSalaryDetailsCard(history),
                const SizedBox(height: 16),
                _buildWorkDetailsCard(history),
                const SizedBox(height: 16),
                _buildPaymentDetailsCard(history),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryDetailsCard(Map<String, dynamic> history) {
    final mucLuongChinh = (history['mucLuongChinh'] ?? 0);
    final thanhTienCongLe = (history['thanhTienCongLe'] ?? 0);
    final thanhTienTangCa = (history['thanhTienTangCa'] ?? 0);
    final phuCapDienThoai = (history['phuCapDienThoai'] ?? 0);
    final phuCapGuiXe = (history['phuCapGuiXe'] ?? 0);
    final phuCapAnUong = (history['phuCapAnUong'] ?? 0);
    final truBhxh = (history['truBhxh'] ?? 0);
    final truCongDoan = (history['truCongDoan'] ?? 0);
    final tongThucNhan = (history['tongThucNhan'] ?? 0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_money, color: Colors.blue[600], size: 16),
              const SizedBox(width: 4),
              Text('Chi tiết lương', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[600])),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thu nhập:', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.green[700], fontSize: 12)),
                    Text('• Lương cơ bản: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(mucLuongChinh)}', style: const TextStyle(fontSize: 11)),
                    Text('• Tiền công lẻ: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(thanhTienCongLe)}', style: const TextStyle(fontSize: 11)),
                    Text('• Tiền tăng ca: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(thanhTienTangCa)}', style: const TextStyle(fontSize: 11)),
                    Text('• PC điện thoại: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(phuCapDienThoai)}', style: const TextStyle(fontSize: 11)),
                    Text('• PC gửi xe: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(phuCapGuiXe)}', style: const TextStyle(fontSize: 11)),
                    Text('• PC ăn uống: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(phuCapAnUong)}', style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Khấu trừ:', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red[700], fontSize: 12)),
                    Text('• BHXH: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(truBhxh)}', style: const TextStyle(fontSize: 11)),
                    Text('• Công đoàn: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(truCongDoan)}', style: const TextStyle(fontSize: 11)),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Thực nhận:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[600])),
              Text(
                NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(tongThucNhan),
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[600], fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkDetailsCard(Map<String, dynamic> history) {
    final tongCongGoc = (history['tongCongGoc'] ?? 0).toDouble();
    final tongCongSua = (history['tongCongSua'] ?? 0).toDouble();
    final tongTangCaGoc = (history['tongTangCaGoc'] ?? 0).toDouble();
    final tongTangCaSua = (history['tongTangCaSua'] ?? 0).toDouble();
    final phutDiMuonGoc = (history['phutDiMuonGoc'] ?? 0);
    final phutDiMuonSua = (history['phutDiMuonSua'] ?? 0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.work, color: Colors.orange[600], size: 16),
              const SizedBox(width: 4),
              Text('Thông tin công việc', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[600])),
            ],
          ),
          const SizedBox(height: 8),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                children: [
                  Text('', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  Text('Gốc', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orange[700])),
                  Text('Sửa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orange[700])),
                ],
              ),
              TableRow(
                children: [
                  Text('Tổng công:', style: TextStyle(fontSize: 11)),
                  Text('${tongCongGoc.toStringAsFixed(1)}', style: TextStyle(fontSize: 11)),
                  Text('${tongCongSua.toStringAsFixed(1)}', style: TextStyle(fontSize: 11)),
                ],
              ),
              TableRow(
                children: [
                  Text('Tăng ca:', style: TextStyle(fontSize: 11)),
                  Text('${tongTangCaGoc.toStringAsFixed(1)}h', style: TextStyle(fontSize: 11)),
                  Text('${tongTangCaSua.toStringAsFixed(1)}h', style: TextStyle(fontSize: 11)),
                ],
              ),
              TableRow(
                children: [
                  Text('Đi muộn:', style: TextStyle(fontSize: 11)),
                  Text('${phutDiMuonGoc}p', style: TextStyle(fontSize: 11)),
                  Text('${phutDiMuonSua}p', style: TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailsCard(Map<String, dynamic> history) {
    final thanhToanLan1 = (history['thanhToanLan1'] ?? 0);
    final thanhToanLan2 = (history['thanhToanLan2'] ?? 0);
    final hinhThucLan1 = (history['hinhThucLan1'] ?? 0);
    final hinhThucLan2 = (history['hinhThucLan2'] ?? 0);
    final ghiChu = history['ghiChu']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: Colors.green[600], size: 16),
              const SizedBox(width: 4),
              Text('Thông tin thanh toán', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[600])),
            ],
          ),
          const SizedBox(height: 8),
          if (thanhToanLan1 > 0)
            Text('Thanh toán lần 1: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(thanhToanLan1)} (${_getPaymentMethod(hinhThucLan1)})', style: const TextStyle(fontSize: 11)),
          if (thanhToanLan2 > 0)
            Text('Thanh toán lần 2: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(thanhToanLan2)} (${_getPaymentMethod(hinhThucLan2)})', style: const TextStyle(fontSize: 11)),
          if (ghiChu.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Ghi chú: $ghiChu', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey[600])),
            ),
        ],
      ),
    );
  }

  String _getPaymentMethod(int method) {
    switch (method) {
      case 1:
        return 'Tiền mặt';
      case 2:
        return 'Chuyển khoản';
      case 3:
        return 'Thẻ ATM';
      default:
        return 'Không xác định';
    }
  }

  Color _getSalaryRangeColor(int salary) {
    if (salary >= 20000000) return Colors.purple[600]!; // 20M+
    if (salary >= 15000000) return Colors.blue[600]!;   // 15M-20M
    if (salary >= 10000000) return Colors.green[600]!;  // 10M-15M
    if (salary >= 5000000) return Colors.orange[600]!;  // 5M-10M
    return Colors.grey[600]!;                           // <5M
  }

  String _formatCurrency(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toString();
  }

  List<Map<String, dynamic>> _getFilteredAndSortedData() {
    var filtered = widget.historyData;
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((history) {
        final tenNhanVien = history['tenNhanVien']?.toString().toLowerCase() ?? '';
        final maNhanVien = history['maNhanVien']?.toString().toLowerCase() ?? '';
        final soTaiKhoan = history['soTaiKhoan']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return tenNhanVien.contains(query) || maNhanVien.contains(query) || soTaiKhoan.contains(query);
      }).toList();
    }
    
    // Apply department filter
    if (_selectedDepartment != 'Tất cả') {
      filtered = filtered.where((history) {
        final phanNhom = history['phanNhom']?.toString() ?? '';
        return phanNhom == _selectedDepartment;
      }).toList();
    }
    
    // Apply period filter
    if (_selectedPeriod != 'Tất cả') {
      final now = DateTime.now();
      filtered = filtered.where((history) {
        try {
          final giaiDoan = history['giaiDoan']?.toString();
          if (giaiDoan == null) return false;
          
          final date = DateTime.parse(giaiDoan);
          switch (_selectedPeriod) {
            case '3 tháng gần nhất':
              return date.isAfter(now.subtract(const Duration(days: 90)));
            case '6 tháng gần nhất':
              return date.isAfter(now.subtract(const Duration(days: 180)));
            case 'Năm nay':
              return date.year == now.year;
            case 'Năm trước':
              return date.year == now.year - 1;
            default:
              return true;
          }
        } catch (e) {
          return false;
        }
      }).toList();
    }
    
    // Apply sorting
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'Giai đoạn mới nhất':
          try {
            final dateA = DateTime.parse(a['giaiDoan']?.toString() ?? '');
            final dateB = DateTime.parse(b['giaiDoan']?.toString() ?? '');
            return dateB.compareTo(dateA);
          } catch (e) {
            return 0;
          }
        case 'Giai đoạn cũ nhất':
          try {
            final dateA = DateTime.parse(a['giaiDoan']?.toString() ?? '');
            final dateB = DateTime.parse(b['giaiDoan']?.toString() ?? '');
            return dateA.compareTo(dateB);
          } catch (e) {
            return 0;
          }
        case 'Lương cao nhất':
          final salaryA = a['tongThucNhan'] ?? 0;
          final salaryB = b['tongThucNhan'] ?? 0;
          return salaryB.compareTo(salaryA);
        case 'Lương thấp nhất':
          final salaryA = a['tongThucNhan'] ?? 0;
          final salaryB = b['tongThucNhan'] ?? 0;
          return salaryA.compareTo(salaryB);
        case 'Tên A-Z':
          final nameA = a['tenNhanVien']?.toString().toLowerCase() ?? '';
          final nameB = b['tenNhanVien']?.toString().toLowerCase() ?? '';
          return nameA.compareTo(nameB);
        default:
          return 0;
      }
    });
    
    return filtered;
  }

  void _showStatisticsDialog() {
    final filteredData = _getFilteredAndSortedData();
    final totalRecords = filteredData.length;
final totalSalary = filteredData.fold<int>(0, (sum, item) => sum + ((item['tongThucNhan'] ?? 0) as int));
    final avgSalary = totalRecords > 0 ? totalSalary / totalRecords : 0;
    final maxSalary = filteredData.isEmpty ? 0 : 
        filteredData.map((p) => p['tongThucNhan'] ?? 0).reduce((a, b) => a > b ? a : b);
    final minSalary = filteredData.isEmpty ? 0 : 
        filteredData.map((p) => p['tongThucNhan'] ?? 0).reduce((a, b) => a < b ? a : b);

    // Department statistics
    final departmentStats = <String, Map<String, dynamic>>{};
    for (final item in filteredData) {
      final dept = item['phanNhom']?.toString() ?? 'Không xác định';
      if (!departmentStats.containsKey(dept)) {
        departmentStats[dept] = {'count': 0, 'totalSalary': 0};
      }
      departmentStats[dept]!['count']++;
      departmentStats[dept]!['totalSalary'] += (item['tongThucNhan'] ?? 0);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Thống kê lịch sử lương'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📊 Tổng quan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[600])),
              Text('• Tổng bản ghi: $totalRecords'),
              Text('• Tổng chi phí: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalSalary)}'),
              const Divider(),
              Text('💰 Thống kê lương', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[600])),
              Text('• Lương trung bình: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(avgSalary)}'),
              Text('• Lương cao nhất: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(maxSalary)}'),
              Text('• Lương thấp nhất: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(minSalary)}'),
              const Divider(),
              Text('🏢 Theo phòng ban', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[600])),
              ...departmentStats.entries.map((entry) {
                final avgDeptSalary = entry.value['totalSalary'] / entry.value['count'];
                return Text('• ${entry.key}: ${entry.value['count']} NV - TB: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(avgDeptSalary)}');
              }),
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

  void _exportData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xuất dữ liệu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Xuất Excel'),
              subtitle: const Text('Tạo file Excel với dữ liệu hiện tại'),
              onTap: () {
                Navigator.pop(context);
                _showExportConfirmation('Excel');
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Xuất PDF'),
              subtitle: const Text('Tạo báo cáo PDF chi tiết'),
              onTap: () {
                Navigator.pop(context);
                _showExportConfirmation('PDF');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }

  void _showExportConfirmation(String format) {
    final filteredData = _getFilteredAndSortedData();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xuất $format'),
        content: Text('Bạn muốn xuất ${filteredData.length} bản ghi ra file $format?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Chức năng xuất $format sẽ được phát triển trong phiên bản tiếp theo'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            child: const Text('Xuất'),
          ),
        ],
      ),
    );
  }
}

class PayrollCreationScreen extends StatefulWidget {
  final String username;
  final String userRole;
  final List<Map<String, dynamic>> payrollRecords;
  final String selectedMonth;
  final String selectedBranch;

  const PayrollCreationScreen({
    Key? key,
    required this.username,
    required this.userRole,
    required this.payrollRecords,
    required this.selectedMonth,
    required this.selectedBranch,
  }) : super(key: key);

  @override
  _PayrollCreationScreenState createState() => _PayrollCreationScreenState();
}

class _PayrollCreationScreenState extends State<PayrollCreationScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _selectedRecords = [];
  List<Map<String, dynamic>> _existingRecords = [];
  Map<String, String> _recordStatus = {}; // 'create', 'update', 'exists'
  bool _allSelected = true;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _selectedRecords = List.from(widget.payrollRecords);
    _checkExistingRecords();
  }

  Future<void> _checkExistingRecords() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang kiểm tra bản ghi hiện có...';
    });

    try {
      final url = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/paycheck');
      final requestBody = {
        'username': widget.username,
        'period': widget.selectedMonth,
        'branch': widget.selectedBranch,
        'userIds': widget.payrollRecords.map((r) => r['userId']).toList(),
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          _existingRecords = data.cast<Map<String, dynamic>>();
        }
      }

      // Determine status for each record
      _recordStatus.clear();
      for (final record in _selectedRecords) {
        final userId = record['userId'];
        final existing = _existingRecords.firstWhere(
          (r) => r['userId'] == userId && r['giaiDoan'] == record['giaiDoan'],
          orElse: () => <String, dynamic>{},
        );

        if (existing.isNotEmpty) {
          _recordStatus[userId] = 'update';
          // Update the record with existing ID for update operation
          record['id'] = existing['id'];
        } else {
          _recordStatus[userId] = 'create';
        }
      }

      setState(() {
        _isLoading = false;
        _statusMessage = _buildStatusMessage();
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Lỗi khi kiểm tra dữ liệu: $e';
      });
      
      // Default to create for all records if check fails
      for (final record in _selectedRecords) {
        _recordStatus[record['userId']] = 'create';
      }
    }
  }

  String _buildStatusMessage() {
    final createCount = _recordStatus.values.where((s) => s == 'create').length;
    final updateCount = _recordStatus.values.where((s) => s == 'update').length;
    
    return 'Tìm thấy: $createCount bản ghi mới, $updateCount bản ghi cập nhật';
  }

  void _toggleRecordSelection(int index, bool selected) {
    setState(() {
      if (selected) {
        final record = widget.payrollRecords[index];
        if (!_selectedRecords.any((r) => r['userId'] == record['userId'])) {
          _selectedRecords.add(record);
        }
      } else {
        _selectedRecords.removeWhere((r) => r['userId'] == widget.payrollRecords[index]['userId']);
      }
      _updateSelectAllState();
    });
  }

  void _toggleSelectAll(bool selectAll) {
    setState(() {
      _allSelected = selectAll;
      if (selectAll) {
        _selectedRecords = List.from(widget.payrollRecords);
      } else {
        _selectedRecords.clear();
      }
    });
  }

  void _updateSelectAllState() {
    _allSelected = _selectedRecords.length == widget.payrollRecords.length;
  }

  Future<void> _showConfirmationDialog() async {
    if (_selectedRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một bản ghi để xử lý'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final createCount = _selectedRecords.where((r) => _recordStatus[r['userId']] == 'create').length;
    final updateCount = _selectedRecords.where((r) => _recordStatus[r['userId']] == 'update').length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận gửi dữ liệu lương'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sẽ xử lý ${_selectedRecords.length} bản ghi:'),
            const SizedBox(height: 8),
            if (createCount > 0)
              Text('• Tạo mới: $createCount bản ghi', style: TextStyle(color: Colors.green[700])),
            if (updateCount > 0)
              Text('• Cập nhật: $updateCount bản ghi', style: TextStyle(color: Colors.blue[700])),
            const SizedBox(height: 16),
            const Text('Bạn có chắc chắn muốn tiếp tục?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Xác nhận gửi'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _submitPayrollData();
    }
  }

  Future<void> _submitPayrollData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang gửi dữ liệu lương...';
    });

    try {
      final url = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/paycreation');
      final requestBody = {
        'username': widget.username,
        'userRole': widget.userRole,
        'selectedMonth': widget.selectedMonth,
        'selectedBranch': widget.selectedBranch,
        'records': _selectedRecords,
        'submittedAt': DateTime.now().toIso8601String(),
      };

      print('Sending request to: $url');
      print('Request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gửi dữ liệu lương thành công! Đã xử lý ${_selectedRecords.length} bản ghi.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Navigate to success screen or pay history
        _showSuccessDialog();

      } else {
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Lỗi khi gửi dữ liệu: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi gửi dữ liệu lương: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Thành công'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Đã gửi dữ liệu lương tháng ${widget.selectedMonth} thành công!'),
            const SizedBox(height: 8),
            Text('Số bản ghi đã xử lý: ${_selectedRecords.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
              Navigator.pop(context); // Go back to main screen
            },
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => PayHistoryScreen(
                    username: widget.username,
                    userRole: widget.userRole,
                    historyData: _selectedRecords,
                  ),
                ),
              );
            },
            child: const Text('Xem lịch sử lương'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(Map<String, dynamic> record, int index) {
    final userId = record['userId'];
    final isSelected = _selectedRecords.any((r) => r['userId'] == userId);
    final status = _recordStatus[userId] ?? 'create';
    
    Color statusColor = status == 'create' ? Colors.green : Colors.blue;
    String statusText = status == 'create' ? 'Tạo mới' : 'Cập nhật';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: Checkbox(
          value: isSelected,
          onChanged: (value) => _toggleRecordSelection(index, value ?? false),
        ),
        title: Text(
          '${record['tenNhanVien']} (${record['maNhanVien']})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phòng ban: ${record['phanNhom'] ?? 'N/A'}'),
            Text('Tổng công: ${record['tongCongGoc']} | Tăng ca: ${record['tongTangCaGoc']}h'),
            Text('Đi muộn: ${record['phutDiMuonGoc']}p | Trừ tiền: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(record['truDiMuonGoc'])}'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Tạo lịch sử lương'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          if (!_isLoading && _selectedRecords.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: _showConfirmationDialog,
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Xác nhận gửi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusMessage),
                ],
              ),
            )
          : Column(
              children: [
                // Header Card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
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
                        'Thông tin tạo lịch sử lương',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tháng: ${widget.selectedMonth}', style: const TextStyle(fontSize: 14)),
                                Text('Chi nhánh: ${widget.selectedBranch}', style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tổng NV: ${widget.payrollRecords.length}', style: const TextStyle(fontSize: 14)),
                                Text('Đã chọn: ${_selectedRecords.length}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_statusMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Select All Checkbox
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: CheckboxListTile(
                    title: const Text('Chọn tất cả', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${_selectedRecords.length}/${widget.payrollRecords.length} bản ghi được chọn'),
                    value: _allSelected,
                    onChanged: (value) => _toggleSelectAll(value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),

                const Divider(),

                // Records List
                Expanded(
                  child: widget.payrollRecords.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Không có dữ liệu lương để xử lý',
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: widget.payrollRecords.length,
                          itemBuilder: (context, index) {
                            final record = widget.payrollRecords[index];
                            return _buildRecordItem(record, index);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}