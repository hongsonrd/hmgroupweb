import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/services.dart';
import 'package:barcode/barcode.dart' as barcode_pkg;
import 'db_helper.dart';
import 'table_models.dart';
import 'hd_yeucaumaymoi.dart';

class HDYeuCauMayQuanLyScreen extends StatefulWidget {
  final String username;
  final String userRole;
  final String currentPeriod;
  final String nextPeriod;
  const HDYeuCauMayQuanLyScreen({Key? key, required this.username, required this.userRole, required this.currentPeriod, required this.nextPeriod}) : super(key: key);
  @override
  _HDYeuCauMayQuanLyScreenState createState() => _HDYeuCauMayQuanLyScreenState();
}

class _HDYeuCauMayQuanLyScreenState extends State<HDYeuCauMayQuanLyScreen> {
  final DBHelper _dbHelper = DBHelper();
  final String baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  final List<String> _managerApprovers = ['hm.tason', 'hm.tranminh'];
  final List<String> _financeApprovers = ['hm.tason', 'hm.nguyenyen'];
  List<LinkYeuCauMayModel> _allRequests = [];
  List<LinkYeuCauMayModel> _filteredRequests = [];
  Map<String, List<LinkYeuCauMayChiTietModel>> _requestDetails = {};
  bool _isLoading = true;
  bool _isProcessing = false;
  String _selectedFilter = 'Tất cả';
  String _searchText = '';
  String? _selectedMonth;
  final TextEditingController _searchController = TextEditingController();
  final List<String> _filterOptions = ['Tất cả', 'Nháp', 'Chờ duyệt TPKD', 'Chờ duyệt KT', 'Đã duyệt', 'Từ chối'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    if (_searchText.isNotEmpty) {
      filtered = filtered.where((r) {
        final searchLower = _searchText.toLowerCase();
        return (r.nguoiTao?.toLowerCase().contains(searchLower) ?? false) ||
               (r.tenHopDong?.toLowerCase().contains(searchLower) ?? false) ||
               (r.diaChi?.toLowerCase().contains(searchLower) ?? false);
      }).toList();
    }
    if (_selectedMonth != null) {
      filtered = filtered.where((r) {
        if (r.ngay == null) return false;
        final monthYear = DateFormat('MM/yyyy').format(r.ngay!);
        return monthYear == _selectedMonth;
      }).toList();
    }
    filtered.sort((a, b) => (b.ngay ?? DateTime.now()).compareTo(a.ngay ?? DateTime.now()));
    setState(() {
      _filteredRequests = filtered;
    });
  }

  List<String> _getAvailableMonths() {
    final months = _allRequests.where((r) => r.ngay != null).map((r) => DateFormat('MM/yyyy').format(r.ngay!)).toSet().toList();
    months.sort((a, b) => b.compareTo(a));
    return months;
  }

  Future<void> _sendDraftRequest(LinkYeuCauMayModel request) async {
    setState(() { _isProcessing = true; });
    try {
      final updatedRequest = LinkYeuCauMayModel(yeuCauId: request.yeuCauId, nguoiTao: request.nguoiTao, ngay: request.ngay, gio: request.gio, hopDongId: request.hopDongId, phanLoai: request.phanLoai, tenHopDong: request.tenHopDong, diaChi: request.diaChi, moTa: request.moTa, trangThai: 'Gửi', nguoiGuiCapNhat: DateTime.now().toIso8601String());
      final response = await http.post(Uri.parse('$baseUrl/guiyeucaumay'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(updatedRequest.toMap())).timeout(Duration(seconds: 30));
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
      showDialog(context: context, builder: (context) => AlertDialog(title: Row(children: [Icon(Icons.error, color: Colors.red), SizedBox(width: 12), Text('Lỗi')]), content: Text('Không thể gửi yêu cầu lên máy chủ.\n\nChi tiết: $e'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Đóng'))]));
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  Future<void> _approveRequest(LinkYeuCauMayModel request, bool isManagerApproval) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text('Xác nhận duyệt'), content: Text('Bạn có chắc chắn muốn duyệt yêu cầu này?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Hủy')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Duyệt'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green))]));
    if (confirmed != true) return;
    setState(() { _isProcessing = true; });
    try {
      final now = DateTime.now().toIso8601String();
      final updatedRequest = LinkYeuCauMayModel(yeuCauId: request.yeuCauId, nguoiTao: request.nguoiTao, ngay: request.ngay, gio: request.gio, hopDongId: request.hopDongId, phanLoai: request.phanLoai, tenHopDong: request.tenHopDong, diaChi: request.diaChi, moTa: request.moTa, trangThai: isManagerApproval ? 'TPKD Duyệt' : 'Kế toán duyệt', nguoiGuiCapNhat: request.nguoiGuiCapNhat, duyetKdCapNhat: isManagerApproval ? now : request.duyetKdCapNhat, duyetKtCapNhat: isManagerApproval ? request.duyetKtCapNhat : now);
      final response = await http.post(Uri.parse('$baseUrl/guiyeucaumay'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(updatedRequest.toMap())).timeout(Duration(seconds: 30));
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
      showDialog(context: context, builder: (context) => AlertDialog(title: Row(children: [Icon(Icons.error, color: Colors.red), SizedBox(width: 12), Text('Lỗi')]), content: Text('Không thể duyệt yêu cầu.\n\nChi tiết: $e'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Đóng'))]));
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  Future<void> _rejectRequest(LinkYeuCauMayModel request, bool isManagerApproval) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text('Xác nhận từ chối'), content: Text('Bạn có chắc chắn muốn từ chối yêu cầu này?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Hủy')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Từ chối'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red))]));
    if (confirmed != true) return;
    setState(() { _isProcessing = true; });
    try {
      final now = DateTime.now().toIso8601String();
      final updatedRequest = LinkYeuCauMayModel(yeuCauId: request.yeuCauId, nguoiTao: request.nguoiTao, ngay: request.ngay, gio: request.gio, hopDongId: request.hopDongId, phanLoai: request.phanLoai, tenHopDong: request.tenHopDong, diaChi: request.diaChi, moTa: request.moTa, trangThai: isManagerApproval ? 'TPKD Từ chối' : 'Kế toán từ chối', nguoiGuiCapNhat: request.nguoiGuiCapNhat, duyetKdCapNhat: isManagerApproval ? now : request.duyetKdCapNhat, duyetKtCapNhat: isManagerApproval ? request.duyetKtCapNhat : now);
      final response = await http.post(Uri.parse('$baseUrl/guiyeucaumay'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(updatedRequest.toMap())).timeout(Duration(seconds: 30));
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
      showDialog(context: context, builder: (context) => AlertDialog(title: Row(children: [Icon(Icons.error, color: Colors.red), SizedBox(width: 12), Text('Lỗi')]), content: Text('Không thể từ chối yêu cầu.\n\nChi tiết: $e'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Đóng'))]));
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  Future<void> _editDraftRequest(LinkYeuCauMayModel request) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => HDYeuCauMayMoiScreen(username: widget.username, userRole: widget.userRole, currentPeriod: widget.currentPeriod, nextPeriod: widget.nextPeriod, existingRequest: request, existingDetails: _requestDetails[request.yeuCauId] ?? [])));
    if (result == true) {
      _loadData();
    }
  }

Future<void> _showRequestDetails(LinkYeuCauMayModel request) async {
  final details = _requestDetails[request.yeuCauId] ?? [];
  final totalSum = details.fold<double>(0, (sum, item) => sum + (item.thanhTienThang ?? 0));

  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Container
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.description, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Chi tiết yêu cầu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Scrollable Content
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  // Request Info Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.assignment, color: Color(0xFF1976D2)),
                              SizedBox(width: 8),
                              Text(
                                'Thông tin yêu cầu',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1976D2),
                                ),
                              ),
                            ],
                          ),
                          Divider(height: 24),
                          _buildDetailRow('Mã yêu cầu:', request.yeuCauId ?? 'N/A'),
                          SizedBox(height: 8),
                          _buildDetailRow('Tên hợp đồng:', request.tenHopDong ?? 'N/A'),
                          SizedBox(height: 8),
                          _buildDetailRow('Phân loại:', request.phanLoai ?? 'N/A'),
                          SizedBox(height: 8),
                          _buildDetailRow('Địa chỉ:', request.diaChi ?? 'N/A'),
                          SizedBox(height: 8),
                          _buildDetailRow('Người tạo:', request.nguoiTao ?? 'N/A'),
                          SizedBox(height: 8),
                          _buildDetailRow(
                            'Ngày tạo:',
                            request.ngay != null
                                ? '${request.ngay!.day}/${request.ngay!.month}/${request.ngay!.year} ${request.gio ?? ""}'
                                : 'N/A',
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'Trạng thái: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(request.trangThai),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  request.trangThai ?? 'N/A',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (request.moTa != null && request.moTa!.isNotEmpty) ...[
                            SizedBox(height: 8),
                            _buildDetailRow('Mô tả:', request.moTa!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Machine List Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.construction, color: Color(0xFF4CAF50)),
                              SizedBox(width: 8),
                              Text(
                                'Danh sách máy móc',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Color(0xFF4CAF50),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${details.length}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Tổng thành tiền/tháng: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  NumberFormat('#,###').format(totalSum),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 24),
                          if (details.isEmpty)
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Không có máy móc nào',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: details.length,
                              separatorBuilder: (context, index) => Divider(height: 24),
                              itemBuilder: (context, index) {
                                final detail = details[index];
                                return Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: Color(0xFF4CAF50),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${index + 1}',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              detail.loaiMay ?? 'N/A',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildDetailItem(
                                              'Mã máy',
                                              detail.maMay ?? 'N/A',
                                            ),
                                          ),
                                          Expanded(
                                            child: _buildDetailItem(
                                              'Hãng',
                                              detail.hangMay ?? 'N/A',
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildDetailItem(
                                              'Đơn giá',
                                              NumberFormat('#,###').format(detail.donGia ?? 0),
                                            ),
                                          ),
                                          Expanded(
                                            child: _buildDetailItem(
                                              'Số lượng',
                                              '${detail.soLuong ?? 0}',
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildDetailItem(
                                              'Tình trạng',
                                              '${((detail.tinhTrang ?? 0) * 100).toStringAsFixed(0)}%',
                                            ),
                                          ),
                                          Expanded(
                                            child: _buildDetailItem(
                                              'Thành tiền/tháng',
                                              NumberFormat('#,###').format(
                                                detail.thanhTienThang ?? 0,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (detail.ghiChu != null && detail.ghiChu!.isNotEmpty) ...[
                                        SizedBox(height: 6),
                                        _buildDetailItem('Ghi chú', detail.ghiChu!),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ), // <-- Added comma here
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Export Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _generateAndShareExcel(request, details),
                          icon: Icon(Icons.table_chart),
                          label: Text('Xuất Excel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _generateAndSharePDF(request, details),
                          icon: Icon(Icons.picture_as_pdf),
                          label: Text('Xuất PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Close Button Container
            Container(
              padding: EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Đóng'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 48),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildDetailItem(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])), SizedBox(height: 2), Text(value, style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500))]);
  }

  Future<void> _generateAndShareExcel(LinkYeuCauMayModel request, List<LinkYeuCauMayChiTietModel> details) async {
    try {
      final excelDoc = excel_pkg.Excel.createExcel();
      final sheet = excelDoc['Yêu cầu máy móc'];
      final headers = ['STT', 'Loại máy', 'Mã máy', 'Hãng', 'Tần suất', 'Đơn giá', 'Tình trạng %', 'Tháng khấu hao', 'Số lượng', 'Thành tiền/tháng', 'Ghi chú'];
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = 'YÊU CẦU MÁY MÓC';
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = 'Tên hợp đồng:';
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).value = request.tenHopDong ?? 'N/A';
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).value = 'Địa chỉ:';
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3)).value = request.diaChi ?? 'N/A';
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4)).value = 'Người tạo:';
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4)).value = request.nguoiTao ?? 'N/A';
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 5)).value = 'Trạng thái:';
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 5)).value = request.trangThai ?? 'N/A';
      int startRow = 7;
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: startRow));
        cell.value = headers[i];
        cell.cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#4CAF50', fontColorHex: '#FFFFFF');
      }
      for (int i = 0; i < details.length; i++) {
        final detail = details[i];
        final rowData = ['${i + 1}', detail.loaiMay ?? '', detail.maMay ?? '', detail.hangMay ?? '', detail.tanSuatSuDung ?? '', '${detail.donGia ?? 0}', '${((detail.tinhTrang ?? 0) * 100).toStringAsFixed(0)}', '${detail.soThangKhauHao ?? 0}', '${detail.soLuong ?? 0}', '${detail.thanhTienThang ?? 0}', detail.ghiChu ?? ''];
        for (int j = 0; j < rowData.length; j++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: startRow + 1 + i)).value = rowData[j];
        }
      }
      final excelBytes = excelDoc.encode()!;
      final dir = await getApplicationDocumentsDirectory();
      final reportDir = Directory('${dir.path}/YeuCauMay');
      if (!await reportDir.exists()) {
        await reportDir.create(recursive: true);
      }
      final now = DateTime.now();
      final ts = DateFormat('yyyyMMddHHmmss').format(now);
      final rand = 1000000 + Random().nextInt(9000000);
      final fileName = '${ts}_yeucaumay_$rand.xlsx';
      final file = File('${reportDir.path}/$fileName');
      await file.writeAsBytes(excelBytes, flush: true);
      if (mounted) {
        final result = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 12), Text('Đã tạo Excel')]), content: Text('File đã được lưu tại:\n${file.path}\n\nBạn muốn làm gì?'), actions: [TextButton(onPressed: () => Navigator.pop(context, 'share'), child: Text('Chia sẻ')), if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) TextButton(onPressed: () => Navigator.pop(context, 'open'), child: Text('Mở file')), if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) TextButton(onPressed: () => Navigator.pop(context, 'folder'), child: Text('Mở thư mục')), TextButton(onPressed: () => Navigator.pop(context), child: Text('Đóng'))]));
        if (result == 'share') {
          await Share.shareXFiles([XFile(file.path)], text: 'Yêu cầu máy móc: ${request.tenHopDong ?? ""}');
        } else if (result == 'open') {
          await _openFile(file.path);
        } else if (result == 'folder') {
          await _openFolder(reportDir.path);
        }
      }
    } catch (e) {
      print('Error generating Excel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi tạo Excel: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _generateAndSharePDF(LinkYeuCauMayModel request, List<LinkYeuCauMayChiTietModel> details) async {
    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.notoSansRegular();
      final fontBold = await PdfGoogleFonts.notoSansBold();
      final ByteData logoData = await rootBundle.load('assets/logochecklist.png');
      final logo = pw.MemoryImage(logoData.buffer.asUint8List());
      final totalSum = details.fold<double>(0, (sum, item) => sum + (item.thanhTienThang ?? 0));
      
      String _formatDateTime(String? isoString) {
        if (isoString == null) return '';
        try {
          final dt = DateTime.parse(isoString);
          return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } catch (e) {
          return '';
        }
      }

      final kdApproved = request.trangThai == 'TPKD Duyệt' || request.trangThai == 'Kế toán duyệt';
      final kdRejected = request.trangThai == 'TPKD Từ chối';
      final ktApproved = request.trangThai == 'Kế toán duyệt';
      final ktRejected = request.trangThai == 'Kế toán từ chối';

      pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.all(20), build: (pw.Context context) {
        return [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(width: 60, height: 60, child: pw.Image(logo)),
            pw.SizedBox(width: 12),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Công ty TNHH Hoàn Mỹ', style: pw.TextStyle(font: fontBold, fontSize: 14)),
              pw.SizedBox(height: 4),
              pw.Text('YÊU CẦU MÁY MÓC', style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.blue900))
            ])
          ]),
          pw.SizedBox(height: 20),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: pw.Container(padding: pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(4)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('THÔNG TIN YÊU CẦU', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.blue800)),
              pw.Divider(thickness: 1),
              _buildPdfRow('Tên hợp đồng:', request.tenHopDong ?? 'N/A', font, fontBold, 9),
              pw.SizedBox(height: 4),
              _buildPdfRow('Phân loại:', request.phanLoai ?? 'N/A', font, fontBold, 9),
              pw.SizedBox(height: 4),
              _buildPdfRow('Địa chỉ:', request.diaChi ?? 'N/A', font, fontBold, 9),
              pw.SizedBox(height: 4),
              _buildPdfRow('Người tạo:', request.nguoiTao ?? 'N/A', font, fontBold, 9),
              pw.SizedBox(height: 4),
              _buildPdfRow('Ngày tạo:', request.ngay != null ? '${request.ngay!.day}/${request.ngay!.month}/${request.ngay!.year} ${request.gio ?? ""}' : 'N/A', font, fontBold, 9),
              pw.SizedBox(height: 4),
              _buildPdfRow('Trạng thái:', request.trangThai ?? 'N/A', font, fontBold, 9),
              if (request.moTa != null && request.moTa!.isNotEmpty) ...[pw.SizedBox(height: 4), _buildPdfRow('Mô tả:', request.moTa!, font, fontBold, 9)]
            ]))),
            pw.SizedBox(width: 10),
            pw.Column(children: [
              pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: request.yeuCauId ?? 'N/A', width: 64, height: 64),
              pw.SizedBox(height: 4),
              pw.Text(request.yeuCauId ?? 'N/A', style: pw.TextStyle(font: font, fontSize: 3), textAlign: pw.TextAlign.center)
            ])
          ]),
          pw.SizedBox(height: 16),
          pw.Text('DANH SÁCH MÁY MÓC', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.green800)),
          pw.SizedBox(height: 8),
          if (details.isEmpty) pw.Text('Không có máy móc nào', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)) else pw.Table.fromTextArray(
            headers: ['#', 'Loại máy', 'Mã máy', 'Hãng', 'Đơn giá', 'SL', 'T.trạng', 'T.tiền/tháng'],
            data: [
              ...List.generate(details.length, (index) {
                final detail = details[index];
                return ['${index + 1}', detail.loaiMay ?? 'N/A', detail.maMay ?? 'N/A', detail.hangMay ?? 'N/A', NumberFormat('#,###').format(detail.donGia ?? 0), '${detail.soLuong ?? 0}', '${((detail.tinhTrang ?? 0) * 100).toStringAsFixed(0)}%', NumberFormat('#,###').format(detail.thanhTienThang ?? 0)];
              }),
              ['', '', '', '', '', '', 'TỔNG', NumberFormat('#,###').format(totalSum)]
            ],
            border: pw.TableBorder.all(color: PdfColors.grey400),
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColors.blue700),
            cellStyle: pw.TextStyle(font: font, fontSize: 7.5),
            cellHeight: 22,
            cellAlignments: {0: pw.Alignment.center, 1: pw.Alignment.centerLeft, 2: pw.Alignment.centerLeft, 3: pw.Alignment.centerLeft, 4: pw.Alignment.centerRight, 5: pw.Alignment.center, 6: pw.Alignment.center, 7: pw.Alignment.centerRight}
          ),
          pw.SizedBox(height: 12),
          pw.Container(padding: pw.EdgeInsets.all(6), decoration: pw.BoxDecoration(color: PdfColors.yellow50, border: pw.Border.all(color: PdfColors.orange300)), child: pw.Text('Tổng số máy móc: ${details.length} loại', style: pw.TextStyle(font: fontBold, fontSize: 9))),
          pw.SizedBox(height: 20),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            _buildSignatureSection('Nhân viên đề xuất', request.nguoiTao ?? '', _formatDateTime(request.nguoiGuiCapNhat), true, false, font, fontBold),
            _buildSignatureSection('TP. Kinh doanh', 'Trần Thị Thanh Minh', _formatDateTime(request.duyetKdCapNhat), kdApproved, kdRejected, font, fontBold),
            _buildSignatureSection('TP. Kế toán', 'Nguyễn Thị Hoàng Yến', _formatDateTime(request.duyetKtCapNhat), ktApproved, ktRejected, font, fontBold),
            _buildSignatureSection('Giám đốc', 'Đàm Hữu Hoàng', '', false, false, font, fontBold),
          ])
        ];
      }));
      
      final dir = await getApplicationDocumentsDirectory();
      final reportDir = Directory('${dir.path}/YeuCauMay');
      if (!await reportDir.exists()) {
        await reportDir.create(recursive: true);
      }
      final now = DateTime.now();
      final ts = DateFormat('yyyyMMddHHmmss').format(now);
      final rand = 1000000 + Random().nextInt(9000000);
      final fileName = '${ts}_yeucaumay_$rand.pdf';
      final file = File('${reportDir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      if (mounted) {
        final result = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 12), Text('Đã tạo PDF')]), content: Text('File đã được lưu tại:\n${file.path}\n\nBạn muốn làm gì?'), actions: [TextButton(onPressed: () => Navigator.pop(context, 'share'), child: Text('Chia sẻ')), if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) TextButton(onPressed: () => Navigator.pop(context, 'open'), child: Text('Mở file')), if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) TextButton(onPressed: () => Navigator.pop(context, 'folder'), child: Text('Mở thư mục')), TextButton(onPressed: () => Navigator.pop(context), child: Text('Đóng'))]));
        if (result == 'share') {
          await Share.shareXFiles([XFile(file.path)], text: 'Yêu cầu máy móc: ${request.tenHopDong ?? ""}');
        } else if (result == 'open') {
          await _openFile(file.path);
        } else if (result == 'folder') {
          await _openFolder(reportDir.path);
        }
      }
    } catch (e) {
      print('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi tạo PDF: $e'), backgroundColor: Colors.red));
      }
    }
  }

  pw.Widget _buildSignatureSection(String title, String name, String dateTime, bool approved, bool rejected, pw.Font font, pw.Font fontBold) {
    return pw.Container(width: 110, child: pw.Column(children: [
      pw.Container(padding: pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: pw.BoxDecoration(color: PdfColors.grey300, borderRadius: pw.BorderRadius.circular(12)), child: pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 7), textAlign: pw.TextAlign.center)),
      pw.SizedBox(height: 40),
      if (name.isNotEmpty) pw.Text(name, style: pw.TextStyle(font: fontBold, fontSize: 8, color: approved ? PdfColors.green700 : (rejected ? PdfColors.red700 : PdfColors.black)), textAlign: pw.TextAlign.center),
      if (dateTime.isNotEmpty) pw.Text(dateTime, style: pw.TextStyle(font: font, fontSize: 7, color: approved ? PdfColors.green700 : (rejected ? PdfColors.red700 : PdfColors.black)), textAlign: pw.TextAlign.center),
    ]));
  }

  Future<void> _openFile(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path], runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (e) {
      print('Error opening file: $e');
    }
  }

  Future<void> _openFolder(String folderPath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [folderPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [folderPath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [folderPath]);
      }
    } catch (e) {
      print('Error opening folder: $e');
    }
  }

  pw.Widget _buildPdfRow(String label, String value, pw.Font font, pw.Font fontBold, double fontSize) {
    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.SizedBox(width: 100, child: pw.Text(label, style: pw.TextStyle(font: fontBold, fontSize: fontSize))), pw.Expanded(child: pw.Text(value, style: pw.TextStyle(font: font, fontSize: fontSize)))]);
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 120, child: Text(label, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey[700]))), Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: Colors.black87)))]);
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final crossAxisCount = isDesktop ? (screenWidth > 1400 ? 3 : 2) : 1;

    return Scaffold(
      appBar: AppBar(title: Text('Quản lý yêu cầu máy móc'), flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1976D2), Color(0xFF42A5F5)]))), foregroundColor: Colors.white),
      body: Column(children: [
        Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 1, blurRadius: 3, offset: Offset(0, 2))]), child: Column(children: [
          Row(children: [
            Expanded(child: TextField(controller: _searchController, decoration: InputDecoration(hintText: 'Tìm kiếm theo người tạo, hợp đồng, địa chỉ...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12), isDense: true), onChanged: (value) {
              setState(() {
                _searchText = value;
                _filterRequests();
              });
            })),
            SizedBox(width: 12),
            Container(width: 160, child: DropdownButtonFormField<String>(decoration: InputDecoration(labelText: 'Tháng', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), isDense: true), value: _selectedMonth, items: [DropdownMenuItem(value: null, child: Text('Tất cả tháng')), ..._getAvailableMonths().map((m) => DropdownMenuItem(value: m, child: Text(m)))], onChanged: (value) {
              setState(() {
                _selectedMonth = value;
                _filterRequests();
              });
            }))
          ]),
          SizedBox(height: 12),
          Row(children: [
            Icon(Icons.filter_list, color: Color(0xFF1976D2)),
            SizedBox(width: 8),
            Text('Lọc:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _filterOptions.map((option) {
              final isSelected = _selectedFilter == option;
              return Padding(padding: EdgeInsets.only(right: 8), child: FilterChip(label: Text(option), selected: isSelected, onSelected: (selected) {
                setState(() {
                  _selectedFilter = option;
                  _filterRequests();
                });
              }, backgroundColor: Colors.grey[200], selectedColor: Color(0xFF1976D2), labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)));
            }).toList())))
          ])
        ])),
        Expanded(child: _isLoading ? Center(child: CircularProgressIndicator()) : _filteredRequests.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox, size: 64, color: Colors.grey), SizedBox(height: 16), Text('Không có yêu cầu nào', style: TextStyle(fontSize: 16, color: Colors.grey[600]))])) : GridView.builder(padding: EdgeInsets.all(16), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: isDesktop ? 2.1 : 1.65), itemCount: _filteredRequests.length, itemBuilder: (context, index) {
          final request = _filteredRequests[index];
          final details = _requestDetails[request.yeuCauId] ?? [];
          final isDraft = request.trangThai == 'Nháp';
          final needsManagerApproval = request.trangThai == 'Gửi' && isManager;
          final needsFinanceApproval = request.trangThai == 'TPKD Duyệt' && isFinance;
          return Card(margin: EdgeInsets.zero, elevation: 2, child: InkWell(onTap: () => _showRequestDetails(request), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: _getStatusColor(request.trangThai).withOpacity(0.1), borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(_getStatusIcon(request.trangThai), color: _getStatusColor(request.trangThai), size: 18), SizedBox(width: 6), Expanded(child: Text(request.tenHopDong ?? 'N/A', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis)), Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _getStatusColor(request.trangThai), borderRadius: BorderRadius.circular(12)), child: Text(request.trangThai ?? 'N/A', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))]), SizedBox(height: 8), _buildInfoRowCompact(Icons.person, request.nguoiTao ?? 'N/A'), SizedBox(height: 4), _buildInfoRowCompact(Icons.calendar_today, request.ngay != null ? "${request.ngay!.day}/${request.ngay!.month}/${request.ngay!.year}" : "N/A"), SizedBox(height: 4), _buildInfoRowCompact(Icons.location_on, request.diaChi ?? 'N/A'), if (details.isNotEmpty) ...[SizedBox(height: 4), _buildInfoRowCompact(Icons.construction, '${details.length} loại')]]))), if (isDraft && request.nguoiTao == widget.username) Container(padding: EdgeInsets.all(8), child: Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _isProcessing ? null : () => _editDraftRequest(request), icon: Icon(Icons.edit, size: 14), label: Text('Sửa', style: TextStyle(fontSize: 12)), style: OutlinedButton.styleFrom(foregroundColor: Colors.blue, padding: EdgeInsets.symmetric(vertical: 8)))), SizedBox(width: 8), Expanded(child: ElevatedButton.icon(onPressed: _isProcessing ? null : () => _sendDraftRequest(request), icon: Icon(Icons.send, size: 14), label: Text('Gửi', style: TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 8))))])), if (needsManagerApproval || needsFinanceApproval) Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange[50], border: Border(top: BorderSide(color: Colors.orange[200]!))), child: Column(children: [Text('Cần duyệt', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[900], fontSize: 11)), SizedBox(height: 6), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _isProcessing ? null : () => _rejectRequest(request, needsManagerApproval), icon: Icon(Icons.close, size: 14), label: Text('Từ chối', style: TextStyle(fontSize: 11)), style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.symmetric(vertical: 6)))), SizedBox(width: 8), Expanded(child: ElevatedButton.icon(onPressed: _isProcessing ? null : () => _approveRequest(request, needsManagerApproval), icon: Icon(Icons.check, size: 14), label: Text('Duyệt', style: TextStyle(fontSize: 11)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 6))))])]))])));
        })),
        if (_isProcessing) LinearProgressIndicator()
      ])
    );
  }

  Widget _buildInfoRowCompact(IconData icon, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 14, color: Colors.grey[600]), SizedBox(width: 6), Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis))]);
  }
}