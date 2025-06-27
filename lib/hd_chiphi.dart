// hd_chiphi.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'table_models.dart';
import 'db_helper.dart';

// Context class to pass data between files
class HDChiPhiContext {
  final String costType;
  final String username;
  final String userRole;
  final String? hopDongUid;
  final String hopDongThang;
  final String hopDongTen;
  final String hopDongMaKinhDoanh;
  final String currentPeriod;
  final String nextPeriod;
  final int currentCostValue;
  final Function(String costType, int newValue) onCostUpdated;

  HDChiPhiContext({
    required this.costType,
    required this.username,
    required this.userRole,
    this.hopDongUid,
    required this.hopDongThang,
    required this.hopDongTen,
    required this.hopDongMaKinhDoanh,
    required this.currentPeriod,
    required this.nextPeriod,
    required this.currentCostValue,
    required this.onCostUpdated,
  });
}

// Main class for handling cost editing
class HDChiPhi {
  static const String _apiUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app/universal';
  static final Uuid _uuid = Uuid();

  static void editCost({
    required BuildContext context,
    required HDChiPhiContext costContext,
  }) {
    // Check if user can edit (only current/next period and correct user/admin)
    if (!_canEditCost(costContext)) {
      _showErrorDialog(context, 'Bạn không có quyền chỉnh sửa chi phí này');
      return;
    }

    // Show the appropriate cost editing dialog based on cost type
    switch (costContext.costType) {
      case 'VatLieu':
        _showVatLieuDialog(context, costContext);
        break;
      case 'CVDinhKy':
        _showDinhKyDialog(context, costContext);
        break;
      case 'LeTetTCa':
        _showLeTetTCDialog(context, costContext);
        break;
      case 'PhuCap':
        _showPhuCapDialog(context, costContext);
        break;
      case 'NgoaiGiao':
        _showNgoaiGiaoDialog(context, costContext);
        break;
      case 'MayMoc':
        _showMayMocDialog(context, costContext);
        break;
      case 'Luong':
        _showLuongDialog(context, costContext);
        break;
      default:
        _showErrorDialog(context, 'Loại chi phí không hợp lệ');
    }
  }

  static bool _canEditCost(HDChiPhiContext context) {
    // Check if contract month is current or next period
    //bool isValidPeriod = context.hopDongThang == context.currentPeriod || 
    //                    context.hopDongThang == context.nextPeriod;
    
    // Check if user is admin or the creator
    //bool hasPermission = context.userRole == 'Admin' || 
    //                    context.username == context.hopDongTen; // Assuming nguoiTao matches username
    
    //return isValidPeriod && hasPermission;
    return true;
  }

  // VatLieu Dialog
  static void _showVatLieuDialog(BuildContext context, HDChiPhiContext costContext) {
    showDialog(
      context: context,
      builder: (context) => _VatLieuDialog(costContext: costContext),
    );
  }

  // DinhKy Dialog
  static void _showDinhKyDialog(BuildContext context, HDChiPhiContext costContext) {
    showDialog(
      context: context,
      builder: (context) => _DinhKyDialog(costContext: costContext),
    );
  }

  // LeTetTC Dialog
  static void _showLeTetTCDialog(BuildContext context, HDChiPhiContext costContext) {
    showDialog(
      context: context,
      builder: (context) => _LeTetTCDialog(costContext: costContext),
    );
  }

  // PhuCap Dialog
  static void _showPhuCapDialog(BuildContext context, HDChiPhiContext costContext) {
    showDialog(
      context: context,
      builder: (context) => _PhuCapDialog(costContext: costContext),
    );
  }

  // NgoaiGiao Dialog
  static void _showNgoaiGiaoDialog(BuildContext context, HDChiPhiContext costContext) {
    showDialog(
      context: context,
      builder: (context) => _NgoaiGiaoDialog(costContext: costContext),
    );
  }

  // MayMoc Dialog
  static void _showMayMocDialog(BuildContext context, HDChiPhiContext costContext) {
    showDialog(
      context: context,
      builder: (context) => _MayMocDialog(costContext: costContext),
    );
  }

  // Luong Dialog
  static void _showLuongDialog(BuildContext context, HDChiPhiContext costContext) {
    showDialog(
      context: context,
      builder: (context) => _LuongDialog(costContext: costContext),
    );
  }

  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lỗi'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Send data to server
  static Future<bool> _sendDataToServer(Map<String, dynamic> data) async {
    print(jsonEncode(data));
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error sending data to server: $e');
      return false;
    }
  }

  // Calculate total cost for a specific cost type
  static Future<int> _calculateTotalCost(String hopDongID, String costType) async {
    final dbHelper = DBHelper();
    
    switch (costType) {
  case 'VatLieu':
    final records = await dbHelper.getLinkVatTusByContract(hopDongID);
    return records.fold<int>(0, (sum, record) => sum + (record.thanhTien ?? 0));
  case 'CVDinhKy':
    final records = await dbHelper.getLinkDinhKysByContract(hopDongID);
    return records.fold<int>(0, (sum, record) => sum + (record.thanhTien ?? 0));
  case 'LeTetTCa':
    final records = await dbHelper.getLinkLeTetTCsByContract(hopDongID);
    return records.fold<int>(0, (sum, record) => sum + (record.thanhTienTrenThang ?? 0));
  case 'PhuCap':
    final records = await dbHelper.getLinkPhuCapsByContract(hopDongID);
    return records.fold<int>(0, (sum, record) => sum + (record.thanhTienTrenThang ?? 0));
  case 'NgoaiGiao':
    final records = await dbHelper.getLinkNgoaiGiaosByContract(hopDongID);
    return records.fold<int>(0, (sum, record) => sum + (record.thanhTienTrenThang ?? 0));
  case 'MayMoc':
    final records = await dbHelper.getLinkMayMocsByContract(hopDongID);
    return records.fold<int>(0, (sum, record) => sum + (record.thanhTienThang ?? 0));
  case 'Luong':
    final records = await dbHelper.getLinkLuongsByContract(hopDongID);
    return records.fold<int>(0, (sum, record) => sum + (record.thanhTien ?? 0));
  default:
    return 0;
}
  }
}

// VatLieu Dialog Widget
class _VatLieuDialog extends StatefulWidget {
  final HDChiPhiContext costContext;

  const _VatLieuDialog({required this.costContext});

  @override
  _VatLieuDialogState createState() => _VatLieuDialogState();
}

class _VatLieuDialogState extends State<_VatLieuDialog> {
  final _formKey = GlobalKey<FormState>();
  final _danhMucController = TextEditingController();
  final _nhanHieuController = TextEditingController();
  final _quyCachController = TextEditingController();
  final _donViTinhController = TextEditingController();
  final _donGiaController = TextEditingController();
  final _soLuongController = TextEditingController();
  
  List<LinkVatTuModel> _records = [];
  bool _isLoading = true;
  int _thanhTien = 0;
  
  // Add edit mode variables
  bool _isEditMode = false;
  LinkVatTuModel? _editingRecord;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _donGiaController.addListener(_calculateThanhTien);
    _soLuongController.addListener(_calculateThanhTien);
  }

  void _calculateThanhTien() {
    final donGia = int.tryParse(_donGiaController.text) ?? 0;
    final soLuong = double.tryParse(_soLuongController.text) ?? 0.0;
    setState(() {
      _thanhTien = (donGia * soLuong).round();
    });
  }

  Future<void> _loadRecords() async {
    if (widget.costContext.hopDongUid != null) {
      final dbHelper = DBHelper();
      final records = await dbHelper.getLinkVatTusByContract(widget.costContext.hopDongUid!);
      setState(() {
        _records = records;
        _isLoading = false;
      });
    }
  }

  // New method to enter edit mode
  void _enterEditMode(LinkVatTuModel record) {
    setState(() {
      _isEditMode = true;
      _editingRecord = record;
      
      // Pre-populate form fields
      _danhMucController.text = record.danhMucVatTuTieuHao ?? '';
      _nhanHieuController.text = record.nhanHieu ?? '';
      _quyCachController.text = record.quyCach ?? '';
      _donViTinhController.text = record.donViTinh ?? '';
      _donGiaController.text = (record.donGiaCapKhachHang ?? 0).toString();
      _soLuongController.text = (record.soLuong ?? 0).toString();
      
      // Trigger calculation
      _calculateThanhTien();
    });
  }

  // New method to exit edit mode
  void _exitEditMode() {
    setState(() {
      _isEditMode = false;
      _editingRecord = null;
    });
    _clearForm();
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isEditMode && _editingRecord != null) {
      // Update existing record
      final updatedRecord = _editingRecord!.copyWith(
        danhMucVatTuTieuHao: _danhMucController.text.trim(),
        nhanHieu: _nhanHieuController.text.trim(),
        quyCach: _quyCachController.text.trim(),
        donViTinh: _donViTinhController.text.trim(),
        donGiaCapKhachHang: int.tryParse(_donGiaController.text),
        soLuong: double.tryParse(_soLuongController.text),
        thanhTien: _thanhTien,
      );

      // Update in local database
      final dbHelper = DBHelper();
      await dbHelper.updateLinkVatTu(updatedRecord);

      // Send update to server
      final success = await HDChiPhi._sendDataToServer({
        'table': 'LinkVatTu',
        'action': 'update',
        'data': updatedRecord.toMap(),
      });

      if (success) {
        _showSuccessMessage('Đã cập nhật thành công!');
        _exitEditMode();
        _loadRecords();
      } else {
        _showErrorMessage('Lỗi khi cập nhật dữ liệu');
      }
    } else {
      // Create new record (existing logic)
      final record = LinkVatTuModel(
        uid: HDChiPhi._uuid.v4(),
        hopDongID: widget.costContext.hopDongUid,
        thang: widget.costContext.hopDongThang,
        nguoiTao: widget.costContext.username,
        maKinhDoanh: widget.costContext.hopDongMaKinhDoanh,
        danhMucVatTuTieuHao: _danhMucController.text.trim(),
        nhanHieu: _nhanHieuController.text.trim(),
        quyCach: _quyCachController.text.trim(),
        donViTinh: _donViTinhController.text.trim(),
        donGiaCapKhachHang: int.tryParse(_donGiaController.text),
        soLuong: double.tryParse(_soLuongController.text),
        thanhTien: _thanhTien,
      );

      // Save to local database
      final dbHelper = DBHelper();
      await dbHelper.insertLinkVatTu(record);

      // Send to server
      final success = await HDChiPhi._sendDataToServer({
        'table': 'LinkVatTu',
        'action': 'insert',
        'data': record.toMap(),
      });

      if (success) {
        _showSuccessMessage('Đã lưu thành công!');
        _clearForm();
        _loadRecords();
      } else {
        _showErrorMessage('Lỗi khi lưu dữ liệu');
      }
    }

    // Recalculate total cost
    final newTotal = await HDChiPhi._calculateTotalCost(
      widget.costContext.hopDongUid!, 
      'VatLieu'
    );
    
    // Update parent screen
    widget.costContext.onCostUpdated('VatLieu', newTotal);
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$message Vui lòng lưu hợp đồng và tải lại để cập nhật.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _clearForm() {
    _danhMucController.clear();
    _nhanHieuController.clear();
    _quyCachController.clear();
    _donViTinhController.clear();
    _donGiaController.clear();
    _soLuongController.clear();
    setState(() {
      _thanhTien = 0;
    });
  }

  Future<void> _deleteRecord(String uid) async {
    final dbHelper = DBHelper();
    await dbHelper.deleteLinkVatTu(uid);

    // Send delete to server
    await HDChiPhi._sendDataToServer({
      'table': 'LinkVatTu',
      'action': 'delete',
      'uid': uid,
    });

    // Recalculate total cost
    final newTotal = await HDChiPhi._calculateTotalCost(
      widget.costContext.hopDongUid!, 
      'VatLieu'
    );
    
    // Update parent screen
    widget.costContext.onCostUpdated('VatLieu', newTotal);
    
    _loadRecords();
  }

   @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 1.4,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Chi phí Vật tư - ${widget.costContext.hopDongTen}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            
            // Add new record form
            Expanded(
              flex: 1,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Updated header to show edit mode
                        Row(
                          children: [
                            Text(
                              _isEditMode ? 'Chỉnh sửa vật tư' : 'Thêm vật tư mới', 
                              style: TextStyle(fontWeight: FontWeight.bold)
                            ),
                            if (_isEditMode) ...[
                              Spacer(),
                              TextButton(
                                onPressed: _exitEditMode,
                                child: Text('Hủy chỉnh sửa'),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                              ),
                            ],
                          ],
                        ),
                                                SizedBox(height: 8),
                        Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    ElevatedButton(
      onPressed: _saveRecord,
      child: Text(_isEditMode ? 'Cập nhật' : 'Lưu'),
    ),
    TextButton(
      onPressed: _isEditMode ? _exitEditMode : _clearForm,
      child: Text(_isEditMode ? 'Hủy' : 'Xóa form'),
    ),
  ],
),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _danhMucController,
                                decoration: InputDecoration(
                                  labelText: 'Danh mục vật tư *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _nhanHieuController,
                                decoration: InputDecoration(
                                  labelText: 'Nhãn hiệu',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _quyCachController,
                                decoration: InputDecoration(
                                  labelText: 'Quy cách',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _donViTinhController,
                                decoration: InputDecoration(
                                  labelText: 'Đơn vị',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _donGiaController,
                                decoration: InputDecoration(
                                  labelText: 'Đơn giá *',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _soLuongController,
                                decoration: InputDecoration(
                                  labelText: 'Số lượng *',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Thành tiền: ${NumberFormat('#,##0', 'vi_VN').format(_thanhTien)}',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Records list
            Expanded(
              flex: 2,
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Danh sách vật tư (${_records.length} mục)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: _isLoading
                          ? Center(child: CircularProgressIndicator())
                          : _records.isEmpty
                              ? Center(child: Text('Chưa có vật tư nào'))
                              : ListView.builder(
                                  itemCount: _records.length,
                                  itemBuilder: (context, index) {
                                    final record = _records[index];
                                    final isCurrentlyEditing = _editingRecord?.uid == record.uid;
                                    
                                    return ListTile(
                                      title: Text(record.danhMucVatTuTieuHao ?? ''),
                                      subtitle: Text(
                                        'Nhãn hiệu: ${record.nhanHieu ?? ''} | '
                                        'Số lượng: ${record.soLuong ?? 0} | '
                                        'Đơn giá: ${NumberFormat('#,##0', 'vi_VN').format(record.donGiaCapKhachHang ?? 0)}'
                                      ),
                                      tileColor: isCurrentlyEditing ? Colors.blue.withOpacity(0.1) : null,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${NumberFormat('#,##0', 'vi_VN').format(record.thanhTien ?? 0)} VND',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              isCurrentlyEditing ? Icons.cancel : Icons.edit, 
                                              color: isCurrentlyEditing ? Colors.red : Colors.blue
                                            ),
                                            onPressed: () {
                                              if (isCurrentlyEditing) {
                                                _exitEditMode();
                                              } else {
                                                _enterEditMode(record);
                                              }
                                            },
                                            tooltip: isCurrentlyEditing ? 'Hủy chỉnh sửa' : 'Chỉnh sửa',
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _deleteRecord(record.uid!),
                                            tooltip: 'Xóa',
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Đóng'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _danhMucController.dispose();
    _nhanHieuController.dispose();
    _quyCachController.dispose();
    _donViTinhController.dispose();
    _donGiaController.dispose();
    _soLuongController.dispose();
    super.dispose();
  }
}

// DinhKy Dialog Widget
class _DinhKyDialog extends StatefulWidget {
  final HDChiPhiContext costContext;

  const _DinhKyDialog({required this.costContext});

  @override
  _DinhKyDialogState createState() => _DinhKyDialogState();
}

class _DinhKyDialogState extends State<_DinhKyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _danhMucCongViecController = TextEditingController();
  final _chiTietCongViecController = TextEditingController();
  final _tongTienController = TextEditingController();
  final _tanSuatController = TextEditingController();
  final _soLuongController = TextEditingController();
  final _ghiChuController = TextEditingController();
  
  List<LinkDinhKyModel> _records = [];
  bool _isLoading = true;
  int _donGiaTrenThang = 0;
  int _thanhTien = 0;
  
  // Edit mode variables
  bool _isEditMode = false;
  LinkDinhKyModel? _editingRecord;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _tongTienController.addListener(_calculateDonGia);
    _tanSuatController.addListener(_calculateDonGia);
    _soLuongController.addListener(_calculateThanhTien);
  }

  void _calculateDonGia() {
    final tongTien = int.tryParse(_tongTienController.text) ?? 0;
    final tanSuat = double.tryParse(_tanSuatController.text) ?? 0.0;
    setState(() {
      _donGiaTrenThang = (tongTien * tanSuat).round();
      _calculateThanhTien();
    });
  }

  void _calculateThanhTien() {
    final soLuong = double.tryParse(_soLuongController.text) ?? 0.0;
    setState(() {
      _thanhTien = (_donGiaTrenThang * soLuong).round();
    });
  }

  Future<void> _loadRecords() async {
    if (widget.costContext.hopDongUid != null) {
      final dbHelper = DBHelper();
      final records = await dbHelper.getLinkDinhKysByContract(widget.costContext.hopDongUid!);
      setState(() {
        _records = records;
        _isLoading = false;
      });
    }
  }

  void _enterEditMode(LinkDinhKyModel record) {
    setState(() {
      _isEditMode = true;
      _editingRecord = record;
      
      _danhMucCongViecController.text = record.danhMucCongViec ?? '';
      _chiTietCongViecController.text = record.chiTietCongViec ?? '';
      _tongTienController.text = (record.tongTienTrenLanThucHien ?? 0).toString();
      _tanSuatController.text = (record.tanSuatThucHienTrenThang ?? 0).toString();
      _soLuongController.text = (record.soLuong ?? 0).toString();
      _ghiChuController.text = record.ghiChu ?? '';
      
      _calculateDonGia();
    });
  }

  void _exitEditMode() {
    setState(() {
      _isEditMode = false;
      _editingRecord = null;
    });
    _clearForm();
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isEditMode && _editingRecord != null) {
      final updatedRecord = _editingRecord!.copyWith(
        danhMucCongViec: _danhMucCongViecController.text.trim(),
        chiTietCongViec: _chiTietCongViecController.text.trim(),
        tongTienTrenLanThucHien: int.tryParse(_tongTienController.text),
        tanSuatThucHienTrenThang: double.tryParse(_tanSuatController.text),
        donGiaTrenThang: _donGiaTrenThang,
        soLuong: double.tryParse(_soLuongController.text),
        thanhTien: _thanhTien,
        ghiChu: _ghiChuController.text.trim(),
      );

      final dbHelper = DBHelper();
      await dbHelper.updateLinkDinhKy(updatedRecord);

      final success = await HDChiPhi._sendDataToServer({
        'table': 'LinkDinhKy',
        'action': 'update',
        'data': updatedRecord.toMap(),
      });

      if (success) {
        _showSuccessMessage('Đã cập nhật thành công!');
        _exitEditMode();
        _loadRecords();
      } else {
        _showErrorMessage('Lỗi khi cập nhật dữ liệu');
      }
    } else {
      // Create new record (existing logic)
      final record = LinkDinhKyModel(
        uid: HDChiPhi._uuid.v4(),
        hopDongID: widget.costContext.hopDongUid,
        thang: widget.costContext.hopDongThang,
        nguoiTao: widget.costContext.username,
        maKinhDoanh: widget.costContext.hopDongMaKinhDoanh,
        danhMucCongViec: _danhMucCongViecController.text.trim(),
        chiTietCongViec: _chiTietCongViecController.text.trim(),
        tongTienTrenLanThucHien: int.tryParse(_tongTienController.text),
        tanSuatThucHienTrenThang: double.tryParse(_tanSuatController.text),
        donGiaTrenThang: _donGiaTrenThang,
        soLuong: double.tryParse(_soLuongController.text),
        thanhTien: _thanhTien,
        ghiChu: _ghiChuController.text.trim(),
      );

      final dbHelper = DBHelper();
      await dbHelper.insertLinkDinhKy(record);

      final success = await HDChiPhi._sendDataToServer({
        'table': 'LinkDinhKy',
        'action': 'insert',
        'data': record.toMap(),
      });

      if (success) {
        _showSuccessMessage('Đã lưu thành công!');
        _clearForm();
        _loadRecords();
      } else {
        _showErrorMessage('Lỗi khi lưu dữ liệu');
      }
    }

    final newTotal = await HDChiPhi._calculateTotalCost(
      widget.costContext.hopDongUid!, 
      'CVDinhKy'
    );
    widget.costContext.onCostUpdated('CVDinhKy', newTotal);
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$message Vui lòng lưu hợp đồng và tải lại để cập nhật.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _clearForm() {
    _danhMucCongViecController.clear();
    _chiTietCongViecController.clear();
    _tongTienController.clear();
    _tanSuatController.clear();
    _soLuongController.clear();
    _ghiChuController.clear();
    setState(() {
      _donGiaTrenThang = 0;
      _thanhTien = 0;
    });
  }

  Future<void> _deleteRecord(String uid) async {
    final dbHelper = DBHelper();
    await dbHelper.deleteLinkDinhKy(uid);

    await HDChiPhi._sendDataToServer({
      'table': 'LinkDinhKy',
      'action': 'delete',
      'uid': uid,
    });

    final newTotal = await HDChiPhi._calculateTotalCost(
      widget.costContext.hopDongUid!, 
      'CVDinhKy'
    );
    widget.costContext.onCostUpdated('CVDinhKy', newTotal);
    _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 1.4,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Chi phí CV Định kỳ - ${widget.costContext.hopDongTen}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            
            Expanded(
              flex: 1,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _isEditMode ? 'Chỉnh sửa công việc định kỳ' : 'Thêm công việc định kỳ mới', 
                              style: TextStyle(fontWeight: FontWeight.bold)
                            ),
                            if (_isEditMode) ...[
                              Spacer(),
                              TextButton(
                                onPressed: _exitEditMode,
                                child: Text('Hủy chỉnh sửa'),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                              ),
                            ],
                          ],
                        ),
                                             SizedBox(height: 8),
                        Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    ElevatedButton(
      onPressed: _saveRecord,
      child: Text(_isEditMode ? 'Cập nhật' : 'Lưu'),
    ),
    TextButton(
      onPressed: _isEditMode ? _exitEditMode : _clearForm,
      child: Text(_isEditMode ? 'Hủy' : 'Xóa form'),
    ),
  ],
),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _danhMucCongViecController,
                                decoration: InputDecoration(
                                  labelText: 'Danh mục công việc *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _chiTietCongViecController,
                                decoration: InputDecoration(
                                  labelText: 'Chi tiết công việc',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _tongTienController,
                                decoration: InputDecoration(
                                  labelText: 'Tổng tiền/lần *',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _tanSuatController,
                                decoration: InputDecoration(
                                  labelText: 'Tần suất/tháng *',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Đơn giá/tháng: ${NumberFormat('#,##0', 'vi_VN').format(_donGiaTrenThang)}',
                                  style: TextStyle(fontSize: 12),
                                ),
                                ),
                           ),
                         ],
                       ),
                       SizedBox(height: 8),
                       Row(
                         children: [
                           Expanded(
                             child: TextFormField(
                               controller: _soLuongController,
                               decoration: InputDecoration(
                                 labelText: 'Số lượng *',
                                 border: OutlineInputBorder(),
                               ),
                               keyboardType: TextInputType.numberWithOptions(decimal: true),
                               validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: Container(
                               padding: EdgeInsets.all(12),
                               decoration: BoxDecoration(
                                 border: Border.all(color: Colors.grey),
                                 borderRadius: BorderRadius.circular(4),
                               ),
                               child: Text(
                                 'Thành tiền: ${NumberFormat('#,##0', 'vi_VN').format(_thanhTien)}',
                                 style: TextStyle(fontWeight: FontWeight.bold),
                               ),
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: TextFormField(
                               controller: _ghiChuController,
                               decoration: InputDecoration(
                                 labelText: 'Ghi chú',
                                 border: OutlineInputBorder(),
                               ),
                             ),
                           ),
                         ],
                       ),

                      ],
                    ),
                  ),
                ),
              ),
           ),
           
           SizedBox(height: 16),
           
           Expanded(
              flex: 2,
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Danh sách công việc định kỳ (${_records.length} mục)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: _isLoading
                          ? Center(child: CircularProgressIndicator())
                          : _records.isEmpty
                              ? Center(child: Text('Chưa có công việc định kỳ nào'))
                              : ListView.builder(
                                  itemCount: _records.length,
                                  itemBuilder: (context, index) {
                                    final record = _records[index];
                                    final isCurrentlyEditing = _editingRecord?.uid == record.uid;
                                    
                                    return ListTile(
                                      title: Text(record.danhMucCongViec ?? ''),
                                      subtitle: Text(
                                        'Chi tiết: ${record.chiTietCongViec ?? ''} | '
                                        'Số lượng: ${record.soLuong ?? 0} | '
                                        'Tần suất: ${record.tanSuatThucHienTrenThang ?? 0}'
                                      ),
                                      tileColor: isCurrentlyEditing ? Colors.blue.withOpacity(0.1) : null,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${NumberFormat('#,##0', 'vi_VN').format(record.thanhTien ?? 0)} VND',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              isCurrentlyEditing ? Icons.cancel : Icons.edit, 
                                              color: isCurrentlyEditing ? Colors.red : Colors.blue
                                            ),
                                            onPressed: () {
                                              if (isCurrentlyEditing) {
                                                _exitEditMode();
                                              } else {
                                                _enterEditMode(record);
                                              }
                                            },
                                            tooltip: isCurrentlyEditing ? 'Hủy chỉnh sửa' : 'Chỉnh sửa',
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _deleteRecord(record.uid!),
                                            tooltip: 'Xóa',
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Đóng'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

 @override
  void dispose() {
    _danhMucCongViecController.dispose();
    _chiTietCongViecController.dispose();
    _tongTienController.dispose();
    _tanSuatController.dispose();
    _soLuongController.dispose();
    _ghiChuController.dispose();
    super.dispose();
  }
}

// LeTetTC Dialog Widget
class _LeTetTCDialog extends StatefulWidget {
 final HDChiPhiContext costContext;

 const _LeTetTCDialog({required this.costContext});

 @override
 _LeTetTCDialogState createState() => _LeTetTCDialogState();
}

class _LeTetTCDialogState extends State<_LeTetTCDialog> {
  final _formKey = GlobalKey<FormState>();
  final _danhMucCongViecController = TextEditingController();
  final _chiTietCongViecController = TextEditingController();
  final _tanSuatTrenLanController = TextEditingController();
  final _donViTinhController = TextEditingController();
  final _donGiaController = TextEditingController();
  final _soLuongNhanVienController = TextEditingController();
  final _thoiGianCungCapController = TextEditingController();
  final _phanBoTrenThangController = TextEditingController();
  final _ghiChuController = TextEditingController();
  
  List<LinkLeTetTCModel> _records = [];
  bool _isLoading = true;
  int _thanhTienTrenThang = 0;
  
  // Edit mode variables
  bool _isEditMode = false;
  LinkLeTetTCModel? _editingRecord;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _donGiaController.addListener(_calculateThanhTien);
    _soLuongNhanVienController.addListener(_calculateThanhTien);
  }

  void _calculateThanhTien() {
    final donGia = int.tryParse(_donGiaController.text) ?? 0;
    final soLuongNhanVien = double.tryParse(_soLuongNhanVienController.text) ?? 0.0;
    setState(() {
      _thanhTienTrenThang = (donGia * soLuongNhanVien).round();
    });
  }

  Future<void> _loadRecords() async {
    if (widget.costContext.hopDongUid != null) {
      final dbHelper = DBHelper();
      final records = await dbHelper.getLinkLeTetTCsByContract(widget.costContext.hopDongUid!);
      setState(() {
        _records = records;
        _isLoading = false;
      });
    }
  }

  void _enterEditMode(LinkLeTetTCModel record) {
    setState(() {
      _isEditMode = true;
      _editingRecord = record;
      
      _danhMucCongViecController.text = record.danhMucCongViec ?? '';
      _chiTietCongViecController.text = record.chiTietCongViec ?? '';
      _tanSuatTrenLanController.text = record.tanSuatTrenLan ?? '';
      _donViTinhController.text = record.donViTinh ?? '';
      _donGiaController.text = (record.donGia ?? 0).toString();
      _soLuongNhanVienController.text = (record.soLuongNhanVien ?? 0).toString();
      _thoiGianCungCapController.text = (record.thoiGianCungCapDVT ?? 0).toString();
      _phanBoTrenThangController.text = (record.phanBoTrenThang ?? 0).toString();
      _ghiChuController.text = record.ghiChu ?? '';
      
      _calculateThanhTien();
    });
  }

  void _exitEditMode() {
    setState(() {
      _isEditMode = false;
      _editingRecord = null;
    });
    _clearForm();
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isEditMode && _editingRecord != null) {
      final updatedRecord = _editingRecord!.copyWith(
        danhMucCongViec: _danhMucCongViecController.text.trim(),
        chiTietCongViec: _chiTietCongViecController.text.trim(),
        tanSuatTrenLan: _tanSuatTrenLanController.text.trim(),
        donViTinh: _donViTinhController.text.trim(),
        donGia: int.tryParse(_donGiaController.text),
        soLuongNhanVien: double.tryParse(_soLuongNhanVienController.text),
        thoiGianCungCapDVT: double.tryParse(_thoiGianCungCapController.text),
        phanBoTrenThang: double.tryParse(_phanBoTrenThangController.text),
        thanhTienTrenThang: _thanhTienTrenThang,
        ghiChu: _ghiChuController.text.trim(),
      );

      final dbHelper = DBHelper();
      await dbHelper.updateLinkLeTetTC(updatedRecord);

      final success = await HDChiPhi._sendDataToServer({
        'table': 'LinkLeTetTC',
        'action': 'update',
        'data': updatedRecord.toMap(),
      });

      if (success) {
        _showSuccessMessage('Đã cập nhật thành công!');
        _exitEditMode();
        _loadRecords();
      } else {
        _showErrorMessage('Lỗi khi cập nhật dữ liệu');
      }
    } else {
      // Create new record (existing logic)
      final record = LinkLeTetTCModel(
        uid: HDChiPhi._uuid.v4(),
        hopDongID: widget.costContext.hopDongUid,
        thang: widget.costContext.hopDongThang,
        nguoiTao: widget.costContext.username,
        maKinhDoanh: widget.costContext.hopDongMaKinhDoanh,
        danhMucCongViec: _danhMucCongViecController.text.trim(),
        chiTietCongViec: _chiTietCongViecController.text.trim(),
        tanSuatTrenLan: _tanSuatTrenLanController.text.trim(),
        donViTinh: _donViTinhController.text.trim(),
        donGia: int.tryParse(_donGiaController.text),
        soLuongNhanVien: double.tryParse(_soLuongNhanVienController.text),
        thoiGianCungCapDVT: double.tryParse(_thoiGianCungCapController.text),
        phanBoTrenThang: double.tryParse(_phanBoTrenThangController.text),
        thanhTienTrenThang: _thanhTienTrenThang,
        ghiChu: _ghiChuController.text.trim(),
      );

      final dbHelper = DBHelper();
      await dbHelper.insertLinkLeTetTC(record);

      final success = await HDChiPhi._sendDataToServer({
        'table': 'LinkLeTetTC',
        'action': 'insert',
        'data': record.toMap(),
      });

      if (success) {
        _showSuccessMessage('Đã lưu thành công!');
        _clearForm();
        _loadRecords();
      } else {
        _showErrorMessage('Lỗi khi lưu dữ liệu');
      }
    }

    final newTotal = await HDChiPhi._calculateTotalCost(
      widget.costContext.hopDongUid!, 
      'LeTetTCa'
    );
    widget.costContext.onCostUpdated('LeTetTCa', newTotal);
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$message Vui lòng lưu hợp đồng và tải lại để cập nhật.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _clearForm() {
    _danhMucCongViecController.clear();
    _chiTietCongViecController.clear();
    _tanSuatTrenLanController.clear();
    _donViTinhController.clear();
    _donGiaController.clear();
    _soLuongNhanVienController.clear();
    _thoiGianCungCapController.clear();
    _phanBoTrenThangController.clear();
    _ghiChuController.clear();
    setState(() {
      _thanhTienTrenThang = 0;
    });
  }

  Future<void> _deleteRecord(String uid) async {
    final dbHelper = DBHelper();
    await dbHelper.deleteLinkLeTetTC(uid);

    await HDChiPhi._sendDataToServer({
      'table': 'LinkLeTetTC',
      'action': 'delete',
      'uid': uid,
    });

    final newTotal = await HDChiPhi._calculateTotalCost(
      widget.costContext.hopDongUid!, 
      'LeTetTCa'
    );
    widget.costContext.onCostUpdated('LeTetTCa', newTotal);
    _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 1.4,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Chi phí Lễ tết Tăng ca - ${widget.costContext.hopDongTen}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            
            Expanded(
              flex: 1,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _isEditMode ? 'Chỉnh sửa lễ tết tăng ca' : 'Thêm lễ tết tăng ca mới', 
                              style: TextStyle(fontWeight: FontWeight.bold)
                            ),
                            if (_isEditMode) ...[
                              Spacer(),
                              TextButton(
                                onPressed: _exitEditMode,
                                child: Text('Hủy chỉnh sửa'),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 8),
                       Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    ElevatedButton(
      onPressed: _saveRecord,
      child: Text(_isEditMode ? 'Cập nhật' : 'Lưu'),
    ),
    TextButton(
      onPressed: _isEditMode ? _exitEditMode : _clearForm,
      child: Text(_isEditMode ? 'Hủy' : 'Xóa form'),
    ),
  ],
),
                        SizedBox(height: 8),
                       Row(
                         children: [
                           Expanded(
                             child: TextFormField(
                               controller: _danhMucCongViecController,
                               decoration: InputDecoration(
                                 labelText: 'Danh mục công việc *',
                                 border: OutlineInputBorder(),
                               ),
                               validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: TextFormField(
                               controller: _chiTietCongViecController,
                               decoration: InputDecoration(
                                 labelText: 'Chi tiết công việc',
                                 border: OutlineInputBorder(),
                               ),
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: TextFormField(
                               controller: _tanSuatTrenLanController,
                               decoration: InputDecoration(
                                 labelText: 'Tần suất trên lần',
                                 border: OutlineInputBorder(),
                               ),
                             ),
                           ),
                         ],
                       ),
                       SizedBox(height: 8),
                       Row(
                         children: [
                           Expanded(
                             child: TextFormField(
                               controller: _donViTinhController,
                               decoration: InputDecoration(
                                 labelText: 'Đơn vị',
                                 border: OutlineInputBorder(),
                               ),
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: TextFormField(
                               controller: _donGiaController,
                               decoration: InputDecoration(
                                 labelText: 'Đơn giá *',
                                 border: OutlineInputBorder(),
                               ),
                               keyboardType: TextInputType.number,
                               inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                               validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: TextFormField(
                               controller: _soLuongNhanVienController,
                               decoration: InputDecoration(
                                 labelText: 'Số nhân viên *',
                                 border: OutlineInputBorder(),
                               ),
                               keyboardType: TextInputType.numberWithOptions(decimal: true),
                               validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                             ),
                           ),
                         ],
                       ),
                       SizedBox(height: 8),
                       Row(
                         children: [
                           Expanded(
                             child: TextFormField(
                               controller: _thoiGianCungCapController,
                               decoration: InputDecoration(
                                 labelText: 'Thời gian cung cấp',
                                 border: OutlineInputBorder(),
                               ),
                               keyboardType: TextInputType.numberWithOptions(decimal: true),
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: TextFormField(
                               controller: _phanBoTrenThangController,
                               decoration: InputDecoration(
                                 labelText: 'Phân bổ trên tháng',
                                 border: OutlineInputBorder(),
                               ),
                               keyboardType: TextInputType.numberWithOptions(decimal: true),
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: Container(
                               padding: EdgeInsets.all(12),
                               decoration: BoxDecoration(
                                 border: Border.all(color: Colors.grey),
                                 borderRadius: BorderRadius.circular(4),
                               ),
                               child: Text(
                                 'Thành tiền/tháng: ${NumberFormat('#,##0', 'vi_VN').format(_thanhTienTrenThang)}',
                                 style: TextStyle(fontWeight: FontWeight.bold),
                               ),
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: TextFormField(
                               controller: _ghiChuController,
                               decoration: InputDecoration(
                                 labelText: 'Ghi chú',
                                 border: OutlineInputBorder(),
                               ),
                             ),
                           ),
                         ],
                       ),

                      ],
                    ),
                  ),
                ),
              ),
            ),
           
           SizedBox(height: 16),
           
           Expanded(
              flex: 2,
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Danh sách lễ tết tăng ca (${_records.length} mục)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: _isLoading
                          ? Center(child: CircularProgressIndicator())
                          : _records.isEmpty
                              ? Center(child: Text('Chưa có lễ tết tăng ca nào'))
                              : ListView.builder(
                                  itemCount: _records.length,
                                  itemBuilder: (context, index) {
                                    final record = _records[index];
                                    final isCurrentlyEditing = _editingRecord?.uid == record.uid;
                                    
                                    return ListTile(
                                      title: Text(record.danhMucCongViec ?? ''),
                                      subtitle: Text(
                                        'Chi tiết: ${record.chiTietCongViec ?? ''} | '
                                        'Số NV: ${record.soLuongNhanVien ?? 0} | '
                                        'Đơn giá: ${NumberFormat('#,##0', 'vi_VN').format(record.donGia ?? 0)}'
                                      ),
                                      tileColor: isCurrentlyEditing ? Colors.blue.withOpacity(0.1) : null,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${NumberFormat('#,##0', 'vi_VN').format(record.thanhTienTrenThang ?? 0)} VND',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              isCurrentlyEditing ? Icons.cancel : Icons.edit, 
                                              color: isCurrentlyEditing ? Colors.red : Colors.blue
                                            ),
                                            onPressed: () {
                                              if (isCurrentlyEditing) {
                                                _exitEditMode();
                                              } else {
                                                _enterEditMode(record);
                                              }
                                            },
                                            tooltip: isCurrentlyEditing ? 'Hủy chỉnh sửa' : 'Chỉnh sửa',
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _deleteRecord(record.uid!),
                                            tooltip: 'Xóa',
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Đóng'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

 @override
  void dispose() {
    _danhMucCongViecController.dispose();
    _chiTietCongViecController.dispose();
    _tanSuatTrenLanController.dispose();
    _donViTinhController.dispose();
    _donGiaController.dispose();
    _soLuongNhanVienController.dispose();
    _thoiGianCungCapController.dispose();
    _phanBoTrenThangController.dispose();
    _ghiChuController.dispose();
    super.dispose();
  }
}

// PhuCap Dialog Widget
class _PhuCapDialog extends StatefulWidget {
 final HDChiPhiContext costContext;

 const _PhuCapDialog({required this.costContext});

 @override
 _PhuCapDialogState createState() => _PhuCapDialogState();
}

class _PhuCapDialogState extends State<_PhuCapDialog> {
  final _formKey = GlobalKey<FormState>();
  final _danhMucCongViecController = TextEditingController();
  final _chiTietCongViecController = TextEditingController();
  final _tanSuatTrenLanController = TextEditingController();
  final _donViTinhController = TextEditingController();
  final _donGiaController = TextEditingController();
  final _soLuongNhanVienController = TextEditingController();
  final _thoiGianCungCapController = TextEditingController();
  final _phanBoTrenThangController = TextEditingController();
  final _ghiChuController = TextEditingController();
  
  List<LinkPhuCapModel> _records = [];
  bool _isLoading = true;
  int _thanhTienTrenThang = 0;
  
  // Edit mode variables
  bool _isEditMode = false;
  LinkPhuCapModel? _editingRecord;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _donGiaController.addListener(_calculateThanhTien);
    _soLuongNhanVienController.addListener(_calculateThanhTien);
    _thoiGianCungCapController.addListener(_calculateThanhTien);
    _phanBoTrenThangController.addListener(_calculateThanhTien);
  }

  void _calculateThanhTien() {
    final donGia = int.tryParse(_donGiaController.text) ?? 0;
    final soLuongNhanVien = double.tryParse(_soLuongNhanVienController.text) ?? 0.0;
    final thoiGianCungCap = double.tryParse(_thoiGianCungCapController.text) ?? 0.0;
    final phanBoTrenThang = double.tryParse(_phanBoTrenThangController.text) ?? 1.0;
    
    setState(() {
      if (phanBoTrenThang != 0) {
        _thanhTienTrenThang = (donGia * soLuongNhanVien * thoiGianCungCap / phanBoTrenThang).round();
      } else {
        _thanhTienTrenThang = 0;
      }
    });
  }

  Future<void> _loadRecords() async {
    if (widget.costContext.hopDongUid != null) {
      final dbHelper = DBHelper();
      final records = await dbHelper.getLinkPhuCapsByContract(widget.costContext.hopDongUid!);
      setState(() {
        _records = records;
        _isLoading = false;
      });
    }
  }

  void _enterEditMode(LinkPhuCapModel record) {
    setState(() {
      _isEditMode = true;
      _editingRecord = record;
      
      _danhMucCongViecController.text = record.danhMucCongViec ?? '';
      _chiTietCongViecController.text = record.chiTietCongViec ?? '';
      _tanSuatTrenLanController.text = record.tanSuatTrenLan ?? '';
      _donViTinhController.text = record.donViTinh ?? '';
      _donGiaController.text = (record.donGia ?? 0).toString();
      _soLuongNhanVienController.text = (record.soLuongNhanVien ?? 0).toString();
      _thoiGianCungCapController.text = (record.thoiGianCungCapDVT ?? 0).toString();
      _phanBoTrenThangController.text = (record.phanBoTrenThang ?? 0).toString();
      _ghiChuController.text = record.ghiChu ?? '';
      
      _calculateThanhTien();
    });
  }

  void _exitEditMode() {
    setState(() {
      _isEditMode = false;
      _editingRecord = null;
    });
    _clearForm();
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isEditMode && _editingRecord != null) {
      final updatedRecord = _editingRecord!.copyWith(
        danhMucCongViec: _danhMucCongViecController.text.trim(),
        chiTietCongViec: _chiTietCongViecController.text.trim(),
        tanSuatTrenLan: _tanSuatTrenLanController.text.trim(),
        donViTinh: _donViTinhController.text.trim(),
        donGia: int.tryParse(_donGiaController.text),
        soLuongNhanVien: double.tryParse(_soLuongNhanVienController.text),
        thoiGianCungCapDVT: double.tryParse(_thoiGianCungCapController.text),
        phanBoTrenThang: double.tryParse(_phanBoTrenThangController.text),
        thanhTienTrenThang: _thanhTienTrenThang,
        ghiChu: _ghiChuController.text.trim(),
      );

      final dbHelper = DBHelper();
      await dbHelper.updateLinkPhuCap(updatedRecord);

      final success = await HDChiPhi._sendDataToServer({
        'table': 'LinkPhuCap',
        'action': 'update',
        'data': updatedRecord.toMap(),
      });

      if (success) {
        _showSuccessMessage('Đã cập nhật thành công!');
        _exitEditMode();
        _loadRecords();
      } else {
        _showErrorMessage('Lỗi khi cập nhật dữ liệu');
      }
    } else {
      final record = LinkPhuCapModel(
        uid: HDChiPhi._uuid.v4(),
        hopDongID: widget.costContext.hopDongUid,
        thang: widget.costContext.hopDongThang,
        nguoiTao: widget.costContext.username,
        maKinhDoanh: widget.costContext.hopDongMaKinhDoanh,
        danhMucCongViec: _danhMucCongViecController.text.trim(),
        chiTietCongViec: _chiTietCongViecController.text.trim(),
        tanSuatTrenLan: _tanSuatTrenLanController.text.trim(),
        donViTinh: _donViTinhController.text.trim(),
        donGia: int.tryParse(_donGiaController.text),
        soLuongNhanVien: double.tryParse(_soLuongNhanVienController.text),
        thoiGianCungCapDVT: double.tryParse(_thoiGianCungCapController.text),
        phanBoTrenThang: double.tryParse(_phanBoTrenThangController.text),
        thanhTienTrenThang: _thanhTienTrenThang,
        ghiChu: _ghiChuController.text.trim(),
      );

      final dbHelper = DBHelper();
      await dbHelper.insertLinkPhuCap(record);

      final success = await HDChiPhi._sendDataToServer({
        'table': 'LinkPhuCap',
        'action': 'insert',
        'data': record.toMap(),
      });

      if (success) {
        _showSuccessMessage('Đã lưu thành công!');
        _clearForm();
        _loadRecords();
      } else {
        _showErrorMessage('Lỗi khi lưu dữ liệu');
      }
    }

    final newTotal = await HDChiPhi._calculateTotalCost(
      widget.costContext.hopDongUid!, 
      'PhuCap'
    );
    widget.costContext.onCostUpdated('PhuCap', newTotal);
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$message Vui lòng lưu hợp đồng và tải lại để cập nhật.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _clearForm() {
    _danhMucCongViecController.clear();
    _chiTietCongViecController.clear();
    _tanSuatTrenLanController.clear();
    _donViTinhController.clear();
    _donGiaController.clear();
    _soLuongNhanVienController.clear();
    _thoiGianCungCapController.clear();
    _phanBoTrenThangController.clear();
    _ghiChuController.clear();
    setState(() {
      _thanhTienTrenThang = 0;
    });
  }

  Future<void> _deleteRecord(String uid) async {
    final dbHelper = DBHelper();
    await dbHelper.deleteLinkPhuCap(uid);

    await HDChiPhi._sendDataToServer({
      'table': 'LinkPhuCap',
      'action': 'delete',
      'uid': uid,
    });

    final newTotal = await HDChiPhi._calculateTotalCost(
      widget.costContext.hopDongUid!, 
      'PhuCap'
    );
    widget.costContext.onCostUpdated('PhuCap', newTotal);
    _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 1.4,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Chi phí Phụ cấp - ${widget.costContext.hopDongTen}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            
            Expanded(
              flex: 1,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _isEditMode ? 'Chỉnh sửa phụ cấp' : 'Thêm phụ cấp mới', 
                              style: TextStyle(fontWeight: FontWeight.bold)
                            ),
                            if (_isEditMode) ...[
                              Spacer(),
                              TextButton(
                                onPressed: _exitEditMode,
                                child: Text('Hủy chỉnh sửa'),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 8),
                        Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    ElevatedButton(
      onPressed: _saveRecord,
      child: Text(_isEditMode ? 'Cập nhật' : 'Lưu'),
    ),
    TextButton(
      onPressed: _isEditMode ? _exitEditMode : _clearForm,
      child: Text(_isEditMode ? 'Hủy' : 'Xóa form'),
    ),
  ],
),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _danhMucCongViecController,
                                decoration: InputDecoration(
                                  labelText: 'Danh mục công việc *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _chiTietCongViecController,
                                decoration: InputDecoration(
                                  labelText: 'Chi tiết công việc',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _tanSuatTrenLanController,
                                decoration: InputDecoration(
                                  labelText: 'Tần suất trên lần',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _donViTinhController,
                                decoration: InputDecoration(
                                  labelText: 'Đơn vị',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _donGiaController,
                                decoration: InputDecoration(
                                  labelText: 'Đơn giá *',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _soLuongNhanVienController,
                                decoration: InputDecoration(
                                  labelText: 'Số nhân viên *',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _thoiGianCungCapController,
                                decoration: InputDecoration(
                                  labelText: 'Thời gian cung cấp',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _phanBoTrenThangController,
                                decoration: InputDecoration(
                                  labelText: 'Phân bổ trên tháng',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Thành tiền tháng: ${NumberFormat('#,##0', 'vi_VN').format(_thanhTienTrenThang)}',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _ghiChuController,
                                decoration: InputDecoration(
                                  labelText: 'Ghi chú',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),

                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            Expanded(
              flex: 2,
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Danh sách phụ cấp (${_records.length} mục)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: _isLoading
                          ? Center(child: CircularProgressIndicator())
                          : _records.isEmpty
                              ? Center(child: Text('Chưa có phụ cấp nào'))
                              : ListView.builder(
                                  itemCount: _records.length,
                                  itemBuilder: (context, index) {
                                    final record = _records[index];
                                    final isCurrentlyEditing = _editingRecord?.uid == record.uid;
                                    
                                    return ListTile(
                                      title: Text(record.danhMucCongViec ?? ''),
                                      subtitle: Text(
                                        'Chi tiết: ${record.chiTietCongViec ?? ''} | '
                                        'Số NV: ${record.soLuongNhanVien ?? 0} | '
                                        'Đơn giá: ${NumberFormat('#,##0', 'vi_VN').format(record.donGia ?? 0)}'
                                      ),
                                      tileColor: isCurrentlyEditing ? Colors.blue.withOpacity(0.1) : null,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${NumberFormat('#,##0', 'vi_VN').format(record.thanhTienTrenThang ?? 0)} VND',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              isCurrentlyEditing ? Icons.cancel : Icons.edit, 
                                              color: isCurrentlyEditing ? Colors.red : Colors.blue
                                            ),
                                            onPressed: () {
                                              if (isCurrentlyEditing) {
                                                _exitEditMode();
                                              } else {
                                                _enterEditMode(record);
                                              }
                                            },
                                            tooltip: isCurrentlyEditing ? 'Hủy chỉnh sửa' : 'Chỉnh sửa',
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _deleteRecord(record.uid!),
                                            tooltip: 'Xóa',
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Đóng'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _danhMucCongViecController.dispose();
    _chiTietCongViecController.dispose();
    _tanSuatTrenLanController.dispose();
    _donViTinhController.dispose();
    _donGiaController.dispose();
    _soLuongNhanVienController.dispose();
    _thoiGianCungCapController.dispose();
    _phanBoTrenThangController.dispose();
    _ghiChuController.dispose();
    super.dispose();
  }
}
class _NgoaiGiaoDialog extends StatefulWidget {
 final HDChiPhiContext costContext;

 const _NgoaiGiaoDialog({required this.costContext});

 @override
 _NgoaiGiaoDialogState createState() => _NgoaiGiaoDialogState();
}
class _NgoaiGiaoDialogState extends State<_NgoaiGiaoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _danhMucController = TextEditingController();
  final _noiDungChiTietController = TextEditingController();
  final _tanSuatController = TextEditingController();
  final _donViTinhController = TextEditingController();
  final _donGiaController = TextEditingController();
  final _soLuongController = TextEditingController();
  final _thoiGianCungCapController = TextEditingController();
  final _phanBoTrenThangController = TextEditingController();
  final _ghiChuController = TextEditingController();
  
  List<LinkNgoaiGiaoModel> _records = [];
  bool _isLoading = true;
  int _thanhTienTrenThang = 0;
  
  // Edit mode variables
  bool _isEditMode = false;
  LinkNgoaiGiaoModel? _editingRecord;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _donGiaController.addListener(_calculateThanhTien);
    _soLuongController.addListener(_calculateThanhTien);
    _thoiGianCungCapController.addListener(_calculateThanhTien);
    _phanBoTrenThangController.addListener(_calculateThanhTien);
  }

  void _calculateThanhTien() {
    final donGia = int.tryParse(_donGiaController.text) ?? 0;
    final soLuong = double.tryParse(_soLuongController.text) ?? 0.0;
    final thoiGianCungCap = double.tryParse(_thoiGianCungCapController.text) ?? 0.0;
    final phanBoTrenThang = double.tryParse(_phanBoTrenThangController.text) ?? 1.0;
    
    setState(() {
      if (phanBoTrenThang != 0) {
        _thanhTienTrenThang = (donGia * soLuong * thoiGianCungCap / phanBoTrenThang).round();
      } else {
        _thanhTienTrenThang = 0;
      }
    });
  }

  Future<void> _loadRecords() async {
    if (widget.costContext.hopDongUid != null) {
      final dbHelper = DBHelper();
      final records = await dbHelper.getLinkNgoaiGiaosByContract(widget.costContext.hopDongUid!);
      setState(() {
        _records = records;
        _isLoading = false;
      });
    }
  }

  void _enterEditMode(LinkNgoaiGiaoModel record) {
    setState(() {
      _isEditMode = true;
      _editingRecord = record;
      
      _danhMucController.text = record.danhMuc ?? '';
      _noiDungChiTietController.text = record.noiDungChiTiet ?? '';
      _tanSuatController.text = record.tanSuat ?? '';
      _donViTinhController.text = record.donViTinh ?? '';
      _donGiaController.text = (record.donGia ?? 0).toString();
      _soLuongController.text = (record.soLuong ?? 0).toString();
      _thoiGianCungCapController.text = (record.thoiGianCungCapDVT ?? 0).toString();
      _phanBoTrenThangController.text = (record.phanBoTrenThang ?? 0).toString();
      _ghiChuController.text = record.ghiChu ?? '';
      
      _calculateThanhTien();
    });
  }

  void _exitEditMode() {
    setState(() {
      _isEditMode = false;
      _editingRecord = null;
    });
    _clearForm();
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isEditMode && _editingRecord != null) {
      final updatedRecord = _editingRecord!.copyWith(
        danhMuc: _danhMucController.text.trim(),
        noiDungChiTiet: _noiDungChiTietController.text.trim(),
        tanSuat: _tanSuatController.text.trim(),
        donViTinh: _donViTinhController.text.trim(),
        donGia: int.tryParse(_donGiaController.text),
        soLuong: double.tryParse(_soLuongController.text),
        thoiGianCungCapDVT: double.tryParse(_thoiGianCungCapController.text),
        phanBoTrenThang: double.tryParse(_phanBoTrenThangController.text),
        thanhTienTrenThang: _thanhTienTrenThang,
        ghiChu: _ghiChuController.text.trim(),
      );

      final dbHelper = DBHelper();
      await dbHelper.updateLinkNgoaiGiao(updatedRecord);

      final success = await HDChiPhi._sendDataToServer({
        'table': 'LinkNgoaiGiao',
        'action': 'update',
        'data': updatedRecord.toMap(),
      });

      if (success) {
        _showSuccessMessage('Đã cập nhật thành công!');
        _exitEditMode();
        _loadRecords();
      } else {
        _showErrorMessage('Lỗi khi cập nhật dữ liệu');
      }
    } else {
      final record = LinkNgoaiGiaoModel(
        uid: HDChiPhi._uuid.v4(),
        hopDongID: widget.costContext.hopDongUid,
        thang: widget.costContext.hopDongThang,
        nguoiTao: widget.costContext.username,
        maKinhDoanh: widget.costContext.hopDongMaKinhDoanh,
        danhMuc: _danhMucController.text.trim(),
        noiDungChiTiet: _noiDungChiTietController.text.trim(),
        tanSuat: _tanSuatController.text.trim(),
        donViTinh: _donViTinhController.text.trim(),
        donGia: int.tryParse(_donGiaController.text),
        soLuong: double.tryParse(_soLuongController.text),
        thoiGianCungCapDVT: double.tryParse(_thoiGianCungCapController.text),
        phanBoTrenThang: double.tryParse(_phanBoTrenThangController.text),
        thanhTienTrenThang: _thanhTienTrenThang,
        ghiChu: _ghiChuController.text.trim(),
      );

      final dbHelper = DBHelper();
      await dbHelper.insertLinkNgoaiGiao(record);

      final success = await HDChiPhi._sendDataToServer({
        'table': 'LinkNgoaiGiao',
        'action': 'insert',
        'data': record.toMap(),
      });

      if (success) {
        _showSuccessMessage('Đã lưu thành công!');
        _clearForm();
        _loadRecords();
      } else {
        _showErrorMessage('Lỗi khi lưu dữ liệu');
      }
    }

    final newTotal = await HDChiPhi._calculateTotalCost(
      widget.costContext.hopDongUid!, 
      'NgoaiGiao'
    );
    widget.costContext.onCostUpdated('NgoaiGiao', newTotal);
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$message Vui lòng lưu hợp đồng và tải lại để cập nhật.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _clearForm() {
    _danhMucController.clear();
    _noiDungChiTietController.clear();
    _tanSuatController.clear();
    _donViTinhController.clear();
    _donGiaController.clear();
    _soLuongController.clear();
    _thoiGianCungCapController.clear();
    _phanBoTrenThangController.clear();
    _ghiChuController.clear();
    setState(() {
      _thanhTienTrenThang = 0;
    });
  }

  Future<void> _deleteRecord(String uid) async {
    final dbHelper = DBHelper();
    await dbHelper.deleteLinkNgoaiGiao(uid);

    await HDChiPhi._sendDataToServer({
      'table': 'LinkNgoaiGiao',
      'action': 'delete',
      'uid': uid,
    });

    final newTotal = await HDChiPhi._calculateTotalCost(
      widget.costContext.hopDongUid!, 
      'NgoaiGiao'
    );
    widget.costContext.onCostUpdated('NgoaiGiao', newTotal);
    _loadRecords();
  }

  @override
 Widget build(BuildContext context) {
   return Dialog(
     child: Container(
       width: MediaQuery.of(context).size.width * 0.9,
       height: MediaQuery.of(context).size.height * 1.6,
       padding: EdgeInsets.all(16),
       child: Column(
         children: [
           Text(
             'Chi phí Ngoại giao - ${widget.costContext.hopDongTen}',
             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
           ),
           SizedBox(height: 16),
           
           Expanded(
             flex: 1,
             child: Card(
               child: Padding(
                 padding: EdgeInsets.all(16),
                 child: Form(
                   key: _formKey,
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Row(
                         children: [
                           Text(
                             _isEditMode ? 'Chỉnh sửa ngoại giao' : 'Thêm ngoại giao mới', 
                             style: TextStyle(fontWeight: FontWeight.bold)
                           ),
                           if (_isEditMode) ...[
                             Spacer(),
                             TextButton(
                               onPressed: _exitEditMode,
                               child: Text('Hủy chỉnh sửa'),
                               style: TextButton.styleFrom(foregroundColor: Colors.red),
                             ),
                           ],
                         ],
                       ),
                       SizedBox(height: 8),
                       Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    ElevatedButton(
      onPressed: _saveRecord,
      child: Text(_isEditMode ? 'Cập nhật' : 'Lưu'),
    ),
    TextButton(
      onPressed: _isEditMode ? _exitEditMode : _clearForm,
      child: Text(_isEditMode ? 'Hủy' : 'Xóa form'),
    ),
  ],
),
                       SizedBox(height: 8),
                       Row(
                         children: [
                           Expanded(
                             child: TextFormField(
                               controller: _danhMucController,
                               decoration: InputDecoration(
                                 labelText: 'Danh mục *',
                                 border: OutlineInputBorder(),
                               ),
                               validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: TextFormField(
                               controller: _noiDungChiTietController,
                               decoration: InputDecoration(
                                 labelText: 'Nội dung chi tiết',
                                 border: OutlineInputBorder(),
                               ),
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: TextFormField(
                               controller: _tanSuatController,
                               decoration: InputDecoration(
                                 labelText: 'Tần suất',
                                 border: OutlineInputBorder(),
                               ),
                             ),
                           ),
                         ],
                       ),
                       SizedBox(height: 8),
                       Row(
                         children: [
                           Expanded(
                             child: TextFormField(
                               controller: _donViTinhController,
                               decoration: InputDecoration(
                                 labelText: 'Đơn vị',
                                 border: OutlineInputBorder(),
                               ),
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: TextFormField(
                               controller: _donGiaController,
                               decoration: InputDecoration(
                                 labelText: 'Đơn giá *',
                                 border: OutlineInputBorder(),
                               ),
                               keyboardType: TextInputType.number,
                               inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                               validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: TextFormField(
                               controller: _soLuongController,
                               decoration: InputDecoration(
                                 labelText: 'Số lượng *',
                                 border: OutlineInputBorder(),
                               ),
                               keyboardType: TextInputType.numberWithOptions(decimal: true),
                               validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                             ),
                           ),
                         ],
                       ),
                       SizedBox(height: 8),
                       Row(
                         children: [
                           Expanded(
                             child: TextFormField(
                               controller: _thoiGianCungCapController,
                               decoration: InputDecoration(
                                 labelText: 'Thời gian cung cấp',
                                 border: OutlineInputBorder(),
                               ),
                               keyboardType: TextInputType.numberWithOptions(decimal: true),
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: TextFormField(
                               controller: _phanBoTrenThangController,
                               decoration: InputDecoration(
                                 labelText: 'Phân bổ trên tháng',
                                 border: OutlineInputBorder(),
                               ),
                               keyboardType: TextInputType.numberWithOptions(decimal: true),
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: Container(
                               padding: EdgeInsets.all(12),
                               decoration: BoxDecoration(
                                 border: Border.all(color: Colors.grey),
                                 borderRadius: BorderRadius.circular(4),
                               ),
                               child: Text(
                                 'Thành tiền/tháng: ${NumberFormat('#,##0', 'vi_VN').format(_thanhTienTrenThang)}',
                                 style: TextStyle(fontWeight: FontWeight.bold),
                               ),
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: TextFormField(
                               controller: _ghiChuController,
                               decoration: InputDecoration(
                                 labelText: 'Ghi chú',
                                 border: OutlineInputBorder(),
                               ),
                             ),
                           ),
                         ],
                       ),

                     ],
                   ),
                 ),
               ),
             ),
           ),
           
           SizedBox(height: 16),
           
           Expanded(
             flex: 2,
             child: Card(
               child: Column(
                 children: [
                   Padding(
                     padding: EdgeInsets.all(16),
                     child: Text(
                       'Danh sách ngoại giao (${_records.length} mục)',
                       style: TextStyle(fontWeight: FontWeight.bold),
                     ),
                   ),
                   Expanded(
                     child: _isLoading
                         ? Center(child: CircularProgressIndicator())
                         : _records.isEmpty
                             ? Center(child: Text('Chưa có ngoại giao nào'))
                             : ListView.builder(
                                 itemCount: _records.length,
                                 itemBuilder: (context, index) {
                                   final record = _records[index];
                                   final isCurrentlyEditing = _editingRecord?.uid == record.uid;
                                   
                                   return ListTile(
                                     title: Text(record.danhMuc ?? ''),
                                     subtitle: Text(
                                       'Nội dung: ${record.noiDungChiTiet ?? ''} | '
                                       'Số lượng: ${record.soLuong ?? 0} | '
                                       'Đơn giá: ${NumberFormat('#,##0', 'vi_VN').format(record.donGia ?? 0)}'
                                     ),
                                     tileColor: isCurrentlyEditing ? Colors.blue.withOpacity(0.1) : null,
                                     trailing: Row(
                                       mainAxisSize: MainAxisSize.min,
                                       children: [
                                         Text(
                                           '${NumberFormat('#,##0', 'vi_VN').format(record.thanhTienTrenThang ?? 0)} VND',
                                           style: TextStyle(fontWeight: FontWeight.bold),
                                         ),
                                         IconButton(
                                           icon: Icon(
                                             isCurrentlyEditing ? Icons.cancel : Icons.edit, 
                                             color: isCurrentlyEditing ? Colors.red : Colors.blue
                                           ),
                                           onPressed: () {
                                             if (isCurrentlyEditing) {
                                               _exitEditMode();
                                             } else {
                                               _enterEditMode(record);
                                             }
                                           },
                                           tooltip: isCurrentlyEditing ? 'Hủy chỉnh sửa' : 'Chỉnh sửa',
                                         ),
                                         IconButton(
                                           icon: Icon(Icons.delete, color: Colors.red),
                                           onPressed: () => _deleteRecord(record.uid!),
                                           tooltip: 'Xóa',
                                         ),
                                       ],
                                     ),
                                   );
                                 },
                               ),
                   ),
                 ],
               ),
             ),
           ),
           
           SizedBox(height: 16),
           Row(
             mainAxisAlignment: MainAxisAlignment.end,
             children: [
               TextButton(
                 onPressed: () => Navigator.of(context).pop(),
                 child: Text('Đóng'),
               ),
             ],
           ),
         ],
       ),
     ),
   );
 }

 @override
 void dispose() {
   _danhMucController.dispose();
   _noiDungChiTietController.dispose();
   _tanSuatController.dispose();
   _donViTinhController.dispose();
   _donGiaController.dispose();
   _soLuongController.dispose();
   _thoiGianCungCapController.dispose();
   _phanBoTrenThangController.dispose();
   _ghiChuController.dispose();
   super.dispose();
 }
}
class _MayMocDialog extends StatefulWidget {
 final HDChiPhiContext costContext;

 const _MayMocDialog({required this.costContext});

 @override
 _MayMocDialogState createState() => _MayMocDialogState();
}
class _MayMocDialogState extends State<_MayMocDialog> {
  final _formKey = GlobalKey<FormState>();
  final _loaiMayController = TextEditingController();
  final _tenMayController = TextEditingController();
  final _hangSanXuatController = TextEditingController();
  final _tanSuatController = TextEditingController();
  final _donGiaMayController = TextEditingController();
  final _tinhTrangThietBiController = TextEditingController();
  final _khauHaoController = TextEditingController();
  final _soLuongCapController = TextEditingController();
  final _ghiChuController = TextEditingController();
  
  List<LinkMayMocModel> _records = [];
  bool _isLoading = true;
  int _thanhTienMay = 0;
  int _thanhTienThang = 0;
  
  // Edit mode variables
  bool _isEditMode = false;
  LinkMayMocModel? _editingRecord;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _donGiaMayController.addListener(_calculateThanhTien);
    _tinhTrangThietBiController.addListener(_calculateThanhTien);
    _khauHaoController.addListener(_calculateThanhTien);
    _soLuongCapController.addListener(_calculateThanhTien);
  }

  void _calculateThanhTien() {
    final donGiaMay = int.tryParse(_donGiaMayController.text) ?? 0;
    final tinhTrangThietBi = double.tryParse(_tinhTrangThietBiController.text) ?? 0.0;
    final khauHao = int.tryParse(_khauHaoController.text) ?? 1;
    final soLuongCap = int.tryParse(_soLuongCapController.text) ?? 0;
    
    setState(() {
      if (khauHao != 0) {
        _thanhTienMay = (donGiaMay * tinhTrangThietBi / khauHao).round();
        _thanhTienThang = (_thanhTienMay * soLuongCap).round();
      } else {
        _thanhTienMay = 0;
        _thanhTienThang = 0;
      }
    });
  }

  Future<void> _loadRecords() async {
    if (widget.costContext.hopDongUid != null) {
      final dbHelper = DBHelper();
      final records = await dbHelper.getLinkMayMocsByContract(widget.costContext.hopDongUid!);
      setState(() {
        _records = records;
        _isLoading = false;
      });
    }
  }

  void _enterEditMode(LinkMayMocModel record) {
    setState(() {
      _isEditMode = true;
      _editingRecord = record;
      
      _loaiMayController.text = record.loaiMay ?? '';
      _tenMayController.text = record.tenMay ?? '';
      _hangSanXuatController.text = record.hangSanXuat ?? '';
      _tanSuatController.text = record.tanSuat ?? '';
      _donGiaMayController.text = (record.donGiaMay ?? 0).toString();
      _tinhTrangThietBiController.text = (record.tinhTrangThietBi ?? 0).toString();
      _khauHaoController.text = (record.khauHao ?? 0).toString();
      _soLuongCapController.text = (record.soLuongCap ?? 0).toString();
      _ghiChuController.text = record.ghiChu ?? '';
      
      _calculateThanhTien();
    });
  }

  void _exitEditMode() {
    setState(() {
      _isEditMode = false;
      _editingRecord = null;
    });
    _clearForm();
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isEditMode && _editingRecord != null) {
      final updatedRecord = _editingRecord!.copyWith(
        loaiMay: _loaiMayController.text.trim(),
        tenMay: _tenMayController.text.trim(),
        hangSanXuat: _hangSanXuatController.text.trim(),
        tanSuat: _tanSuatController.text.trim(),
        donGiaMay: int.tryParse(_donGiaMayController.text),
        tinhTrangThietBi: double.tryParse(_tinhTrangThietBiController.text),
        khauHao: int.tryParse(_khauHaoController.text),
        thanhTienMay: _thanhTienMay,
        soLuongCap: int.tryParse(_soLuongCapController.text),
        thanhTienThang: _thanhTienThang,
        ghiChu: _ghiChuController.text.trim(),
      );

      final dbHelper = DBHelper();
      await dbHelper.updateLinkMayMoc(updatedRecord);

      final success = await HDChiPhi._sendDataToServer({
        'table': 'LinkMayMoc',
        'action': 'update',
        'data': updatedRecord.toMap(),
      });

      if (success) {
        _showSuccessMessage('Đã cập nhật thành công!');
        _exitEditMode();
        _loadRecords();
      } else {
        _showErrorMessage('Lỗi khi cập nhật dữ liệu');
      }
    } else {
      final record = LinkMayMocModel(
        uid: HDChiPhi._uuid.v4(),
        hopDongID: widget.costContext.hopDongUid,
        thang: widget.costContext.hopDongThang,
        nguoiTao: widget.costContext.username,
        maKinhDoanh: widget.costContext.hopDongMaKinhDoanh,
        loaiMay: _loaiMayController.text.trim(),
        tenMay: _tenMayController.text.trim(),
        hangSanXuat: _hangSanXuatController.text.trim(),
        tanSuat: _tanSuatController.text.trim(),
        donGiaMay: int.tryParse(_donGiaMayController.text),
        tinhTrangThietBi: double.tryParse(_tinhTrangThietBiController.text),
        khauHao: int.tryParse(_khauHaoController.text),
        thanhTienMay: _thanhTienMay,
        soLuongCap: int.tryParse(_soLuongCapController.text),
        thanhTienThang: _thanhTienThang,
        ghiChu: _ghiChuController.text.trim(),
      );

      final dbHelper = DBHelper();
      await dbHelper.insertLinkMayMoc(record);

      final success = await HDChiPhi._sendDataToServer({
        'table': 'LinkMayMoc',
        'action': 'insert',
        'data': record.toMap(),
      });

      if (success) {
        _showSuccessMessage('Đã lưu thành công!');
        _clearForm();
        _loadRecords();
      } else {
        _showErrorMessage('Lỗi khi lưu dữ liệu');
      }
    }

    final newTotal = await HDChiPhi._calculateTotalCost(
      widget.costContext.hopDongUid!, 
      'MayMoc'
    );
    widget.costContext.onCostUpdated('MayMoc', newTotal);
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$message Vui lòng lưu hợp đồng và tải lại để cập nhật.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _clearForm() {
    _loaiMayController.clear();
    _tenMayController.clear();
    _hangSanXuatController.clear();
    _tanSuatController.clear();
    _donGiaMayController.clear();
    _tinhTrangThietBiController.clear();
    _khauHaoController.clear();
    _soLuongCapController.clear();
    _ghiChuController.clear();
    setState(() {
      _thanhTienMay = 0;
      _thanhTienThang = 0;
    });
  }

  Future<void> _deleteRecord(String uid) async {
    final dbHelper = DBHelper();
    await dbHelper.deleteLinkMayMoc(uid);

    await HDChiPhi._sendDataToServer({
      'table': 'LinkMayMoc',
      'action': 'delete',
      'uid': uid,
    });

    final newTotal = await HDChiPhi._calculateTotalCost(
      widget.costContext.hopDongUid!, 
      'MayMoc'
    );
    widget.costContext.onCostUpdated('MayMoc', newTotal);
    _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    final tinhTrangPercent = (double.tryParse(_tinhTrangThietBiController.text) ?? 0.0) * 100;
    
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 1.7,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Chi phí Máy móc - ${widget.costContext.hopDongTen}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            
            Expanded(
              flex: 1,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _isEditMode ? 'Chỉnh sửa máy móc' : 'Thêm máy móc mới', 
                              style: TextStyle(fontWeight: FontWeight.bold)
                            ),
                            if (_isEditMode) ...[
                              Spacer(),
                              TextButton(
                                onPressed: _exitEditMode,
                                child: Text('Hủy chỉnh sửa'),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 2),
                        Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    ElevatedButton(
      onPressed: _saveRecord,
      child: Text(_isEditMode ? 'Cập nhật' : 'Lưu'),
    ),
    TextButton(
      onPressed: _isEditMode ? _exitEditMode : _clearForm,
      child: Text(_isEditMode ? 'Hủy' : 'Xóa form'),
    ),
  ],
),
                        SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _loaiMayController,
                                decoration: InputDecoration(
                                  labelText: 'Loại máy *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                              ),
                            ),
                            SizedBox(width: 2),
                            Expanded(
                              child: TextFormField(
                                controller: _tenMayController,
                                decoration: InputDecoration(
                                  labelText: 'Tên máy',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(width: 2),
                            Expanded(
                              child: TextFormField(
                                controller: _hangSanXuatController,
                                decoration: InputDecoration(
                                  labelText: 'Hãng sản xuất',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(width: 2),
                            Expanded(
                              child: TextFormField(
                                controller: _tanSuatController,
                                decoration: InputDecoration(
                                  labelText: 'Tần suất',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _donGiaMayController,
                                decoration: InputDecoration(
                                  labelText: 'Giá máy *',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                              ),
                            ),
                            SizedBox(width: 2),
                            Expanded(
                              child: TextFormField(
                                controller: _tinhTrangThietBiController,
                                decoration: InputDecoration(
                                  labelText: 'Tình trạng máy * (0-1)',
                                  helperText: '${tinhTrangPercent.toStringAsFixed(0)}%',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value?.trim().isEmpty == true) return 'Bắt buộc';
                                  final val = double.tryParse(value!);
                                  if (val == null || val < 0 || val > 1) return 'Giá trị từ 0 đến 1';
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(width: 2),
                            Expanded(
                              child: TextFormField(
                                controller: _khauHaoController,
                                decoration: InputDecoration(
                                  labelText: 'Khấu hao *',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                              ),
                            ),
                            SizedBox(width: 2),
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Thành tiền máy: ${NumberFormat('#,##0', 'vi_VN').format(_thanhTienMay)}',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _soLuongCapController,
                                decoration: InputDecoration(
                                  labelText: 'Số lượng cấp *',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                              ),
                            ),
                            SizedBox(width: 2),
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Thành tiền tháng: ${NumberFormat('#,##0', 'vi_VN').format(_thanhTienThang)}',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            SizedBox(width: 2),
                            Expanded(
                              child: TextFormField(
                                controller: _ghiChuController,
                                decoration: InputDecoration(
                                  labelText: 'Ghi chú',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),

                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 2),
            
            Expanded(
              flex: 2,
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Danh sách máy móc (${_records.length} mục)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: _isLoading
                          ? Center(child: CircularProgressIndicator())
                          : _records.isEmpty
                              ? Center(child: Text('Chưa có máy móc nào'))
                              : ListView.builder(
                                  itemCount: _records.length,
                                  itemBuilder: (context, index) {
                                    final record = _records[index];
                                    final isCurrentlyEditing = _editingRecord?.uid == record.uid;
                                    final tinhTrangPercent = ((record.tinhTrangThietBi ?? 0.0) * 100).toStringAsFixed(0);
                                    
                                    return ListTile(
                                      title: Text('${record.loaiMay ?? ''} - ${record.tenMay ?? ''}'),
                                      subtitle: Text(
                                        'Hãng: ${record.hangSanXuat ?? ''} | '
                                        'Tình trạng: $tinhTrangPercent% | '
                                        'Số lượng: ${record.soLuongCap ?? 0}'
                                      ),
                                      tileColor: isCurrentlyEditing ? Colors.blue.withOpacity(0.1) : null,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${NumberFormat('#,##0', 'vi_VN').format(record.thanhTienThang ?? 0)} VND',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              isCurrentlyEditing ? Icons.cancel : Icons.edit, 
                                              color: isCurrentlyEditing ? Colors.red : Colors.blue
                                            ),
                                            onPressed: () {
                                              if (isCurrentlyEditing) {
                                                _exitEditMode();
                                              } else {
                                                _enterEditMode(record);
                                              }
                                            },
                                            tooltip: isCurrentlyEditing ? 'Hủy chỉnh sửa' : 'Chỉnh sửa',
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _deleteRecord(record.uid!),
                                            tooltip: 'Xóa',
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
           Row(
             mainAxisAlignment: MainAxisAlignment.end,
             children: [
               TextButton(
                 onPressed: () => Navigator.of(context).pop(),
                 child: Text('Đóng'),
               ),
             ],
           ),
         ],
       ),
     ),
   );
 }

 @override
 void dispose() {
   _loaiMayController.dispose();
   _tenMayController.dispose();
   _hangSanXuatController.dispose();
   _tanSuatController.dispose();
   _donGiaMayController.dispose();
   _tinhTrangThietBiController.dispose();
   _khauHaoController.dispose();
   _soLuongCapController.dispose();
   _ghiChuController.dispose();
   super.dispose();
 }
}
class _LuongDialog extends StatefulWidget {
 final HDChiPhiContext costContext;

 const _LuongDialog({required this.costContext});

 @override
 _LuongDialogState createState() => _LuongDialogState();
}
class _LuongDialogState extends State<_LuongDialog> {
  final _formKey = GlobalKey<FormState>();
  final _hangMucController = TextEditingController();
  final _moTaController = TextEditingController();
  final _donGiaController = TextEditingController();
  final _soLuongController = TextEditingController();
  
  List<LinkLuongModel> _records = [];
  bool _isLoading = true;
  int _thanhTien = 0;
  
  // Edit mode variables
  bool _isEditMode = false;
  LinkLuongModel? _editingRecord;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _donGiaController.addListener(_calculateThanhTien);
    _soLuongController.addListener(_calculateThanhTien);
  }

  void _calculateThanhTien() {
    final donGia = int.tryParse(_donGiaController.text) ?? 0;
    final soLuong = double.tryParse(_soLuongController.text) ?? 0.0;
    setState(() {
      _thanhTien = (donGia * soLuong).round();
    });
  }

  Future<void> _loadRecords() async {
    if (widget.costContext.hopDongUid != null) {
      final dbHelper = DBHelper();
      final records = await dbHelper.getLinkLuongsByContract(widget.costContext.hopDongUid!);
      setState(() {
        _records = records;
        _isLoading = false;
      });
    }
  }

  void _enterEditMode(LinkLuongModel record) {
    setState(() {
      _isEditMode = true;
      _editingRecord = record;
      
      _hangMucController.text = record.hangMuc ?? '';
      _moTaController.text = record.moTa ?? '';
      _donGiaController.text = (record.donGia ?? 0).toString();
      _soLuongController.text = (record.soLuong ?? 0).toString();
      
      _calculateThanhTien();
    });
  }

  void _exitEditMode() {
    setState(() {
      _isEditMode = false;
      _editingRecord = null;
    });
    _clearForm();
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isEditMode && _editingRecord != null) {
      final updatedRecord = _editingRecord!.copyWith(
        hangMuc: _hangMucController.text.trim(),
        moTa: _moTaController.text.trim(),
        donGia: int.tryParse(_donGiaController.text),
        soLuong: double.tryParse(_soLuongController.text),
        thanhTien: _thanhTien,
      );

      final dbHelper = DBHelper();
      await dbHelper.updateLinkLuong(updatedRecord);

      final success = await HDChiPhi._sendDataToServer({
        'table': 'LinkLuong',
        'action': 'update',
        'data': updatedRecord.toMap(),
      });

      if (success) {
        _showSuccessMessage('Đã cập nhật thành công!');
        _exitEditMode();
        _loadRecords();
      } else {
        _showErrorMessage('Lỗi khi cập nhật dữ liệu');
      }
    } else {
      // Create new record (existing logic)
      final record = LinkLuongModel(
        uid: HDChiPhi._uuid.v4(),
        hopDongID: widget.costContext.hopDongUid,
        thang: widget.costContext.hopDongThang,
        nguoiTao: widget.costContext.username,
        maKinhDoanh: widget.costContext.hopDongMaKinhDoanh,
        hangMuc: _hangMucController.text.trim(),
        moTa: _moTaController.text.trim(),
        donGia: int.tryParse(_donGiaController.text),
        soLuong: double.tryParse(_soLuongController.text),
        thanhTien: _thanhTien,
      );

      final dbHelper = DBHelper();
      await dbHelper.insertLinkLuong(record);

      final success = await HDChiPhi._sendDataToServer({
        'table': 'LinkLuong',
        'action': 'insert',
        'data': record.toMap(),
      });

      if (success) {
        _showSuccessMessage('Đã lưu thành công!');
        _clearForm();
        _loadRecords();
      } else {
        _showErrorMessage('Lỗi khi lưu dữ liệu');
      }
    }

    final newTotal = await HDChiPhi._calculateTotalCost(
      widget.costContext.hopDongUid!, 
      'Luong'
    );
    widget.costContext.onCostUpdated('Luong', newTotal);
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$message Vui lòng lưu hợp đồng và tải lại để cập nhật.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _clearForm() {
    _hangMucController.clear();
    _moTaController.clear();
    _donGiaController.clear();
    _soLuongController.clear();
    setState(() {
      _thanhTien = 0;
    });
  }

  Future<void> _deleteRecord(String uid) async {
    final dbHelper = DBHelper();
    await dbHelper.deleteLinkLuong(uid);

    await HDChiPhi._sendDataToServer({
      'table': 'LinkLuong',
      'action': 'delete',
      'uid': uid,
    });

    final newTotal = await HDChiPhi._calculateTotalCost(
      widget.costContext.hopDongUid!, 
      'Luong'
    );
    widget.costContext.onCostUpdated('Luong', newTotal);
    _loadRecords();
  }

 @override
 Widget build(BuildContext context) {
   return Dialog(
     child: Container(
       width: MediaQuery.of(context).size.width * 0.9,
       height: MediaQuery.of(context).size.height * 0.9,
       padding: EdgeInsets.all(16),
       child: Column(
         children: [
           Text(
             'Chi phí Lương - ${widget.costContext.hopDongTen}',
             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
           ),
           SizedBox(height: 16),
           
           Expanded(
             flex: 1,
             child: Card(
               child: Padding(
                 padding: EdgeInsets.all(16),
                 child: Form(
                   key: _formKey,
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Row(
                         children: [
                           Text(
                             _isEditMode ? 'Chỉnh sửa lương' : 'Thêm lương mới', 
                             style: TextStyle(fontWeight: FontWeight.bold)
                           ),
                           if (_isEditMode) ...[
                             Spacer(),
                             TextButton(
                               onPressed: _exitEditMode,
                               child: Text('Hủy chỉnh sửa'),
                               style: TextButton.styleFrom(foregroundColor: Colors.red),
                             ),
                           ],
                         ],
                       ),
                       SizedBox(height: 8),
                       Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    ElevatedButton(
      onPressed: _saveRecord,
      child: Text(_isEditMode ? 'Cập nhật' : 'Lưu'),
    ),
    TextButton(
      onPressed: _isEditMode ? _exitEditMode : _clearForm,
      child: Text(_isEditMode ? 'Hủy' : 'Xóa form'),
    ),
  ],
),
                       SizedBox(height: 8),
                       Row(
                         children: [
                           Expanded(
                             child: TextFormField(
                               controller: _hangMucController,
                               decoration: InputDecoration(
                                 labelText: 'Hạng mục *',
                                 border: OutlineInputBorder(),
                               ),
                               validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: TextFormField(
                               controller: _moTaController,
                               decoration: InputDecoration(
                                 labelText: 'Mô tả',
                                 border: OutlineInputBorder(),
                               ),
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: TextFormField(
                               controller: _donGiaController,
                               decoration: InputDecoration(
                                 labelText: 'Đơn giá *',
                                 border: OutlineInputBorder(),
                               ),
                               keyboardType: TextInputType.number,
                               inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                               validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: TextFormField(
                               controller: _soLuongController,
                               decoration: InputDecoration(
                                 labelText: 'Số lượng *',
                                 border: OutlineInputBorder(),
                               ),
                               keyboardType: TextInputType.numberWithOptions(decimal: true),
                               validator: (value) => value?.trim().isEmpty == true ? 'Bắt buộc' : null,
                             ),
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: Container(
                               padding: EdgeInsets.all(12),
                               decoration: BoxDecoration(
                                 border: Border.all(color: Colors.grey),
                                 borderRadius: BorderRadius.circular(4),
                               ),
                               child: Text(
                                 'Thành tiền: ${NumberFormat('#,##0', 'vi_VN').format(_thanhTien)}',
                                 style: TextStyle(fontWeight: FontWeight.bold),
                               ),
                             ),
                           ),
                         ],
                       ),

                     ],
                   ),
                 ),
               ),
             ),
           ),
           
           SizedBox(height: 16),
           
           Expanded(
             flex: 2,
             child: Card(
               child: Column(
                 children: [
                   Padding(
                     padding: EdgeInsets.all(16),
                     child: Text(
                       'Danh sách lương (${_records.length} mục)',
                       style: TextStyle(fontWeight: FontWeight.bold),
                     ),
                   ),
                   Expanded(
                     child: _isLoading
                         ? Center(child: CircularProgressIndicator())
                         : _records.isEmpty
                             ? Center(child: Text('Chưa có lương nào'))
                             : ListView.builder(
                                 itemCount: _records.length,
                                 itemBuilder: (context, index) {
                                   final record = _records[index];
                                   final isCurrentlyEditing = _editingRecord?.uid == record.uid;
                                   
                                   return ListTile(
                                     title: Text(record.hangMuc ?? ''),
                                     subtitle: Text(
                                       'Mô tả: ${record.moTa ?? ''} | '
                                       'Số lượng: ${record.soLuong ?? 0} | '
                                       'Đơn giá: ${NumberFormat('#,##0', 'vi_VN').format(record.donGia ?? 0)}'
                                     ),
                                     tileColor: isCurrentlyEditing ? Colors.blue.withOpacity(0.1) : null,
                                     trailing: Row(
                                       mainAxisSize: MainAxisSize.min,
                                       children: [
                                         Text(
                                           '${NumberFormat('#,##0', 'vi_VN').format(record.thanhTien ?? 0)} VND',
                                           style: TextStyle(fontWeight: FontWeight.bold),
                                         ),
                                         IconButton(
                                           icon: Icon(
                                             isCurrentlyEditing ? Icons.cancel : Icons.edit, 
                                             color: isCurrentlyEditing ? Colors.red : Colors.blue
                                           ),
                                           onPressed: () {
                                             if (isCurrentlyEditing) {
                                               _exitEditMode();
                                             } else {
                                               _enterEditMode(record);
                                             }
                                           },
                                           tooltip: isCurrentlyEditing ? 'Hủy chỉnh sửa' : 'Chỉnh sửa',
                                         ),
                                         IconButton(
                                           icon: Icon(Icons.delete, color: Colors.red),
                                           onPressed: () => _deleteRecord(record.uid!),
                                           tooltip: 'Xóa',
                                         ),
                                       ],
                                     ),
                                   );
                                 },
                               ),
                   ),
                 ],
               ),
             ),
           ),
           
           SizedBox(height: 16),
           Row(
             mainAxisAlignment: MainAxisAlignment.end,
             children: [
               TextButton(
                 onPressed: () => Navigator.of(context).pop(),
                 child: Text('Đóng'),
               ),
             ],
           ),
         ],
       ),
     ),
   );
 }

 @override
 void dispose() {
   _hangMucController.dispose();
   _moTaController.dispose();
   _donGiaController.dispose();
   _soLuongController.dispose();
   super.dispose();
 }
}