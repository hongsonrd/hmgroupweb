import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'table_models.dart';
import 'db_helper.dart';

class DeliveryRequestFormGenerator {
  static Future<void> generateDeliveryRequestForm({
  required BuildContext context,
  required DonHangModel order,
  required List<ChiTietDonModel> items,
  required String createdBy,
  String? warehouseId,
  String? warehouseName,
}) async {
  try {
    final pdf = pw.Document();
    
    final fontData = await rootBundle.load("assets/fonts/RobotoCondensed-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    
    final now = DateTime.now();
    final formatter = DateFormat('dd/MM/yyyy');
    final formattedDate = formatter.format(now);
    
    pw.MemoryImage? logoImage;
    pw.MemoryImage? watermarkImage;
    try {
      final logoData = await rootBundle.load('assets/hotellogo2.png');
      logoImage = pw.MemoryImage(
        logoData.buffer.asUint8List(),
      );
      
      try {
        final watermarkData = await rootBundle.load('assets/hotellogo.png');
        watermarkImage = pw.MemoryImage(
          watermarkData.buffer.asUint8List(),
        );
      } catch (e) {
        watermarkImage = logoImage;
        print('Watermark logo not found, using regular logo: $e');
      }
    } catch (e) {
      print('Logo not found: $e');
    }
    
    final qrImage = await _generateQRCodeImage(order.soPhieu ?? 'unknown');
    final qrImagePdf = qrImage != null ? pw.MemoryImage(qrImage) : null;
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 28,
          marginRight: 28,
          marginTop: 28,
          marginBottom: 28
        ),
        header: (pw.Context context) {
          if (context.pageNumber > 1) {
            return pw.Container(
              margin: pw.EdgeInsets.only(bottom: 10),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Phiếu yêu cầu giao hàng thương mại - Trang ${context.pageNumber}',
                    style: pw.TextStyle(font: ttf, fontSize: 8),
                  ),
                  pw.Text(
                    'Số phiếu: ${order.soPhieu}',
                    style: pw.TextStyle(font: ttf, fontSize: 8),
                  ),
                ],
              ),
            );
          } else {
            return pw.Container();
          }
        },
        footer: (pw.Context context) {
          if (context.pageNumber < context.pagesCount) {
            return pw.Container(
              margin: pw.EdgeInsets.only(top: 10),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Trang ${context.pageNumber}/${context.pagesCount}',
                style: pw.TextStyle(font: ttf, fontSize: 8),
              ),
            );
          } else {
            return pw.Container();
          }
        },
        build: (pw.Context context) {
          return [
            pw.Stack(
              children: [
                if (watermarkImage != null)
                  pw.Positioned.fill(
                    child: pw.Center(
                      child: pw.Opacity(
                        opacity: 0.05,
                        child: pw.Image(
                          watermarkImage,
                          width: 200,
                          height: 200,
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        logoImage != null ? 
                          pw.Container(
                            width: 60,
                            height: 60,
                            child: pw.Image(logoImage)
                          ) : pw.SizedBox(width: 60),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'CÔNG TY TNHH CUNG ỨNG TBKS HOÀN MỸ',
                                style: pw.TextStyle(
                                  font: ttf,
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                'Địa chỉ: Tầng 6,Tòa nhà 25T2, Nguyễn Thị Thập, Cầu Giấy, Hà Nội',
                                style: pw.TextStyle(font: ttf, fontSize: 8),
                              ),
                              pw.Text(
                                'ĐT: 024.37831480 – Fax: 024.37831484',
                                style: pw.TextStyle(font: ttf, fontSize: 8),
                              ),
                            ],
                          ),
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Row(
                              children: [
                                pw.Text(
                                  'Số phiếu: ',
                                  style: pw.TextStyle(font: ttf, fontSize: 9),
                                ),
                                pw.Text(
                                  order.soPhieu ?? 'N/A',
                                  style: pw.TextStyle(font: ttf, fontSize: 9),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 3),
                            pw.Row(
                              children: [
                                pw.Text(
                                  'Ngày: ',
                                  style: pw.TextStyle(font: ttf, fontSize: 9),
                                ),
                                pw.Text(
                                  order.ngay ?? formattedDate,
                                  style: pw.TextStyle(font: ttf, fontSize: 9),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    pw.SizedBox(height: 10),
                    
                    pw.Center(
                      child: pw.Text(
                        'PHIẾU YÊU CẦU GIAO HÀNG THƯƠNG MẠI',
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    pw.SizedBox(height: 8),
                    
                    pw.Table(
                      border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
                      columnWidths: {
                        0: pw.FixedColumnWidth(120),
                        1: pw.FlexColumnWidth(3),
                        2: pw.FixedColumnWidth(100),
                        3: pw.FlexColumnWidth(2),
                      },
                      children: [
                        pw.TableRow(
                          children: [
                            _buildTableCell('Tên khách hàng:', ttf, align: pw.TextAlign.right),
                            _buildTableCell(order.tenKhachHang2 ?? order.tenKhachHang ?? 'N/A', ttf),
                            _buildTableCell('SĐT:', ttf, align: pw.TextAlign.right),
                            _buildTableCell(order.sdtNguoiGiaoDich ?? 'N/A', ttf),
                          ],
                        ),
                        
                        pw.TableRow(
                          children: [
                            _buildTableCell('MST:', ttf, align: pw.TextAlign.right),
                            _buildTableCell(order.mst ?? 'N/A', ttf),
                            _buildTableCell('Số PO:', ttf, align: pw.TextAlign.right),
                            _buildTableCell(order.soPO ?? 'N/A', ttf),
                          ],
                        ),
                        
                        pw.TableRow(
                          children: [
                            _buildTableCell('Địa chỉ:', ttf, align: pw.TextAlign.right),
                            _buildTableCell(order.diaChi ?? 'N/A', ttf, colspan: 3),
                          ],
                        ),
                        
                        pw.TableRow(
                          children: [
                            _buildTableCell('Tập khách hàng:', ttf, align: pw.TextAlign.right),
                            _buildTableCell(order.tapKH ?? 'N/A', ttf),
                            _buildTableCell('Bộ phận GD:', ttf, align: pw.TextAlign.right),
                            _buildTableCell(order.boPhanGiaoDich ?? 'N/A', ttf),
                          ],
                        ),
                        
                        pw.TableRow(
                          children: [
                            _buildTableCell('Người giao dịch:', ttf, align: pw.TextAlign.right),
                            _buildTableCell(order.tenNguoiGiaoDich ?? 'N/A', ttf),
                            _buildTableCell('SĐT người GD:', ttf, align: pw.TextAlign.right),
                            _buildTableCell(order.sdtNguoiNhanHang ?? 'N/A', ttf),
                          ],
                        ),
                        
                        pw.TableRow(
                          children: [
                            _buildTableCell('Phương thức thanh toán:', ttf, align: pw.TextAlign.right),
                            _buildTableCell(order.phuongThucThanhToan ?? 'N/A', ttf, colspan: 3),
                          ],
                        ),
                        
                        pw.TableRow(
                          children: [
                            _buildTableCell('Sau nhận hàng, sẽ thanh toán sau:', ttf, align: pw.TextAlign.right),
                            pw.Padding(
                              padding: pw.EdgeInsets.all(3),
                              child: pw.Row(
                                children: [
                                  pw.Text(
                                    order.thanhToanSauNhanHangXNgay?.toString() ?? 'N/A',
                                    style: pw.TextStyle(font: ttf, fontSize: 8),
                                  ),
                                  pw.SizedBox(width: 5),
                                  pw.Text(
                                    'ngày',
                                    style: pw.TextStyle(font: ttf, fontSize: 8),
                                  ),
                                ],
                              ),
                            ),
                            pw.Container(),
                            pw.Container(),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 8),
            
            pw.Table(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
              columnWidths: {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(1),
                3: pw.FlexColumnWidth(1.5),
                4: pw.FlexColumnWidth(1.5),
                5: pw.FlexColumnWidth(1.5),
                6: pw.FlexColumnWidth(1),
                7: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  repeat: true,
                  children: [
                    _buildTableCell('Tên hàng', ttf, isBold: true),
                    _buildTableCell('Mã hàng', ttf, isBold: true),
                    _buildTableCell('ĐVT', ttf, isBold: true),
                    _buildTableCell('Số lượng', ttf, isBold: true),
                    _buildTableCell('Số lượng thực giao', ttf, isBold: true),
                    _buildTableCell('Đơn giá', ttf, isBold: true),
                    _buildTableCell('%VAT', ttf, isBold: true),
                    _buildTableCell('Thành tiền', ttf, isBold: true),
                  ],
                ),
                
                ...items.map((item) => pw.TableRow(
                  children: [
                    _buildTableCell(item.idHang ?? 'N/A', ttf, textColor: PdfColors.red),
                    _buildTableCell(item.maHang ?? 'N/A', ttf),
                    _buildTableCell(item.donViTinh ?? 'N/A', ttf),
                    _buildTableCell(item.soLuongYeuCau?.toString() ?? '0', ttf, align: pw.TextAlign.right),
                    _buildTableCell(item.soLuongThucGiao?.toString() ?? '0', ttf, align: pw.TextAlign.right),
                    _buildTableCell(_formatCurrency(item.donGia), ttf, align: pw.TextAlign.right),
                    _buildTableCell(item.phanTramVAT?.toString() ?? '10%', ttf, align: pw.TextAlign.center),
                    _buildTableCell(_formatCurrency(item.thanhTien), ttf, align: pw.TextAlign.right, textColor: PdfColors.red),
                  ],
                )).toList(),
              ],
            ),
            
            pw.SizedBox(height: 8),
            
            pw.Table(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
              columnWidths: {
                0: pw.FlexColumnWidth(5),
                1: pw.FlexColumnWidth(2),
              },
              children: [
                _buildTotalRow('TỔNG', _formatCurrency(order.tongTien), ttf),
                _buildTotalRow('Tổng VAT các mặt hàng chịu VAT 8%', _formatVAT(items, 8), ttf),
                _buildTotalRow('Tổng VAT các mặt hàng chịu VAT 10%', _formatVAT(items, 10), ttf),
                _buildTotalRow('TỔNG VAT', _formatCurrency(order.vat10), ttf),
                _buildTotalRow('TỔNG CỘNG', _formatCurrency(order.tongCong), ttf, isBold: true),
                _buildTotalRow('HOA HỒNG 10%', _formatCurrency(order.hoaHong10), ttf),
                _buildTotalRow('TIỀN GỬI 10%', _formatCurrency(order.tienGui10), ttf),
                _buildTotalRow('THUẾ TNDN 10%', _formatCurrency(order.thueTNDN), ttf),
                _buildTotalRow('VẬN CHUYỂN', _formatCurrency(order.vanChuyen), ttf),
                _buildTotalRow('THỰC THU', _formatCurrency(order.thucThu), ttf, isBold: true),
              ],
            ),
            
            pw.SizedBox(height: 8),
            
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5, color: PdfColors.grey),
              ),
              padding: pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Thông tin khác:',
                    style: pw.TextStyle(font: ttf, fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 3),
                  
                  _buildInfoRow('Các giấy tờ cần khi giao hàng:', order.giayToCanKhiGiaoHang ?? 'N/A', ttf),
                  _buildInfoRow('Thông tin viết hóa đơn (nếu có):', order.thongTinVietHoaDon ?? 'N/A', ttf),
                  _buildInfoRow('Địa chỉ giao hàng:', 
                    '${order.diaChiGiaoHang ?? 'N/A'} / ${order.nguoiNhanHang ?? 'N/A'} / ${order.sdtNguoiNhanHang ?? 'N/A'}', ttf),
                  _buildInfoRow('Họ tên người nhận hoa hồng:', order.hoTenNguoiNhanHoaHong ?? 'N/A', ttf, 
                    extraLabel: 'SĐT người nhận hoa hồng:', extraValue: order.sdtNguoiNhanHoaHong ?? 'N/A'),
                  _buildInfoRow('Hình thức chuyển hoa hồng:', order.hinhThucChuyenHoaHong ?? 'N/A', ttf, 
                    extraLabel: 'Tài khoản nhận:', extraValue: order.thongTinNhanHoaHong ?? 'N/A'),
                  _buildInfoRow('Phương tiện giao hàng:', order.phuongTienGiaoHang ?? 'N/A', ttf),
                  _buildInfoRow('Ghi chú:', order.ghiChu ?? '', ttf),
                ],
              ),
            ),
            
            pw.SizedBox(height: 10),
            
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                qrImagePdf != null ? 
                  pw.Container(
                    width: 80,
                    child: pw.Column(
                      children: [
                        pw.Image(qrImagePdf, width: 60, height: 60),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Mã đơn: ${order.soPhieu}',
                          style: pw.TextStyle(font: ttf, fontSize: 7),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ) : pw.SizedBox(width: 0),
                
                pw.Expanded(
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSignatureBox('TP Kế toán', ttf, 
                        signatureName: _getSignatureByLocation(order.thoiGianDatHang, "SG", "Đàm Phương Linh", "Lưu Văn Kính"),
                        smallerSize: true),
                      _buildSignatureBox('TP Xác nhận', ttf, 
                        signatureName: _getSignatureByLocation(order.thoiGianDatHang, "SG", "Đàm Phương Linh", "Trần Xuân Giang"),
                        smallerSize: true),
                      _buildSignatureBox('NV Tổng hợp', ttf, smallerSize: true),
                      _buildSignatureBox('NVKD Yêu cầu', ttf, signatureName: order.nguoiTao, smallerSize: true),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );
    
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/PYC_${order.soPhieu}.pdf');
    await file.writeAsBytes(await pdf.save());
    
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'PYC_${order.soPhieu}.pdf',
    );
    
    _showPrintOptionsDialog(context, file, order.soPhieu ?? 'unknown');
    
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi khi tạo phiếu yêu cầu giao hàng: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
    print('Error generating delivery request form: $e');
  }
}
  
  // QR code generation with qr_flutter
  static Future<Uint8List?> _generateQRCodeImage(String data) async {
    try {
      final qrPainter = QrPainter(
        data: data,
        version: QrVersions.auto,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
        gapless: true,
      );
      
      final imageSize = 200.0;
      
      final qrImage = await qrPainter.toImageData(
        imageSize,
        format: ui.ImageByteFormat.png,
      );
      
      return qrImage?.buffer.asUint8List();
    } catch (e) {
      print('Error generating QR code: $e');
      return null;
    }
  }
  
  static Future<void> _showPrintOptionsDialog(BuildContext context, File pdfFile, String orderNumber) async {
    final isProbablyMobile = MediaQuery.of(context).size.width < 600;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Phiếu yêu cầu giao hàng'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Bạn muốn làm gì với phiếu yêu cầu giao hàng?'),
              
              // Add printing instructions for mobile users
              if (isProbablyMobile) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lưu ý khi in từ thiết bị di động:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700]),
                      ),
                      SizedBox(height: 8),
                      Text('• Vui lòng bỏ chọn "Vừa với trang"'),
                      Text('• Tỷ lệ in: chọn "100%"'),
                      Text('• Chọn kích thước giấy "A4" hoặc "Letter"'),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Đóng'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                // Print with specific settings for better sizing
                await Printing.layoutPdf(
                  onLayout: (PdfPageFormat format) async => pdfFile.readAsBytes(),
                  name: 'PYC_$orderNumber.pdf',
                  format: PdfPageFormat.a4.copyWith(
                    marginLeft: 0,
                    marginRight: 0,
                    marginTop: 0,
                    marginBottom: 0,
                  ),
                );
              },
              icon: Icon(Icons.print),
              label: Text('In lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                // Share the file
                await Share.shareFiles(
                  [pdfFile.path],
                  mimeTypes: ['application/pdf'],
                  subject: 'Phiếu yêu cầu giao hàng $orderNumber',
                  text: 'Phiếu yêu cầu giao hàng mã: $orderNumber',
                );
              },
              icon: Icon(Icons.share),
              label: Text('Chia sẻ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
  
  static pw.Widget _buildTableCell(
  String text, 
  pw.Font font, {
  bool isBold = false,
  pw.TextAlign align = pw.TextAlign.left,
  PdfColor textColor = PdfColors.black,
  int colspan = 1,
}) {
  return pw.Padding(
    padding: pw.EdgeInsets.all(3), // Smaller padding
    child: pw.Text(
      text,
      style: pw.TextStyle(
        font: font,
        fontSize: 8, // Smaller font
        fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: textColor,
      ),
      textAlign: align,
    ),
  );
}

static pw.TableRow _buildTotalRow(
  String label,
  String value,
  pw.Font font,
  {bool isBold = false}
) {
  return pw.TableRow(
    children: [
      pw.Padding(
        padding: pw.EdgeInsets.all(3), // Smaller padding
        child: pw.Text(
          label,
          style: pw.TextStyle(
            font: font,
            fontSize: 8, // Smaller font
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
      pw.Padding(
        padding: pw.EdgeInsets.all(3), // Smaller padding
        child: pw.Text(
          value,
          style: pw.TextStyle(
            font: font,
            fontSize: 8, // Smaller font
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
          textAlign: pw.TextAlign.right,
        ),
      ),
    ],
  );
}

static pw.Widget _buildInfoRow(
  String label,
  String value,
  pw.Font font,
  {String? extraLabel, 
  String? extraValue}
) {
  if (extraLabel != null && extraValue != null) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 1), // Smaller padding
      child: pw.Row(
        children: [
          pw.Container(
            width: 130, // Slightly narrower
            child: pw.Text(
              label,
              style: pw.TextStyle(font: font, fontSize: 8), // Smaller font
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              value,
              style: pw.TextStyle(font: font, fontSize: 8), // Smaller font
            ),
          ),
          pw.Container(
            width: 130, // Slightly narrower
            child: pw.Text(
              extraLabel,
              style: pw.TextStyle(font: font, fontSize: 8), // Smaller font
            ),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Text(
              extraValue,
              style: pw.TextStyle(font: font, fontSize: 8), // Smaller font
            ),
          ),
        ],
      ),
    );
  } else {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 1), // Smaller padding
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 130, // Slightly narrower
            child: pw.Text(
              label,
              style: pw.TextStyle(font: font, fontSize: 8), // Smaller font
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: font, fontSize: 8), // Smaller font
            ),
          ),
        ],
      ),
    );
  }
}

static pw.Widget _buildSignatureBox(
  String title, 
  pw.Font font,
  {String? signatureName, 
  bool smallerSize = false}
) {
  final fontSize = smallerSize ? 8.0 : 10.0;
  final signatureNameSize = smallerSize ? 7.0 : 9.0;
  final spaceHeight = smallerSize ? 25.0 : 40.0;
  
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(
          font: font,
          fontSize: fontSize,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: spaceHeight),
      pw.SizedBox(height: spaceHeight),
      if (signatureName != null)
        pw.Text(
          signatureName,
          style: pw.TextStyle(
            font: font,
            fontSize: signatureNameSize,
          ),
        ),
    ],
  );
}
  
  static String _getSignatureByLocation(String? location, String compareValue, String ifTrue, String ifFalse) {
    if (location == compareValue) {
      return ifTrue;
    } else {
      return ifFalse;
    }
  }
  
  static String _formatCurrency(int? value) {
    if (value == null) return '0';
    final formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(value);
  }
  
  static String _formatVAT(List<ChiTietDonModel> items, int vatRate) {
  int total = 0;
  
  for (var item in items) {
    if (item.phanTramVAT == vatRate && item.vat != null) {
      // Use the actual VAT value from the item directly
      total += item.vat!;
    }
  }
  
  final formatter = NumberFormat('#,###', 'vi_VN');
  return formatter.format(total);
}
}