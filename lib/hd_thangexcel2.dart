// hd_thangexcel2.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'table_models.dart';
import 'db_helper.dart';

class HDThangExcelGenerator {
  Future<bool> generateAndShareExcel({
    required List<LinkHopDongModel> contracts,
    required String period,
    required DBHelper dbHelper,
    required BuildContext context,
  }) async {
    try {
      // Show choice dialog
      final choice = await _showExportChoiceDialog(context);
      if (choice == null) return false; // User cancelled
      
      // Create Excel workbook
      var excel = Excel.createExcel();
      
      // Remove default sheet
      excel.delete('Sheet1');
      
      // Create summary sheet (non-financial)
      await _createSummarySheet(excel, contracts, period);
      
      // Create contracts sheet (all contracts in one sheet, non-financial)
      await _createAllContractsSheet(excel, contracts);
      
      // Create cost tables sheets (one sheet per cost type - kept normal)
      await _createCostTablesSheets(excel, contracts, dbHelper);
      
      // Generate filename
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'BaoCao_HopDong_${_formatPeriodForFile(period)}_$dateStr.xlsx';
      
      // Save and handle based on user choice
      final fileBytes = excel.encode()!;
      
      if (choice == 'share') {
        return await _handleShare(fileBytes, fileName, period, context);
      } else {
        return await _handleSaveToAppFolder(fileBytes, fileName, context);
      }
    } catch (e) {
      print('Error in Excel generation: $e');
      return false;
    }
  }
  
  Future<String?> _showExportChoiceDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Xuất file Excel'),
          content: Text('Bạn muốn chia sẻ file hay lưu vào thư mục ứng dụng?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('share'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.share, size: 16),
                  SizedBox(width: 4),
                  Text('Chia sẻ'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('save'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder, size: 16),
                  SizedBox(width: 4),
                  Text('Lưu vào thư mục'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
  
  Future<bool> _handleShare(List<int> fileBytes, String fileName, String period, BuildContext context) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(fileBytes);
      
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Báo cáo hợp đồng tháng ${_formatPeriod(period)}',
        subject: 'Báo cáo hợp đồng ${_formatPeriod(period)}',
        sharePositionOrigin: box != null 
            ? Rect.fromLTWH(
                box.localToGlobal(Offset.zero).dx,
                box.localToGlobal(Offset.zero).dy,
                box.size.width,
                box.size.height / 2,
              )
            : null,
      );
      return true;
    } catch (e) {
      print('Error sharing file: $e');
      return false;
    }
  }
  
  Future<bool> _handleSaveToAppFolder(List<int> fileBytes, String fileName, BuildContext context) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final appFolder = Directory('${directory.path}/BaoCao_HopDong');
      
      // Create folder if it doesn't exist
      if (!await appFolder.exists()) {
        await appFolder.create(recursive: true);
      }
      
      final filePath = '${appFolder.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      
      // Show success dialog with option to open folder
      await _showSaveSuccessDialog(context, appFolder.path, fileName);
      
      return true;
    } catch (e) {
      print('Error saving to app folder: $e');
      return false;
    }
  }
  
  Future<void> _showSaveSuccessDialog(BuildContext context, String folderPath, String fileName) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Lưu thành công'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File đã được lưu:'),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  fileName,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 8),
              Text('Đường dẫn thư mục:'),
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  folderPath,
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Đóng'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await _openFolder(folderPath);
              },
              icon: Icon(Icons.folder_open, size: 16),
              label: Text('Mở thư mục'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF024965),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
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
  
  Future<void> _createSummarySheet(Excel excel, List<LinkHopDongModel> contracts, String period) async {
    var sheet = excel['Tổng quan'];
    
    // Title
    sheet.cell(CellIndex.indexByString('A1')).value = 'BÁO CÁO TỔNG QUAN HỢP ĐỒNG';
    sheet.cell(CellIndex.indexByString('A2')).value = 'Tháng: ${_formatPeriod(period)}';
    
    // Summary data (non-financial only)
    int row = 4;
    sheet.cell(CellIndex.indexByString('A$row')).value = 'Chỉ tiêu';
    sheet.cell(CellIndex.indexByString('B$row')).value = 'Giá trị';
    
    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = 'Tổng số hợp đồng';
    sheet.cell(CellIndex.indexByString('B$row')).value = contracts.length;
    
    // Worker statistics
    double totalWorkers = 0;
    for (var contract in contracts) {
      totalWorkers += (contract.congNhanDuocCo ?? 0.0);
    }
    
    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = 'Tổng số công nhân được có';
    sheet.cell(CellIndex.indexByString('B$row')).value = totalWorkers;
    
    // Statistics by type (contract count only)
    row += 2;
    sheet.cell(CellIndex.indexByString('A$row')).value = 'THỐNG KÊ THEO LOẠI HÌNH';
    
    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = 'Loại hình';
    sheet.cell(CellIndex.indexByString('B$row')).value = 'Số lượng HĐ';
    sheet.cell(CellIndex.indexByString('C$row')).value = 'Số CN được có';
    
    Map<String, int> typeCount = {};
    Map<String, double> typeWorkers = {};
    
    for (var contract in contracts) {
      String type = contract.loaiHinh ?? 'Khác';
      typeCount[type] = (typeCount[type] ?? 0) + 1;
      typeWorkers[type] = (typeWorkers[type] ?? 0) + (contract.congNhanDuocCo ?? 0.0);
    }
    
    for (var type in typeCount.keys) {
      row++;
      sheet.cell(CellIndex.indexByString('A$row')).value = type;
      sheet.cell(CellIndex.indexByString('B$row')).value = typeCount[type]!;
      sheet.cell(CellIndex.indexByString('C$row')).value = typeWorkers[type]!;
    }
    
    // Statistics by status
    row += 2;
    sheet.cell(CellIndex.indexByString('A$row')).value = 'THỐNG KÊ THEO TRẠNG THÁI';
    
    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = 'Trạng thái';
    sheet.cell(CellIndex.indexByString('B$row')).value = 'Số lượng HĐ';
    
    Map<String, int> statusCount = {};
    
    for (var contract in contracts) {
      String status = contract.trangThai ?? 'Không xác định';
      statusCount[status] = (statusCount[status] ?? 0) + 1;
    }
    
    for (var status in statusCount.keys) {
      row++;
      sheet.cell(CellIndex.indexByString('A$row')).value = status;
      sheet.cell(CellIndex.indexByString('B$row')).value = statusCount[status]!;
    }
  }
  
  Future<void> _createAllContractsSheet(Excel excel, List<LinkHopDongModel> contracts) async {
    var sheet = excel['Tất cả hợp đồng'];
    
    // Headers - only non-financial contract columns
    List<String> headers = [
      'STT', 'UID','Tháng thực hiện','Vùng miền', 'Người tạo','Trạng thái', 
      'Tên hợp đồng', 'Mã KD', 'Mã KT', 'Số hợp đồng', 'Địa chỉ', 'Loại hình',
      'CN theo HĐ', 'CN tăng', 'CN giảm', 'CN được có', 'GS cố định',
      'Thời hạn HĐ (tháng)', 'TH bắt đầu', 'TH kết thúc',
      'Đáo hạn HĐ', 'CV cần giải quyết',
      'CN ca 1', 'CN ca 2', 'CN ca 3', 'CN ca HC', 'CN ca khác', 
      'Ghi chú bố trí NS', 'File HĐ', 'Ghi chú HĐ', 'Ngày cập nhật cuối'
    ];
    
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = headers[i];
    }
    
    // Data rows
    for (int i = 0; i < contracts.length; i++) {
      var contract = contracts[i];
      int row = i + 1;
      
      List<dynamic> data = [
        i + 1,
        contract.uid ?? '',
        contract.thang ?? '',
        contract.vungMien ?? '',
        contract.nguoiTao ?? '',
        contract.trangThai ?? '',
        contract.tenHopDong ?? '',
        contract.maKinhDoanh ?? '',
        contract.maKeToan ?? '',
        contract.soHopDong ?? '',
        contract.diaChi ?? '',
        contract.loaiHinh ?? '',
        contract.congNhanHopDong ?? 0,
        contract.congNhanHDTang ?? 0,
        contract.congNhanHDGiam ?? 0,
        contract.congNhanDuocCo ?? 0,
        contract.giamSatCoDinh ?? 0,
        contract.thoiHanHopDong ?? '',
        _formatDate(contract.thoiHanBatDau),
        _formatDate(contract.thoiHanKetthuc),
        contract.daoHanHopDong ?? '',
        contract.congViecCanGiaiQuyet ?? '',
        contract.congNhanCa1 ?? '',
        contract.congNhanCa2 ?? '',
        contract.congNhanCa3 ?? '',
        contract.congNhanCaHC ?? '',
        contract.congNhanCaKhac ?? '',
        contract.congNhanGhiChuBoTriNhanSu ?? '',
        contract.fileHopDong ?? '',
        contract.ghiChuHopDong ?? '',
        _formatDate(contract.ngayCapNhatCuoi),
      ];
      
      for (int j = 0; j < data.length; j++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row));
        cell.value = data[j];
      }
    }
  }
  
  Future<void> _createCostTablesSheets(Excel excel, List<LinkHopDongModel> contracts, DBHelper dbHelper) async {
    // Get all contract IDs
    List<String> contractIds = contracts.where((c) => c.uid != null).map((c) => c.uid!).toList();
    
    if (contractIds.isEmpty) return;
    
    // Create sheets for each cost type (kept normal with all financial details)
    await _createVatLieuSheet(excel, contractIds, dbHelper);
    await _createDinhKySheet(excel, contractIds, dbHelper);
    await _createLeTetTCSheet(excel, contractIds, dbHelper);
    await _createPhuCapSheet(excel, contractIds, dbHelper);
    //await _createNgoaiGiaoSheet(excel, contractIds, dbHelper);
    await _createMayMocSheet(excel, contractIds, dbHelper);
    await _createLuongSheet(excel, contractIds, dbHelper);
  }
  
  Future<void> _createVatLieuSheet(Excel excel, List<String> contractIds, DBHelper dbHelper) async {
    var sheet = excel['Vật liệu'];
    
    // Headers
    List<String> headers = [
      'STT', 'UID', 'Mã KD', 'Danh mục vật tư tiêu hao', 'Nhãn hiệu', 'Quy cách',
      'Số lượng', 'Đơn vị tính', 'Đơn giá cấp KH', 'Thành tiền', 'Tháng' 
    ];
    
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = headers[i];
    }
    
    int row = 1;
    int stt = 1;
    
    for (String contractId in contractIds) {
      try {
        List<LinkVatTuModel> records = await dbHelper.getLinkVatTusByContract(contractId);
        
        for (var record in records) {
          List<dynamic> data = [
            stt++,
            record.uid ?? '',
            record.maKinhDoanh ?? '',
            record.danhMucVatTuTieuHao ?? '',
            record.nhanHieu ?? '',
            record.quyCach ?? '',
            record.soLuong ?? 0,
            record.donViTinh ?? '',
            _safeToDouble(record.donGiaCapKhachHang),
            _safeToDouble(record.thanhTien),
            _formatDate(record.thang),
          ];
          
          for (int j = 0; j < data.length; j++) {
            var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row));
            cell.value = data[j];
          }
          row++;
        }
      } catch (e) {
        print('Error loading VatLieu for contract $contractId: $e');
      }
    }
  }
  
  Future<void> _createDinhKySheet(Excel excel, List<String> contractIds, DBHelper dbHelper) async {
    var sheet = excel['Công việc định kỳ'];
    
    // Headers
    List<String> headers = [
      'STT', 'UID', 'Mã KD', 'Danh mục công việc', 'Chi tiết công việc',
      'Tổng tiền/lần thực hiện', 'Tần suất thực hiện/tháng', 'Số lượng', 
      'Đơn giá/tháng', 'Thành tiền', 'Tháng'
    ];
    
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = headers[i];
    }
    
    int row = 1;
    int stt = 1;
    
    for (String contractId in contractIds) {
      try {
        List<LinkDinhKyModel> records = await dbHelper.getLinkDinhKysByContract(contractId);
        
        for (var record in records) {
          List<dynamic> data = [
            stt++,
            record.uid ?? '',
            record.maKinhDoanh ?? '',
            record.danhMucCongViec ?? '',
            record.chiTietCongViec ?? '',
            record.tongTienTrenLanThucHien ?? '',
            record.tanSuatThucHienTrenThang ?? 0,
            record.soLuong ?? 0,
            _safeToDouble(record.donGiaTrenThang),
            _safeToDouble(record.thanhTien),
            _formatDate(record.thang),
          ];
          
          for (int j = 0; j < data.length; j++) {
            var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row));
            cell.value = data[j];
          }
          row++;
        }
      } catch (e) {
        print('Error loading DinhKy for contract $contractId: $e');
      }
    }
  }
  
  Future<void> _createLeTetTCSheet(Excel excel, List<String> contractIds, DBHelper dbHelper) async {
    var sheet = excel['Lễ tết tăng ca'];
    
    // Headers
    List<String> headers = [
      'STT', 'UID', 'Mã KD', 'Danh mục công việc', 'Chi tiết công việc',
      'Đơn vị tính', 'Tần suất thực hiện trên tháng', 'Đơn giá', 'Số lượng nhân viên',
      'Thời gian cung cấp','Phân bổ trên tháng', 'Thành tiền trên tháng', 
      'Ghi chú', 'Tháng'
    ];
    
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = headers[i];
    }
    
    int row = 1;
    int stt = 1;
    
    for (String contractId in contractIds) {
      try {
        List<LinkLeTetTCModel> records = await dbHelper.getLinkLeTetTCsByContract(contractId);
        
        for (var record in records) {
          List<dynamic> data = [
            stt++,
            record.uid ?? '',
            record.maKinhDoanh ?? '',
            record.danhMucCongViec ?? '',
            record.chiTietCongViec ?? '',
            record.donViTinh ?? '',
            record.tanSuatTrenLan ?? 0,
            _safeToDouble(record.donGia),
            record.soLuongNhanVien ?? 0,
            record.thoiGianCungCapDVT ?? '',
            record.phanBoTrenThang ?? '',
            _safeToDouble(record.thanhTienTrenThang),
            record.ghiChu ?? '',
            _formatDate(record.thang),
          ];
          
          for (int j = 0; j < data.length; j++) {
            var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row));
            cell.value = data[j];
          }
          row++;
        }
      } catch (e) {
        print('Error loading LeTetTC for contract $contractId: $e');
      }
    }
  }
  
  Future<void> _createPhuCapSheet(Excel excel, List<String> contractIds, DBHelper dbHelper) async {
    var sheet = excel['Phụ cấp'];
    
    // Headers
    List<String> headers = [
      'STT', 'UID', 'Mã KD', 'Danh mục công việc', 'Chi tiết công việc',
      'Tần suất trên lần','Đơn vị tính','Đơn giá','Số lượng NV',
      'Thời gian cung cấp','Phân bổ trên tháng','Thành tiền tháng',
      'Ghi chú', 'Tháng'
    ];
    
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = headers[i];
    }
    
    int row = 1;
    int stt = 1;
    
    for (String contractId in contractIds) {
      try {
        List<LinkPhuCapModel> records = await dbHelper.getLinkPhuCapsByContract(contractId);
        
        for (var record in records) {
          List<dynamic> data = [
            stt++,
            record.uid ?? '',
            record.maKinhDoanh ?? '',
            record.danhMucCongViec ?? '',
            record.chiTietCongViec ?? '',
            record.tanSuatTrenLan ?? 0,
            record.donViTinh ?? '',
            _safeToDouble(record.donGia),
            record.soLuongNhanVien ?? 0,
            record.thoiGianCungCapDVT ?? '',
            record.phanBoTrenThang ?? '',
            _safeToDouble(record.thanhTienTrenThang),
            record.ghiChu ?? '',
            _formatDate(record.thang),
          ];
          
          for (int j = 0; j < data.length; j++) {
            var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row));
            cell.value = data[j];
          }
          row++;
        }
      } catch (e) {
        print('Error loading PhuCap for contract $contractId: $e');
      }
    }
  }
  
  Future<void> _createNgoaiGiaoSheet(Excel excel, List<String> contractIds, DBHelper dbHelper) async {
    var sheet = excel['Ngoại giao'];
    
    // Headers
    List<String> headers = [
      'STT', 'UID', 'Mã KD', 'Danh mục', 'Nội dung chi tiết',
      'Tần suất','Đơn vị tính','Đơn giá','Số lượng','Thời gian cung cấp',
      'Phân bổ trên tháng','Thành tiền trên tháng', 'Ghi chú', 'Tháng'
    ];
    
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = headers[i];
    }
    
    int row = 1;
    int stt = 1;
    
    for (String contractId in contractIds) {
      try {
        List<LinkNgoaiGiaoModel> records = await dbHelper.getLinkNgoaiGiaosByContract(contractId);
        
        for (var record in records) {
          List<dynamic> data = [
            stt++,
            record.uid ?? '',
            record.maKinhDoanh ?? '',
            record.danhMuc ?? '',
            record.noiDungChiTiet ?? '',
            record.tanSuat ?? '',
            record.donViTinh ?? '',
            _safeToDouble(record.donGia),
            record.soLuong ?? '',
            record.thoiGianCungCapDVT ?? '',
            record.phanBoTrenThang ?? '',
            _safeToDouble(record.thanhTienTrenThang),
            record.ghiChu ?? '',
            _formatDate(record.thang),
          ];
          
          for (int j = 0; j < data.length; j++) {
            var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row));
            cell.value = data[j];
          }
          row++;
        }
      } catch (e) {
        print('Error loading NgoaiGiao for contract $contractId: $e');
      }
    }
  }

  Future<void> _createMayMocSheet(Excel excel, List<String> contractIds, DBHelper dbHelper) async {
    var sheet = excel['Máy móc'];
    
    // Headers
    List<String> headers = [
      'STT', 'UID', 'Mã KD', 'Loại máy','Tên máy','Hãng sản xuất','Tần suất',
      'Đơn giá máy','Tình trạng thiết bị','Khấu hao','Thành tiền máy',
      'Số lượng cấp','Thành tiền tháng', 'Ghi chú', 'Tháng'
    ];
    
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = headers[i];
    }
    
    int row = 1;
    int stt = 1;
    
    for (String contractId in contractIds) {
      try {
        List<LinkMayMocModel> records = await dbHelper.getLinkMayMocsByContract(contractId);
        
        for (var record in records) {
          List<dynamic> data = [
            stt++,
            record.uid ?? '',
            record.maKinhDoanh ?? '',
            record.loaiMay ?? '',
            record.tenMay ?? '',
            record.hangSanXuat ?? '',
            record.tanSuat ?? '',
            _safeToDouble(record.donGiaMay),
            record.tinhTrangThietBi ?? '',
            record.khauHao ?? '',
            _safeToDouble(record.thanhTienMay),
            record.soLuongCap ?? '',
            _safeToDouble(record.thanhTienThang),
            record.ghiChu ?? '',
            _formatDate(record.thang),
          ];
          
          for (int j = 0; j < data.length; j++) {
            var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row));
            cell.value = data[j];
          }
          row++;
        }
      } catch (e) {
        print('Error loading MayMoc for contract $contractId: $e');
      }
    }
  }
  
  Future<void> _createLuongSheet(Excel excel, List<String> contractIds, DBHelper dbHelper) async {
    var sheet = excel['Lương'];
    
    // Headers
    List<String> headers = [
      'STT', 'UID', 'Mã KD', 'Hạng mục', 'Mô tả', 'Số lượng', 
      'Đơn giá', 'Thành tiền', 'Tháng'
    ];
    
    for (int i = 0; i < headers.length; i++) {
     var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
     cell.value = headers[i];
   }
   
   int row = 1;
   int stt = 1;
   
   for (String contractId in contractIds) {
     try {
       List<LinkLuongModel> records = await dbHelper.getLinkLuongsByContract(contractId);
       
       for (var record in records) {
         List<dynamic> data = [
           stt++,
           record.uid ?? '',
           record.maKinhDoanh ?? '',
           record.hangMuc ?? '',
           record.moTa ?? '',
           record.soLuong ?? 0,
           _safeToDouble(record.donGia),
           _safeToDouble(record.thanhTien),
           _formatDate(record.thang),
         ];
         
         for (int j = 0; j < data.length; j++) {
           var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row));
           cell.value = data[j];
         }
         row++;
       }
     } catch (e) {
       print('Error loading Luong for contract $contractId: $e');
     }
   }
 }
 
 // Utility methods
 double _safeToDouble(dynamic value) {
   if (value == null) return 0.0;
   if (value is double) return value;
   if (value is int) return value.toDouble();
   if (value is num) return value.toDouble();
   if (value is String) {
     return double.tryParse(value) ?? 0.0;
   }
   return 0.0;
 }
 
 String _formatPeriod(String period) {
   try {
     if (period.contains('-') && period.length >= 7) {
       List<String> parts = period.split('-');
       if (parts.length >= 2) {
         String year = parts[0];
         String month = parts[1];
         return '$month/$year';
       }
     }
     
     DateTime date = DateTime.parse('$period-01');
     return DateFormat('MM/yyyy').format(date);
   } catch (e) {
     return period;
   }
 }
 
 String _formatPeriodForFile(String period) {
   return period.replaceAll('-', '_').replaceAll('/', '_');
 }
 
 String _formatDate(String? dateString) {
   if (dateString == null || dateString.isEmpty) return '';
   
   try {
     DateTime date = DateTime.parse(dateString);
     return DateFormat('dd/MM/yyyy').format(date);
   } catch (e) {
     return dateString;
   }
 }
}