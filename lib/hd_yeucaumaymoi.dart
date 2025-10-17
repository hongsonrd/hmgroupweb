import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'db_helper.dart';
import 'table_models.dart';

class HDYeuCauMayMoiScreen extends StatefulWidget {
  final String username;
  final String userRole;
  final String currentPeriod;
  final String nextPeriod;
  final LinkYeuCauMayModel? existingRequest;
  final List<LinkYeuCauMayChiTietModel>? existingDetails;

  const HDYeuCauMayMoiScreen({
    Key? key,
    required this.username,
    required this.userRole,
    required this.currentPeriod,
    required this.nextPeriod,
    this.existingRequest,
    this.existingDetails,
  }) : super(key: key);

  @override
  _HDYeuCauMayMoiScreenState createState() => _HDYeuCauMayMoiScreenState();
}

class _HDYeuCauMayMoiScreenState extends State<HDYeuCauMayMoiScreen> {
  final DBHelper _dbHelper = DBHelper();
  final _formKey = GlobalKey<FormState>();
  final String baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  final TextEditingController _diaChiController = TextEditingController();
  final TextEditingController _moTaController = TextEditingController();
  
  List<LinkHopDongModel> _allContracts = [];
  List<LinkHopDongModel> _latestContracts = [];
  LinkHopDongModel? _selectedContract;
  List<LinkYeuCauMayChiTietModel> _chiTietList = [];
  List<LinkDanhMucMayModel> _allDanhMucMay = [];
  List<String> _uniqueLoaiMay = [];
  Map<String, List<String>> _maMayByLoaiMay = {};
  Map<String, String> _hangMayByMaMay = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _diaChiController.dispose();
    _moTaController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });
    try {
      final contracts = await _dbHelper.getLinkHopDongsByUser(widget.username);
      final danhMucMay = await _dbHelper.getAllLinkDanhMucMays();
      final uniqueLoaiMaySet = <String>{};
      final maMayByLoaiMay = <String, Set<String>>{};
      final hangMayByMaMay = <String, String>{};
      
      for (var item in danhMucMay) {
        if (item.loaiMay != null && item.loaiMay!.isNotEmpty) {
          uniqueLoaiMaySet.add(item.loaiMay!);
          if (!maMayByLoaiMay.containsKey(item.loaiMay!)) {
            maMayByLoaiMay[item.loaiMay!] = <String>{};
          }
          if (item.maMay != null && item.maMay!.isNotEmpty) {
            maMayByLoaiMay[item.loaiMay!]!.add(item.maMay!);
            final key = '${item.loaiMay}_${item.maMay}';
            if (item.hangMay != null) {
              hangMayByMaMay[key] = item.hangMay!;
            }
          }
        }
      }
      
      List<LinkHopDongModel> latestContracts = [];
      if (contracts.isNotEmpty) {
        final latestMonth = contracts.first.thang;
        latestContracts = contracts.where((c) => c.thang == latestMonth).toList();
      }
      
      setState(() {
        _allContracts = contracts;
        _latestContracts = latestContracts;
        _allDanhMucMay = danhMucMay;
        _uniqueLoaiMay = uniqueLoaiMaySet.toList()..sort();
        _maMayByLoaiMay = maMayByLoaiMay.map((key, value) => MapEntry(key, value.toList()..sort()));
        _hangMayByMaMay = hangMayByMaMay;
        _isLoading = false;
      });
      
      if (latestContracts.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không tìm thấy hợp đồng nào. Vui lòng tạo hợp đồng trước.'), backgroundColor: Colors.orange, duration: Duration(seconds: 4)));
      }
    } catch (e) {
      print('Error loading data: $e');
      setState(() { _isLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi tải dữ liệu: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _onContractSelected(LinkHopDongModel? contract) {
    setState(() {
      _selectedContract = contract;
      if (contract != null) {
        _diaChiController.text = contract.diaChi ?? '';
      } else {
        _diaChiController.clear();
      }
    });
  }

  void _addChiTiet() {
    showDialog(context: context, builder: (context) => _ChiTietDialog(uniqueLoaiMay: _uniqueLoaiMay, maMayByLoaiMay: _maMayByLoaiMay, hangMayByMaMay: _hangMayByMaMay, onSave: (chiTiet) { setState(() { _chiTietList.add(chiTiet); }); }));
  }

  void _editChiTiet(int index) {
    showDialog(context: context, builder: (context) => _ChiTietDialog(uniqueLoaiMay: _uniqueLoaiMay, maMayByLoaiMay: _maMayByLoaiMay, hangMayByMaMay: _hangMayByMaMay, existingChiTiet: _chiTietList[index], onSave: (chiTiet) { setState(() { _chiTietList[index] = chiTiet; }); }));
  }

  void _deleteChiTiet(int index) {
    setState(() { _chiTietList.removeAt(index); });
  }

  Future<void> _saveRequest(bool isDraft) async {
    if (!isDraft && !_formKey.currentState!.validate()) return;
    if (_selectedContract == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vui lòng chọn hợp đồng'), backgroundColor: Colors.red));
      return;
    }
    if (!isDraft && _chiTietList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vui lòng thêm ít nhất một máy móc'), backgroundColor: Colors.red));
      return;
    }
    setState(() { _isSaving = true; });
    try {
      final yeuCauId = Uuid().v4();
      final now = DateTime.now();
      final request = LinkYeuCauMayModel(yeuCauId: yeuCauId, nguoiTao: widget.username, ngay: now, gio: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}', hopDongId: _selectedContract!.uid, phanLoai: _selectedContract!.loaiHinh, tenHopDong: _selectedContract!.tenHopDong, diaChi: _diaChiController.text.trim(), moTa: _moTaController.text.trim(), trangThai: isDraft ? 'Nháp' : 'Gửi');
      final chiTietListWithYeuCauId = _chiTietList.map((chiTiet) => LinkYeuCauMayChiTietModel(chiTietId: chiTiet.chiTietId, yeuCauId: yeuCauId, loaiMay: chiTiet.loaiMay, maMay: chiTiet.maMay, hangMay: chiTiet.hangMay, tanSuatSuDung: chiTiet.tanSuatSuDung, donGia: chiTiet.donGia, tinhTrang: chiTiet.tinhTrang, soThangKhauHao: chiTiet.soThangKhauHao, soLuong: chiTiet.soLuong, thanhTienThang: chiTiet.thanhTienThang, ghiChu: chiTiet.ghiChu)).toList();
      
      final apiResult = await _sendToAPI(request, chiTietListWithYeuCauId);
      
      if (!apiResult['success']) {
        throw Exception(apiResult['message']);
      }
      
      await _dbHelper.insertLinkYeuCauMay(request);
      for (var chiTiet in chiTietListWithYeuCauId) {
        await _dbHelper.insertLinkYeuCauMayChiTiet(chiTiet);
      }
      
      if (!mounted) return;
      
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 32), SizedBox(width: 12), Text('Thành công')]),
          content: Text('${isDraft ? 'Đã lưu nháp' : 'Đã gửi yêu cầu'} thành công!\n\nVui lòng đồng bộ dữ liệu từ màn hình chính để cập nhật thông tin mới nhất.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              child: Text('Đồng ý'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error saving request: $e');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(children: [Icon(Icons.error, color: Colors.red, size: 32), SizedBox(width: 12), Text('Lỗi')]),
          content: Text('Không thể gửi yêu cầu lên máy chủ.\n\nChi tiết: $e\n\nVui lòng kiểm tra kết nối mạng và thử lại.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Đóng')),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  Future<Map<String, dynamic>> _sendToAPI(LinkYeuCauMayModel request, List<LinkYeuCauMayChiTietModel> chiTietList) async {
    try {
      final requestResponse = await http.post(Uri.parse('$baseUrl/guiyeucaumay'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(request.toMap())).timeout(Duration(seconds: 30));
      
      if (requestResponse.statusCode != 200) {
        return {'success': false, 'message': 'Server trả về lỗi khi gửi yêu cầu chính (Status: ${requestResponse.statusCode})'};
      }
      
      for (int i = 0; i < chiTietList.length; i++) {
        final chiTiet = chiTietList[i];
        final chiTietResponse = await http.post(Uri.parse('$baseUrl/guiyeucaumaychitiet'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(chiTiet.toMap())).timeout(Duration(seconds: 30));
        
        if (chiTietResponse.statusCode != 200) {
          return {'success': false, 'message': 'Server trả về lỗi khi gửi chi tiết máy #${i + 1} (Status: ${chiTietResponse.statusCode})'};
        }
      }
      
      print('Successfully sent to API');
      return {'success': true, 'message': 'Success'};
    } catch (e) {
      print('Error sending to API: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

@override
Widget build(BuildContext context) {
  return WillPopScope(
    onWillPop: () async {
      if (_isSaving) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đang gửi yêu cầu, vui lòng đợi...'),
            backgroundColor: Colors.orange,
          ),
        );
        return false;
      }
      return true;
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text('Tạo yêu cầu máy móc mới'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang tải dữ liệu...'),
                ],
              ),
            )
          : _latestContracts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Không có hợp đồng nào',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Vui lòng tạo hợp đồng trước khi tạo yêu cầu',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back),
                        label: Text('Quay lại'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.all(16),
                          children: [
                            _buildContractCard(),
                            SizedBox(height: 16),
                            _buildRequestDetailsCard(),
                            SizedBox(height: 16),
                            _buildMachineDetailsSection(),
                            SizedBox(height: 16),
                            Card(
                              color: Color(0xFFFFF3E0),
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Color(0xFFFF6F00)),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Vui lòng thêm chi tiết máy móc trước khi gửi yêu cầu.',
                                        style: TextStyle(fontSize: 13, color: Color(0xFFE65100)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            _buildUserInfo(),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 5,
                              offset: Offset(0, -3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: (_isSaving || _selectedContract == null)
                                    ? null
                                    : () => _saveRequest(true),
                                icon: Icon(Icons.save_outlined),
                                label: Text('Lưu nháp'),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(color: Color(0xFF1976D2), width: 1.5),
                                  foregroundColor: Color(0xFF1976D2),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: (_isSaving || _selectedContract == null)
                                    ? null
                                    : () => _saveRequest(false),
                                icon: _isSaving
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Icon(Icons.send),
                                label: Text(_isSaving ? 'Đang gửi...' : 'Gửi yêu cầu'),
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: Color(0xFF4CAF50),
                                  foregroundColor: Colors.white,
                                  elevation: 3,
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

  Widget _buildContractCard() {
    return Card(elevation: 2, child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.assignment, color: Color(0xFF1976D2), size: 24), SizedBox(width: 8), Text('Chọn hợp đồng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)))]), SizedBox(height: 16), DropdownButtonFormField<LinkHopDongModel>(value: _selectedContract, decoration: InputDecoration(labelText: 'Hợp đồng *', hintText: 'Chọn hợp đồng', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: Icon(Icons.description, color: Color(0xFF1976D2))), isExpanded: true, items: _latestContracts.map((contract) => DropdownMenuItem<LinkHopDongModel>(value: contract, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(contract.tenHopDong ?? 'N/A', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis), Text('Loại: ${contract.loaiHinh ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey[600]))]))).toList(), onChanged: _isSaving ? null : _onContractSelected, validator: (value) => value == null ? 'Vui lòng chọn hợp đồng' : null), if (_selectedContract != null) ...[SizedBox(height: 16), Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(8), border: Border.all(color: Color(0xFF90CAF9))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildInfoRow('Mã HĐ:', _selectedContract!.uid ?? 'N/A'), SizedBox(height: 8), _buildInfoRow('Tên HĐ:', _selectedContract!.tenHopDong ?? 'N/A'), SizedBox(height: 8), _buildInfoRow('Loại hình:', _selectedContract!.loaiHinh ?? 'N/A'), SizedBox(height: 8), _buildInfoRow('Tháng:', _selectedContract!.thang ?? 'N/A')]))]])));
  }

  Widget _buildRequestDetailsCard() {
    return Card(elevation: 2, child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.edit_note, color: Color(0xFF1976D2), size: 24), SizedBox(width: 8), Text('Chi tiết yêu cầu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)))]), SizedBox(height: 16), TextFormField(controller: _diaChiController, decoration: InputDecoration(labelText: 'Địa chỉ công trường *', hintText: 'Nhập địa chỉ công trường', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: Icon(Icons.location_on, color: Color(0xFF1976D2)), helperText: 'Bạn có thể chỉnh sửa địa chỉ nếu cần'), maxLines: 2, enabled: !_isSaving && _selectedContract != null, validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập địa chỉ' : null), SizedBox(height: 16), TextFormField(controller: _moTaController, decoration: InputDecoration(labelText: 'Mô tả yêu cầu', hintText: 'Nhập mô tả chi tiết về yêu cầu máy móc', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: Icon(Icons.notes, color: Color(0xFF1976D2))), maxLines: 4, enabled: !_isSaving)])));
  }

  Widget _buildMachineDetailsSection() {
    return Card(elevation: 2, child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.precision_manufacturing, color: Color(0xFF1976D2), size: 24), SizedBox(width: 8), Expanded(child: Text('Chi tiết máy móc', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)))), ElevatedButton.icon(onPressed: _isSaving ? null : _addChiTiet, icon: Icon(Icons.add, size: 20), label: Text('Thêm máy'), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF4CAF50), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)))]), SizedBox(height: 16), if (_chiTietList.isEmpty) Container(padding: EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)), child: Center(child: Column(children: [Icon(Icons.construction, size: 48, color: Colors.grey), SizedBox(height: 12), Text('Chưa có máy móc nào', style: TextStyle(fontSize: 16, color: Colors.grey[600])), SizedBox(height: 8), Text('Nhấn "Thêm máy" để bắt đầu', style: TextStyle(fontSize: 14, color: Colors.grey[500]))]))) else ListView.separated(shrinkWrap: true, physics: NeverScrollableScrollPhysics(), itemCount: _chiTietList.length, separatorBuilder: (context, index) => SizedBox(height: 8), itemBuilder: (context, index) => _buildChiTietCard(_chiTietList[index], index))])));
  }

  Widget _buildChiTietCard(LinkYeuCauMayChiTietModel chiTiet, int index) {
    return Card(elevation: 1, color: Colors.grey[50], child: Padding(padding: EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Color(0xFF1976D2), borderRadius: BorderRadius.circular(4)), child: Text('#${index + 1}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))), SizedBox(width: 12), Expanded(child: Text(chiTiet.loaiMay ?? 'N/A', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), IconButton(icon: Icon(Icons.edit, color: Colors.blue), onPressed: _isSaving ? null : () => _editChiTiet(index), tooltip: 'Chỉnh sửa'), IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: _isSaving ? null : () => _deleteChiTiet(index), tooltip: 'Xóa')]), Divider(), _buildChiTietInfoRow('Mã máy:', chiTiet.maMay ?? 'N/A'), _buildChiTietInfoRow('Hãng máy:', chiTiet.hangMay ?? 'N/A'), _buildChiTietInfoRow('Tần suất:', chiTiet.tanSuatSuDung ?? 'N/A'), _buildChiTietInfoRow('Đơn giá:', '${chiTiet.donGia?.toString() ?? '0'} VNĐ'), _buildChiTietInfoRow('Tình trạng:', '${((chiTiet.tinhTrang ?? 0) * 100).toStringAsFixed(0)}%'), _buildChiTietInfoRow('Số tháng khấu hao:', chiTiet.soThangKhauHao?.toString() ?? '0'), _buildChiTietInfoRow('Số lượng:', chiTiet.soLuong?.toString() ?? '0'), _buildChiTietInfoRow('Thành tiền/tháng:', '${chiTiet.thanhTienThang?.toString() ?? '0'} VNĐ', isHighlight: true), if (chiTiet.ghiChu != null && chiTiet.ghiChu!.isNotEmpty) _buildChiTietInfoRow('Ghi chú:', chiTiet.ghiChu!)])));
  }

  Widget _buildChiTietInfoRow(String label, String value, {bool isHighlight = false}) {
    return Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 140, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700]))), Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal, color: isHighlight ? Color(0xFF1976D2) : Colors.black87)))]));
  }

  Widget _buildUserInfo() {
    return Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.person, size: 16, color: Colors.grey[600]), SizedBox(width: 8), Text('Người tạo: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[700])), Text(widget.username, style: TextStyle(fontSize: 13, color: Colors.grey[800]))]), SizedBox(height: 8), Row(children: [Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]), SizedBox(width: 8), Text('Thời gian: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[700])), Text('${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 13, color: Colors.grey[800]))])]));
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 80, child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1565C0)))), Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: Color(0xFF0D47A1))))]);
  }
}

class _ChiTietDialog extends StatefulWidget {
  final List<String> uniqueLoaiMay;
  final Map<String, List<String>> maMayByLoaiMay;
  final Map<String, String> hangMayByMaMay;
  final LinkYeuCauMayChiTietModel? existingChiTiet;
  final Function(LinkYeuCauMayChiTietModel) onSave;

  const _ChiTietDialog({required this.uniqueLoaiMay, required this.maMayByLoaiMay, required this.hangMayByMaMay, this.existingChiTiet, required this.onSave});

  @override
  _ChiTietDialogState createState() => _ChiTietDialogState();
}

class _ChiTietDialogState extends State<_ChiTietDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedLoaiMay;
  String? _selectedMaMay;
  final TextEditingController _maMayController = TextEditingController();
  final TextEditingController _hangMayController = TextEditingController();
  final TextEditingController _tanSuatController = TextEditingController();
  final TextEditingController _donGiaController = TextEditingController();
  final TextEditingController _tinhTrangController = TextEditingController();
  final TextEditingController _soThangKhauHaoController = TextEditingController();
  final TextEditingController _soLuongController = TextEditingController();
  final TextEditingController _ghiChuController = TextEditingController();
  List<String> _availableMaMay = [];
  int _thanhTienThang = 0;
  final List<String> _tanSuatSuggestions = ['Hàng ngày', 'Hàng tuần', 'Hàng tháng', 'Hàng quý'];

  @override
  void initState() {
    super.initState();
    if (widget.existingChiTiet != null) {
      _selectedLoaiMay = widget.existingChiTiet!.loaiMay;
      _selectedMaMay = widget.existingChiTiet!.maMay;
      _maMayController.text = widget.existingChiTiet!.maMay ?? '';
      _hangMayController.text = widget.existingChiTiet!.hangMay ?? '';
      _tanSuatController.text = widget.existingChiTiet!.tanSuatSuDung ?? '';
      _donGiaController.text = widget.existingChiTiet!.donGia?.toString() ?? '';
      _tinhTrangController.text = ((widget.existingChiTiet!.tinhTrang ?? 0) * 100).toStringAsFixed(0);
      _soThangKhauHaoController.text = widget.existingChiTiet!.soThangKhauHao?.toString() ?? '';
      _soLuongController.text = widget.existingChiTiet!.soLuong?.toString() ?? '';
      _ghiChuController.text = widget.existingChiTiet!.ghiChu ?? '';
      _thanhTienThang = widget.existingChiTiet!.thanhTienThang ?? 0;
      if (_selectedLoaiMay != null) {
        _availableMaMay = widget.maMayByLoaiMay[_selectedLoaiMay!] ?? [];
      }
    }
    _donGiaController.addListener(_calculateThanhTien);
    _tinhTrangController.addListener(_calculateThanhTien);
    _soThangKhauHaoController.addListener(_calculateThanhTien);
    _soLuongController.addListener(_calculateThanhTien);
  }

  @override
  void dispose() {
    _maMayController.dispose();
    _hangMayController.dispose();
    _tanSuatController.dispose();
    _donGiaController.dispose();
    _tinhTrangController.dispose();
    _soThangKhauHaoController.dispose();
    _soLuongController.dispose();
    _ghiChuController.dispose();
    super.dispose();
  }

  void _onLoaiMayChanged(String? loaiMay) {
    setState(() {
      _selectedLoaiMay = loaiMay;
      _selectedMaMay = null;
      _maMayController.clear();
      _hangMayController.clear();
      _availableMaMay = widget.maMayByLoaiMay[loaiMay!] ?? [];
    });
  }

  void _onMaMayChanged(String? maMay) {
    setState(() {
      _selectedMaMay = maMay;
      _maMayController.text = maMay ?? '';
      if (_selectedLoaiMay != null && maMay != null) {
        final key = '${_selectedLoaiMay}_$maMay';
        _hangMayController.text = widget.hangMayByMaMay[key] ?? '';
      }
    });
  }

  void _calculateThanhTien() {
    final donGia = int.tryParse(_donGiaController.text) ?? 0;
    final tinhTrangPercent = double.tryParse(_tinhTrangController.text) ?? 0;
    final tinhTrang = tinhTrangPercent / 100;
    final soThangKhauHao = int.tryParse(_soThangKhauHaoController.text) ?? 1;
    final soLuong = int.tryParse(_soLuongController.text) ?? 0;
    if (soThangKhauHao > 0) {
      setState(() { _thanhTienThang = ((donGia * soLuong * tinhTrang) / soThangKhauHao).round(); });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final chiTiet = LinkYeuCauMayChiTietModel(chiTietId: widget.existingChiTiet?.chiTietId ?? Uuid().v4(), yeuCauId: widget.existingChiTiet?.yeuCauId, loaiMay: _selectedLoaiMay, maMay: _maMayController.text.trim(), hangMay: _hangMayController.text.trim(), tanSuatSuDung: _tanSuatController.text.trim(), donGia: int.tryParse(_donGiaController.text), tinhTrang: (double.tryParse(_tinhTrangController.text) ?? 0) / 100, soThangKhauHao: int.tryParse(_soThangKhauHaoController.text), soLuong: int.tryParse(_soLuongController.text), thanhTienThang: _thanhTienThang, ghiChu: _ghiChuController.text.trim());
    widget.onSave(chiTiet);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(child: Container(width: MediaQuery.of(context).size.width * 0.9, constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: Color(0xFF1976D2), borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))), child: Row(children: [Icon(Icons.precision_manufacturing, color: Colors.white), SizedBox(width: 12), Expanded(child: Text(widget.existingChiTiet == null ? 'Thêm máy móc' : 'Chỉnh sửa máy móc', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))), IconButton(icon: Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))])), Expanded(child: Form(key: _formKey, child: ListView(padding: EdgeInsets.all(16), children: [DropdownButtonFormField<String>(value: _selectedLoaiMay, decoration: InputDecoration(labelText: 'Loại máy *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: Icon(Icons.category)), items: widget.uniqueLoaiMay.map((loaiMay) => DropdownMenuItem(value: loaiMay, child: Text(loaiMay))).toList(), onChanged: _onLoaiMayChanged, validator: (value) => value == null ? 'Vui lòng chọn loại máy' : null), SizedBox(height: 16), if (_availableMaMay.isNotEmpty) DropdownButtonFormField<String>(value: _selectedMaMay, decoration: InputDecoration(labelText: 'Mã máy (chọn)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: Icon(Icons.code)), items: _availableMaMay.map((maMay) => DropdownMenuItem(value: maMay, child: Text(maMay))).toList(), onChanged: _onMaMayChanged), if (_availableMaMay.isNotEmpty) SizedBox(height: 16), TextFormField(controller: _maMayController, decoration: InputDecoration(labelText: 'Mã máy (nhập hoặc chỉnh sửa) *', hintText: 'Nhập mã máy', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: Icon(Icons.qr_code)), validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập mã máy' : null), SizedBox(height: 16), TextFormField(controller: _hangMayController, decoration: InputDecoration(labelText: 'Hãng máy *', hintText: 'Nhập hãng máy', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: Icon(Icons.business)), validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập hãng máy' : null), SizedBox(height: 16), Autocomplete<String>(initialValue: TextEditingValue(text: _tanSuatController.text), optionsBuilder: (TextEditingValue textEditingValue) { if (textEditingValue.text.isEmpty) return _tanSuatSuggestions; return _tanSuatSuggestions.where((suggestion) => suggestion.toLowerCase().contains(textEditingValue.text.toLowerCase())); }, onSelected: (String selection) { _tanSuatController.text = selection; }, fieldViewBuilder: (context, controller, focusNode, onEditingComplete) { controller.text = _tanSuatController.text; controller.addListener(() { _tanSuatController.text = controller.text; }); return TextFormField(controller: controller, focusNode: focusNode, decoration: InputDecoration(labelText: 'Tần suất sử dụng', hintText: 'Nhập hoặc chọn tần suất', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: Icon(Icons.access_time))); }), SizedBox(height: 16), TextFormField(controller: _donGiaController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: 'Đơn giá *', hintText: 'Nhập đơn giá', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: Icon(Icons.attach_money), suffixText: 'VNĐ'), validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập đơn giá' : null), SizedBox(height: 16), TextFormField(controller: _tinhTrangController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}$'))], decoration: InputDecoration(labelText: 'Tình trạng (%) *', hintText: 'Nhập % từ 0-100', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: Icon(Icons.speed), suffixText: '%'), validator: (value) { if (value == null || value.trim().isEmpty) return 'Vui lòng nhập tình trạng'; final val = int.tryParse(value); if (val == null || val < 0 || val > 100) return 'Giá trị từ 0-100'; return null; }), SizedBox(height: 16), TextFormField(controller: _soThangKhauHaoController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: 'Số tháng khấu hao *', hintText: 'Nhập số tháng (1-100)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: Icon(Icons.calendar_month)), validator: (value) { if (value == null || value.trim().isEmpty) return 'Vui lòng nhập số tháng khấu hao'; final val = int.tryParse(value); if (val == null || val < 1 || val > 100) return 'Giá trị từ 1-100'; return null; }), SizedBox(height: 16), TextFormField(controller: _soLuongController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: 'Số lượng *', hintText: 'Nhập số lượng', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: Icon(Icons.numbers)), validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập số lượng' : null), SizedBox(height: 16), Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8), border: Border.all(color: Color(0xFF4CAF50))), child: Row(children: [Icon(Icons.calculate, color: Color(0xFF4CAF50)), SizedBox(width: 12), Text('Thành tiền/tháng: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2E7D32))), Text('$_thanhTienThang VNĐ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)))])), SizedBox(height: 16), TextFormField(controller: _ghiChuController, decoration: InputDecoration(labelText: 'Ghi chú', hintText: 'Nhập ghi chú (nếu có)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: Icon(Icons.note)), maxLines: 3)]))), Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[300]!))), child: Row(children: [Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text('Hủy'), style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)))), SizedBox(width: 12), Expanded(child: ElevatedButton(onPressed: _save, child: Text('Lưu'), style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14), backgroundColor: Color(0xFF4CAF50), foregroundColor: Colors.white)))]))])));
  }
}