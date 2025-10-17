import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'db_helper.dart';
import 'table_models.dart';
import 'hd_yeucaumaymoi.dart';

class HDYeuCauMayQuanLyScreen extends StatefulWidget {
  final String username;
  final String userRole;
  final String currentPeriod;
  final String nextPeriod;

  const HDYeuCauMayQuanLyScreen({
    Key? key,
    required this.username,
    required this.userRole,
    required this.currentPeriod,
    required this.nextPeriod,
  }) : super(key: key);

  @override
  _HDYeuCauMayQuanLyScreenState createState() => _HDYeuCauMayQuanLyScreenState();
}

class _HDYeuCauMayQuanLyScreenState extends State<HDYeuCauMayQuanLyScreen> {
  final DBHelper _dbHelper = DBHelper();
  final String baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  final List<String> _managerApprovers = ['hm.tason', 'hm.tranminh'];
  final List<String> _financeApprovers = ['hm.tason', 'hm.luukinh'];
  
  List<LinkYeuCauMayModel> _allRequests = [];
  List<LinkYeuCauMayModel> _filteredRequests = [];
  Map<String, List<LinkYeuCauMayChiTietModel>> _requestDetails = {};
  
  bool _isLoading = true;
  bool _isProcessing = false;
  String _selectedFilter = 'Tất cả';
  final List<String> _filterOptions = ['Tất cả', 'Nháp', 'Chờ duyệt TPKD', 'Chờ duyệt KT', 'Đã duyệt', 'Từ chối'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });
    try {
      final requests = await _dbHelper.getAllLinkYeuCauMays();
      final allDetails = await _dbHelper.getAllLinkYeuCauMayChiTiets();
      
      final detailsMap = <String, List<LinkYeuCauMayChiTietModel>>{};
      for (var detail in allDetails) {
        if (detail.yeuCauId != null) {
          if (!detailsMap.containsKey(detail.yeuCauId!)) {
            detailsMap[detail.yeuCauId!] = [];
          }
          detailsMap[detail.yeuCauId!]!.add(detail);
        }
      }
      
      setState(() {
        _allRequests = requests;
        _requestDetails = detailsMap;
        _filterRequests();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() { _isLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi tải dữ liệu: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _filterRequests() {
    List<LinkYeuCauMayModel> filtered = _allRequests;
    
    if (_selectedFilter == 'Nháp') {
      filtered = filtered.where((r) => r.trangThai == 'Nháp' && r.nguoiTao == widget.username).toList();
    } else if (_selectedFilter == 'Chờ duyệt TPKD') {
      filtered = filtered.where((r) => r.trangThai == 'Gửi').toList();
    } else if (_selectedFilter == 'Chờ duyệt KT') {
      filtered = filtered.where((r) => r.trangThai == 'TPKD Duyệt').toList();
    } else if (_selectedFilter == 'Đã duyệt') {
      filtered = filtered.where((r) => r.trangThai == 'Kế toán duyệt').toList();
    } else if (_selectedFilter == 'Từ chối') {
      filtered = filtered.where((r) => r.trangThai == 'TPKD Từ chối' || r.trangThai == 'Kế toán từ chối').toList();
    }
    
    filtered.sort((a, b) => (b.ngay ?? DateTime.now()).compareTo(a.ngay ?? DateTime.now()));
    
    setState(() {
      _filteredRequests = filtered;
    });
  }

  Future<void> _sendDraftRequest(LinkYeuCauMayModel request) async {
    setState(() { _isProcessing = true; });
    try {
      final updatedRequest = LinkYeuCauMayModel(
        yeuCauId: request.yeuCauId,
        nguoiTao: request.nguoiTao,
        ngay: request.ngay,
        gio: request.gio,
        hopDongId: request.hopDongId,
        phanLoai: request.phanLoai,
        tenHopDong: request.tenHopDong,
        diaChi: request.diaChi,
        moTa: request.moTa,
        trangThai: 'Gửi',
        nguoiGuiCapNhat: DateTime.now().toIso8601String(),
      );
      
      final response = await http.post(
        Uri.parse('$baseUrl/guiyeucaumay'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updatedRequest.toMap()),
      ).timeout(Duration(seconds: 30));
      
      if (response.statusCode != 200) {
        throw Exception('Server trả về lỗi (Status: ${response.statusCode})');
      }
      
      await _dbHelper.updateLinkYeuCauMay(updatedRequest);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã gửi yêu cầu thành công'), backgroundColor: Colors.green));
      _loadData();
    } catch (e) {
      print('Error sending request: $e');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(children: [Icon(Icons.error, color: Colors.red), SizedBox(width: 12), Text('Lỗi')]),
          content: Text('Không thể gửi yêu cầu lên máy chủ.\n\nChi tiết: $e'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Đóng'))],
        ),
      );
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  Future<void> _approveRequest(LinkYeuCauMayModel request, bool isManagerApproval) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận duyệt'),
        content: Text('Bạn có chắc chắn muốn duyệt yêu cầu này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Duyệt'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() { _isProcessing = true; });
    try {
      final now = DateTime.now().toIso8601String();
      final updatedRequest = LinkYeuCauMayModel(
        yeuCauId: request.yeuCauId,
        nguoiTao: request.nguoiTao,
        ngay: request.ngay,
        gio: request.gio,
        hopDongId: request.hopDongId,
        phanLoai: request.phanLoai,
        tenHopDong: request.tenHopDong,
        diaChi: request.diaChi,
        moTa: request.moTa,
        trangThai: isManagerApproval ? 'TPKD Duyệt' : 'Kế toán duyệt',
        nguoiGuiCapNhat: request.nguoiGuiCapNhat,
        duyetKdCapNhat: isManagerApproval ? now : request.duyetKdCapNhat,
        duyetKtCapNhat: isManagerApproval ? request.duyetKtCapNhat : now,
      );
      
      final response = await http.post(
        Uri.parse('$baseUrl/guiyeucaumay'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updatedRequest.toMap()),
      ).timeout(Duration(seconds: 30));
      
      if (response.statusCode != 200) {
        throw Exception('Server trả về lỗi (Status: ${response.statusCode})');
      }
      
      await _dbHelper.updateLinkYeuCauMay(updatedRequest);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã duyệt yêu cầu thành công'), backgroundColor: Colors.green));
      _loadData();
    } catch (e) {
      print('Error approving request: $e');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(children: [Icon(Icons.error, color: Colors.red), SizedBox(width: 12), Text('Lỗi')]),
          content: Text('Không thể duyệt yêu cầu.\n\nChi tiết: $e'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Đóng'))],
        ),
      );
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  Future<void> _rejectRequest(LinkYeuCauMayModel request, bool isManagerApproval) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận từ chối'),
        content: Text('Bạn có chắc chắn muốn từ chối yêu cầu này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Từ chối'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() { _isProcessing = true; });
    try {
      final now = DateTime.now().toIso8601String();
      final updatedRequest = LinkYeuCauMayModel(
        yeuCauId: request.yeuCauId,
        nguoiTao: request.nguoiTao,
        ngay: request.ngay,
        gio: request.gio,
        hopDongId: request.hopDongId,
        phanLoai: request.phanLoai,
        tenHopDong: request.tenHopDong,
        diaChi: request.diaChi,
        moTa: request.moTa,
        trangThai: isManagerApproval ? 'TPKD Từ chối' : 'Kế toán từ chối',
        nguoiGuiCapNhat: request.nguoiGuiCapNhat,
        duyetKdCapNhat: isManagerApproval ? now : request.duyetKdCapNhat,
        duyetKtCapNhat: isManagerApproval ? request.duyetKtCapNhat : now,
      );
      
      final response = await http.post(
        Uri.parse('$baseUrl/guiyeucaumay'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updatedRequest.toMap()),
      ).timeout(Duration(seconds: 30));
      
      if (response.statusCode != 200) {
        throw Exception('Server trả về lỗi (Status: ${response.statusCode})');
      }
      
      await _dbHelper.updateLinkYeuCauMay(updatedRequest);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã từ chối yêu cầu'), backgroundColor: Colors.orange));
      _loadData();
    } catch (e) {
      print('Error rejecting request: $e');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(children: [Icon(Icons.error, color: Colors.red), SizedBox(width: 12), Text('Lỗi')]),
          content: Text('Không thể từ chối yêu cầu.\n\nChi tiết: $e'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Đóng'))],
        ),
      );
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  Future<void> _editDraftRequest(LinkYeuCauMayModel request) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HDYeuCauMayMoiScreen(
          username: widget.username,
          userRole: widget.userRole,
          currentPeriod: widget.currentPeriod,
          nextPeriod: widget.nextPeriod,
          existingRequest: request,
          existingDetails: _requestDetails[request.yeuCauId] ?? [],
        ),
      ),
    );
    
    if (result == true) {
      _loadData();
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Nháp': return Colors.grey;
      case 'Gửi': return Colors.orange;
      case 'TPKD Duyệt': return Colors.blue;
      case 'TPKD Từ chối': return Colors.red;
      case 'Kế toán duyệt': return Colors.green;
      case 'Kế toán từ chối': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'Nháp': return Icons.edit_note;
      case 'Gửi': return Icons.pending_actions;
      case 'TPKD Duyệt': return Icons.approval;
      case 'TPKD Từ chối': return Icons.cancel;
      case 'Kế toán duyệt': return Icons.check_circle;
      case 'Kế toán từ chối': return Icons.cancel;
      default: return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManager = _managerApprovers.contains(widget.username.toLowerCase());
    final isFinance = _financeApprovers.contains(widget.username.toLowerCase());
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản lý yêu cầu máy móc'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 1, blurRadius: 3, offset: Offset(0, 2))],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.filter_list, color: Color(0xFF1976D2)),
                    SizedBox(width: 8),
                    Text('Lọc theo trạng thái:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _filterOptions.map((option) {
                            final isSelected = _selectedFilter == option;
                            return Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(option),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedFilter = option;
                                    _filterRequests();
                                  });
                                },
                                backgroundColor: Colors.grey[200],
                                selectedColor: Color(0xFF1976D2),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredRequests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Không có yêu cầu nào', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _filteredRequests.length,
                        itemBuilder: (context, index) {
                          final request = _filteredRequests[index];
                          final details = _requestDetails[request.yeuCauId] ?? [];
                          final isDraft = request.trangThai == 'Nháp';
                          final needsManagerApproval = request.trangThai == 'Gửi' && isManager;
                          final needsFinanceApproval = request.trangThai == 'TPKD Duyệt' && isFinance;
                          
                          return Card(
                            margin: EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(request.trangThai).withOpacity(0.1),
                                    borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(_getStatusIcon(request.trangThai), color: _getStatusColor(request.trangThai), size: 20),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              request.tenHopDong ?? 'N/A',
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(request.trangThai),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              request.trangThai ?? 'N/A',
                                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      _buildInfoRow(Icons.person, 'Người tạo', request.nguoiTao ?? 'N/A'),
                                      SizedBox(height: 6),
                                      _buildInfoRow(Icons.calendar_today, 'Ngày tạo', '${request.ngay != null ? "${request.ngay!.day}/${request.ngay!.month}/${request.ngay!.year}" : "N/A"} ${request.gio ?? ""}'),
                                      SizedBox(height: 6),
                                      _buildInfoRow(Icons.location_on, 'Địa chỉ', request.diaChi ?? 'N/A'),
                                      SizedBox(height: 6),
                                      _buildInfoRow(Icons.category, 'Phân loại', request.phanLoai ?? 'N/A'),
                                      if (details.isNotEmpty) ...[
                                        SizedBox(height: 6),
                                        _buildInfoRow(Icons.construction, 'Số máy móc', '${details.length} loại'),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isDraft && request.nguoiTao == widget.username)
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: _isProcessing ? null : () => _editDraftRequest(request),
                                            icon: Icon(Icons.edit, size: 18),
                                            label: Text('Chỉnh sửa'),
                                            style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: _isProcessing ? null : () => _sendDraftRequest(request),
                                            icon: Icon(Icons.send, size: 18),
                                            label: Text('Gửi yêu cầu'),
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (needsManagerApproval || needsFinanceApproval)
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      border: Border(top: BorderSide(color: Colors.orange[200]!)),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'Yêu cầu này cần duyệt của bạn',
                                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[900]),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: _isProcessing ? null : () => _rejectRequest(request, needsManagerApproval),
                                                icon: Icon(Icons.close, size: 18),
                                                label: Text('Từ chối'),
                                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: _isProcessing ? null : () => _approveRequest(request, needsManagerApproval),
                                                icon: Icon(Icons.check, size: 18),
                                                label: Text('Duyệt'),
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          if (_isProcessing)
            LinearProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}