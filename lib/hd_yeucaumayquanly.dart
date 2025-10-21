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
    showDialog(context: context, builder: (context) => Dialog(child: Container(width: MediaQuery.of(context).size.width * 0.95, constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1976D2), Color(0xFF42A5F5)]), borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))), child: Row(children: [Icon(Icons.description, color: Colors.white), SizedBox(width: 12), Expanded(child: Text('Chi tiết yêu cầu', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))), IconButton(icon: Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))])), Expanded(child: ListView(padding: EdgeInsets.all(16), children: [Card(elevation: 2, child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.assignment, color: Color(0xFF1976D2)), SizedBox(width: 8), Text('Thông tin yêu cầu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)))]), Divider(height: 24), _buildDetailRow('Mã yêu cầu:', request.yeuCauId ?? 'N/A'), SizedBox(height: 8), _buildDetailRow('Tên hợp đồng:', request.tenHopDong ?? 'N/A'), SizedBox(height: 8), _buildDetailRow('Phân loại:', request.phanLoai ?? 'N/A'), SizedBox(height: 8), _buildDetailRow('Địa chỉ:', request.diaChi ?? 'N/A'), SizedBox(height: 8), _buildDetailRow('Người tạo:', request.nguoiTao ?? 'N/A'), SizedBox(height: 8), _buildDetailRow('Ngày tạo:', request.ngay != null ? '${request.ngay!.day}/${request.ngay!.month}/${request.ngay!.year} ${request.gio ?? ""}' : 'N/A'), SizedBox(height: 8), Row(children: [Text('Trạng thái: ', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])), Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _getStatusColor(request.trangThai), borderRadius: BorderRadius.circular(4)), child: Text(request.trangThai ?? 'N/A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)))]), if (request.moTa != null && request.moTa!.isNotEmpty) ...[SizedBox(height: 8), _buildDetailRow('Mô tả:', request.moTa!)]]))), SizedBox(height: 16), Card(elevation: 2, child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.construction, color: Color(0xFF4CAF50)), SizedBox(width: 8), Text('Danh sách máy móc', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))), SizedBox(width: 8), Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Color(0xFF4CAF50), borderRadius: BorderRadius.circular(12)), child: Text('${details.length}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)))]), Divider(height: 24), if (details.isEmpty) Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Không có máy móc nào', style: TextStyle(color: Colors.grey)))) else ListView.separated(shrinkWrap: true, physics: NeverScrollableScrollPhysics(), itemCount: details.length, separatorBuilder: (context, index) => Divider(height: 24), itemBuilder: (context, index) {
      final detail = details[index];
      final totalCost = (detail.thanhTienThang ?? 0);
      return Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Color(0xFF1976D2), borderRadius: BorderRadius.circular(4)), child: Text('#${index + 1}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))), SizedBox(width: 12), Expanded(child: Text(detail.loaiMay ?? 'N/A', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))]), SizedBox(height: 12), _buildDetailRow('Mã máy:', detail.maMay ?? 'N/A'), SizedBox(height: 6), _buildDetailRow('Hãng máy:', detail.hangMay ?? 'N/A'), SizedBox(height: 6), _buildDetailRow('Tần suất:', detail.tanSuatSuDung ?? 'N/A'), SizedBox(height: 6), _buildDetailRow('Đơn giá:', '${detail.donGia?.toString() ?? '0'} VNĐ'), SizedBox(height: 6), _buildDetailRow('Tình trạng:', '${((detail.tinhTrang ?? 0) * 100).toStringAsFixed(0)}%'), SizedBox(height: 6), _buildDetailRow('Số tháng khấu hao:', detail.soThangKhauHao?.toString() ?? '0'), SizedBox(height: 6), _buildDetailRow('Số lượng:', detail.soLuong?.toString() ?? '0'), SizedBox(height: 6), Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(4)), child: Row(children: [Icon(Icons.calculate, color: Color(0xFF4CAF50), size: 16), SizedBox(width: 8), Text('Thành tiền/tháng: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2E7D32))), Text('$totalCost VNĐ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)))])), if (detail.ghiChu != null && detail.ghiChu!.isNotEmpty) ...[SizedBox(height: 6), _buildDetailRow('Ghi chú:', detail.ghiChu!)]]));
    })]))), SizedBox(height: 16), Card(color: Color(0xFFFFF3E0), child: Padding(padding: EdgeInsets.all(12), child: Row(children: [Icon(Icons.info_outline, color: Color(0xFFFF6F00)), SizedBox(width: 12), Expanded(child: Text('Tổng số máy móc: ${details.length} loại', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100))))]))), SizedBox(height: 80)])), Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 1, blurRadius: 5, offset: Offset(0, -3))]), child: Column(children: [Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () async {
      await _generateAndShareExcel(request, details);
    }, icon: Icon(Icons.table_chart), label: Text('Excel'), style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14), foregroundColor: Colors.green[700]))), SizedBox(width: 12), Expanded(child: ElevatedButton.icon(onPressed: () => _generateAndSharePDF(request, details), icon: Icon(Icons.picture_as_pdf), label: Text('PDF'), style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14), backgroundColor: Colors.red, foregroundColor: Colors.white)))]), SizedBox(height: 12), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close), label: Text('Đóng'), style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14), foregroundColor: Colors.grey[700])))]))]))));
  }
  Future<void> _generateAndShareExcel(LinkYeuCauMayModel request, List<LinkYeuCauMayChiTietModel> details) async {
    try {
      final excelDoc = excel_pkg.Excel.createExcel();
      final sheet = excelDoc['YeuCauMay'];
      final headers = ['STT', 'Loại máy', 'Mã máy', 'Hãng máy', 'Tần suất', 'Đơn giá (VNĐ)', 'Tình trạng (%)', 'Số tháng KH', 'Số lượng', 'Thành tiền/tháng (VNĐ)', 'Ghi chú'];
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = headers[i];
        cell.cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#1976D2', fontColorHex: '#FFFFFF');
      }
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = 'Mã yêu cầu:';
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = request.yeuCauId ?? 'N/A';
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
    pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.all(32), build: (pw.Context context) {
      return [pw.Header(level: 0, child: pw.Text('YÊU CẦU MÁY MÓC', style: pw.TextStyle(font: fontBold, fontSize: 20, color: PdfColors.blue900))), pw.SizedBox(height: 20), pw.Container(padding: pw.EdgeInsets.all(12), decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(4)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('THÔNG TIN YÊU CẦU', style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.blue800)), pw.Divider(thickness: 1), _buildPdfRow('Mã yêu cầu:', request.yeuCauId ?? 'N/A', font, fontBold), pw.SizedBox(height: 6), _buildPdfRow('Tên hợp đồng:', request.tenHopDong ?? 'N/A', font, fontBold), pw.SizedBox(height: 6), _buildPdfRow('Phân loại:', request.phanLoai ?? 'N/A', font, fontBold), pw.SizedBox(height: 6), _buildPdfRow('Địa chỉ:', request.diaChi ?? 'N/A', font, fontBold), pw.SizedBox(height: 6), _buildPdfRow('Người tạo:', request.nguoiTao ?? 'N/A', font, fontBold), pw.SizedBox(height: 6), _buildPdfRow('Ngày tạo:', request.ngay != null ? '${request.ngay!.day}/${request.ngay!.month}/${request.ngay!.year} ${request.gio ?? ""}' : 'N/A', font, fontBold), pw.SizedBox(height: 6), _buildPdfRow('Trạng thái:', request.trangThai ?? 'N/A', font, fontBold), if (request.moTa != null && request.moTa!.isNotEmpty) ...[pw.SizedBox(height: 6), _buildPdfRow('Mô tả:', request.moTa!, font, fontBold)]])), pw.SizedBox(height: 20), pw.Text('DANH SÁCH MÁY MÓC', style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.green800)), pw.SizedBox(height: 10), if (details.isEmpty) pw.Text('Không có máy móc nào', style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey600)) else pw.Table.fromTextArray(headers: ['#', 'Loại máy', 'Mã máy', 'Hãng', 'Đơn giá', 'SL', 'Tình trạng', 'Thành tiền/tháng'], data: List.generate(details.length, (index) {
        final detail = details[index];
        return ['${index + 1}', detail.loaiMay ?? 'N/A', detail.maMay ?? 'N/A', detail.hangMay ?? 'N/A', '${detail.donGia ?? 0}', '${detail.soLuong ?? 0}', '${((detail.tinhTrang ?? 0) * 100).toStringAsFixed(0)}%', '${detail.thanhTienThang ?? 0}'];
      }), border: pw.TableBorder.all(color: PdfColors.grey400), headerStyle: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white), headerDecoration: pw.BoxDecoration(color: PdfColors.blue700), cellStyle: pw.TextStyle(font: font, fontSize: 9), cellHeight: 30, cellAlignments: {0: pw.Alignment.center, 1: pw.Alignment.centerLeft, 2: pw.Alignment.centerLeft, 3: pw.Alignment.centerLeft, 4: pw.Alignment.centerRight, 5: pw.Alignment.center, 6: pw.Alignment.center, 7: pw.Alignment.centerRight}), pw.SizedBox(height: 20), pw.Container(padding: pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(color: PdfColors.yellow50, border: pw.Border.all(color: PdfColors.orange300)), child: pw.Text('Tổng số máy móc: ${details.length} loại', style: pw.TextStyle(font: fontBold, fontSize: 12)))];
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
  pw.Widget _buildPdfRow(String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.SizedBox(width: 120, child: pw.Text(label, style: pw.TextStyle(font: fontBold, fontSize: 10))), pw.Expanded(child: pw.Text(value, style: pw.TextStyle(font: font, fontSize: 10)))]);
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
    return Scaffold(appBar: AppBar(title: Text('Quản lý yêu cầu máy móc'), flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1976D2), Color(0xFF42A5F5)]))), foregroundColor: Colors.white), body: Column(children: [Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 1, blurRadius: 3, offset: Offset(0, 2))]), child: Column(children: [Row(children: [Icon(Icons.filter_list, color: Color(0xFF1976D2)), SizedBox(width: 8), Text('Lọc theo trạng thái:', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(width: 12), Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _filterOptions.map((option) {
      final isSelected = _selectedFilter == option;
      return Padding(padding: EdgeInsets.only(right: 8), child: FilterChip(label: Text(option), selected: isSelected, onSelected: (selected) {
        setState(() {
          _selectedFilter = option;
          _filterRequests();
        });
      }, backgroundColor: Colors.grey[200], selectedColor: Color(0xFF1976D2), labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)));
    }).toList())))])])), Expanded(child: _isLoading ? Center(child: CircularProgressIndicator()) : _filteredRequests.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox, size: 64, color: Colors.grey), SizedBox(height: 16), Text('Không có yêu cầu nào', style: TextStyle(fontSize: 16, color: Colors.grey[600]))])) : ListView.builder(padding: EdgeInsets.all(16), itemCount: _filteredRequests.length, itemBuilder: (context, index) {
      final request = _filteredRequests[index];
      final details = _requestDetails[request.yeuCauId] ?? [];
      final isDraft = request.trangThai == 'Nháp';
      final needsManagerApproval = request.trangThai == 'Gửi' && isManager;
      final needsFinanceApproval = request.trangThai == 'TPKD Duyệt' && isFinance;
      return Card(margin: EdgeInsets.only(bottom: 12), elevation: 2, child: InkWell(onTap: () => _showRequestDetails(request), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: _getStatusColor(request.trangThai).withOpacity(0.1), borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(_getStatusIcon(request.trangThai), color: _getStatusColor(request.trangThai), size: 20), SizedBox(width: 8), Expanded(child: Text(request.tenHopDong ?? 'N/A', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))), Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _getStatusColor(request.trangThai), borderRadius: BorderRadius.circular(12)), child: Text(request.trangThai ?? 'N/A', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))]), SizedBox(height: 12), _buildInfoRow(Icons.person, 'Người tạo', request.nguoiTao ?? 'N/A'), SizedBox(height: 6), _buildInfoRow(Icons.calendar_today, 'Ngày tạo', '${request.ngay != null ? "${request.ngay!.day}/${request.ngay!.month}/${request.ngay!.year}" : "N/A"} ${request.gio ?? ""}'), SizedBox(height: 6), _buildInfoRow(Icons.location_on, 'Địa chỉ', request.diaChi ?? 'N/A'), SizedBox(height: 6), _buildInfoRow(Icons.category, 'Phân loại', request.phanLoai ?? 'N/A'), if (details.isNotEmpty) ...[SizedBox(height: 6), _buildInfoRow(Icons.construction, 'Số máy móc', '${details.length} loại')]])), if (isDraft && request.nguoiTao == widget.username) Container(padding: EdgeInsets.all(12), child: Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _isProcessing ? null : () => _editDraftRequest(request), icon: Icon(Icons.edit, size: 18), label: Text('Chỉnh sửa'), style: OutlinedButton.styleFrom(foregroundColor: Colors.blue))), SizedBox(width: 12), Expanded(child: ElevatedButton.icon(onPressed: _isProcessing ? null : () => _sendDraftRequest(request), icon: Icon(Icons.send, size: 18), label: Text('Gửi yêu cầu'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white)))])), if (needsManagerApproval || needsFinanceApproval) Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange[50], border: Border(top: BorderSide(color: Colors.orange[200]!))), child: Column(children: [Row(children: [Icon(Icons.warning_amber, color: Colors.orange, size: 20), SizedBox(width: 8), Text('Yêu cầu này cần duyệt của bạn', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[900]))]), SizedBox(height: 12), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _isProcessing ? null : () => _rejectRequest(request, needsManagerApproval), icon: Icon(Icons.close, size: 18), label: Text('Từ chối'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red))), SizedBox(width: 12), Expanded(child: ElevatedButton.icon(onPressed: _isProcessing ? null : () => _approveRequest(request, needsManagerApproval), icon: Icon(Icons.check, size: 18), label: Text('Duyệt'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white)))])]))])));
    })), if (_isProcessing) LinearProgressIndicator()]));
  }
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 16, color: Colors.grey[600]), SizedBox(width: 8), SizedBox(width: 100, child: Text('$label:', style: TextStyle(fontSize: 13, color: Colors.grey[700]))), Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: Colors.black87)))]);
  }
}