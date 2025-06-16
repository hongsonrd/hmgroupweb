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

// Create a helper class for combined items
class CombinedItem {
  final String? idHang;
  final String? tenHang;
  final String? donViTinh;
  final double? soLuongYeuCau; // Changed to double to match your model
  final int? donGia;
  final int? thanhTien;
  final int? phanTramVAT;
  final String noteText;

  CombinedItem({
    this.idHang,
    this.tenHang,
    this.donViTinh,
    this.soLuongYeuCau,
    this.donGia,
    this.thanhTien,
    this.phanTramVAT,
    this.noteText = '',
  });
}

class ExportFormGenerator {
  static Future<void> generateExportForm({
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
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

        try {
          final watermarkData = await rootBundle.load('assets/hotellogo.png');
          watermarkImage = pw.MemoryImage(watermarkData.buffer.asUint8List());
        } catch (e) {
          watermarkImage = logoImage;
          print('Watermark logo not found, using regular logo: $e');
        }
      } catch (e) {
        print('Logo not found: $e');
      }

      final qrImage = await _generateQRCodeImage(order.soPhieu ?? 'unknown');
      final qrImagePdf = qrImage != null ? pw.MemoryImage(qrImage) : null;

      // Combine items with same idHang
      final combinedItems = _combineItems(items);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.copyWith(
            marginLeft: 28,
            marginRight: 28,
            marginTop: 28,
            marginBottom: 28
          ),
          header: (context) => _buildHeader(ttf, logoImage, order, formattedDate),
          footer: (context) => _buildFooter(ttf, context),
          build: (pw.Context context) {
            return [
              if (watermarkImage != null)
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: 0.05,
                      child: pw.Image(
                        watermarkImage,
                        width: 50,
                        height: 50,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
                ),

              pw.SizedBox(height: 15),

              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
                headerStyle: pw.TextStyle(
                  font: ttf,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: pw.TextStyle(font: ttf, fontSize: 9),
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey200),
                cellHeight: 25,
                columnWidths: {
                  0: pw.FlexColumnWidth(2.5),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(1),
                  4: pw.FlexColumnWidth(1.5),
                  5: pw.FlexColumnWidth(1.5),
                  6: pw.FlexColumnWidth(1),
                  7: pw.FlexColumnWidth(2),
                },
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.centerRight,
                  6: pw.Alignment.center,
                  7: pw.Alignment.centerRight,
                },
                headers: [
                  'Product Name',
                  'Note',
                  'Code',
                  'Unit',
                  'Quantity',
                  'Price',
                  '%VAT',
                  'Total'
                ],
                data: combinedItems.map((item) => [
                  (item.idHang == "KHAC")
                      ? (item.tenHang ?? 'N/A')
                      : ((item.idHang != null && item.idHang!.contains(' - '))
                          ? item.idHang!.split(' - ')[1].trim()
                          : (item.idHang ?? 'N/A')),
                  item.noteText, // This will contain the baoGia information
                  (item.idHang == "KHAC")
                      ? (item.tenHang ?? 'N/A')
                      : ((item.idHang != null && item.idHang!.contains(' - '))
                          ? item.idHang!.split(' - ')[0].trim()
                          : (item.idHang ?? 'N/A')),
                  item.donViTinh ?? 'N/A',
                  _formatQuantity(item.soLuongYeuCau), // Format quantity properly
                  _formatCurrency(item.donGia),
                  item.phanTramVAT?.toString() ?? '10%',
                  _formatCurrency(item.thanhTien),
                ]).toList(),
              ),

              pw.SizedBox(height: 10),

              _buildSummarySection(order, ttf),

              pw.SizedBox(height: 20),

              _buildSignatureSection(qrImagePdf, order, ttf),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/PXK_${order.soPhieu}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'PXK_${order.soPhieu}.pdf',
      );

      _showPrintOptionsDialog(context, file, order.soPhieu ?? 'unknown');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tạo phiếu xuất kho: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error generating export form: $e');
    }
  }

  // Updated method to combine items with same idHang
  static List<CombinedItem> _combineItems(List<ChiTietDonModel> items) {
    Map<String, CombinedItem> combinedMap = {};
    Map<String, List<String>> baoGiaInfo = {};

    for (var item in items) {
      String key = item.idHang ?? 'unknown';
      
      if (combinedMap.containsKey(key)) {
        // Get existing combined item
        CombinedItem existing = combinedMap[key]!;
        
        // Create new combined item with updated values
        combinedMap[key] = CombinedItem(
          idHang: existing.idHang,
          tenHang: existing.tenHang,
          donViTinh: existing.donViTinh,
          soLuongYeuCau: (existing.soLuongYeuCau ?? 0.0) + (item.soLuongYeuCau ?? 0.0),
          donGia: existing.donGia, // Keep the first price found
          thanhTien: (existing.thanhTien ?? 0) + (item.thanhTien ?? 0),
          phanTramVAT: existing.phanTramVAT,
          noteText: existing.noteText,
        );
        
        // Collect baoGia information
        if (item.baoGia != null && item.baoGia!.isNotEmpty) {
          String baoGiaEntry = '${item.baoGia}: ${_formatQuantity(item.soLuongYeuCau)}';
          baoGiaInfo[key]!.add(baoGiaEntry);
        }
      } else {
        // Create new entry
        combinedMap[key] = CombinedItem(
          idHang: item.idHang,
          tenHang: item.tenHang,
          donViTinh: item.donViTinh,
          soLuongYeuCau: item.soLuongYeuCau,
          donGia: item.donGia,
          thanhTien: item.thanhTien,
          phanTramVAT: item.phanTramVAT,
        );
        
        // Initialize baoGia info list
        baoGiaInfo[key] = [];
        if (item.baoGia != null && item.baoGia!.isNotEmpty) {
          String baoGiaEntry = '${item.baoGia}: ${_formatQuantity(item.soLuongYeuCau)}';
          baoGiaInfo[key]!.add(baoGiaEntry);
        }
      }
    }

    // Update combined items with note text containing baoGia information
    List<CombinedItem> result = [];
    combinedMap.forEach((key, item) {
      String noteText = '';
      if (baoGiaInfo[key]!.isNotEmpty) {
        noteText = baoGiaInfo[key]!.join(', ');
      }
      
      result.add(CombinedItem(
        idHang: item.idHang,
        tenHang: item.tenHang,
        donViTinh: item.donViTinh,
        soLuongYeuCau: item.soLuongYeuCau,
        donGia: item.donGia,
        thanhTien: item.thanhTien,
        phanTramVAT: item.phanTramVAT,
        noteText: noteText,
      ));
    });

    return result;
  }

  // Add helper method to format quantity
  static String _formatQuantity(double? value) {
    if (value == null) return '0';
    // If it's a whole number, display without decimal places
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    // Otherwise, display with appropriate decimal places
    return value.toString();
  }

  static pw.Widget _buildHeader(pw.Font ttf, pw.MemoryImage? logoImage, DonHangModel order, String formattedDate) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            logoImage != null ?
              pw.Container(
                width: 70,
                height: 70,
                child: pw.Image(logoImage)
              ) : pw.SizedBox(width: 70),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CÔNG TY TNHH CUNG ỨNG TBKS HOÀN MỸ',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Địa chỉ: Tầng 6,Tòa nhà 25T2, Nguyễn Thị Thập, Cầu Giấy, Hà Nội',
                    style: pw.TextStyle(font: ttf, fontSize: 9),
                  ),
                  pw.Text(
                    'ĐT: 024.37831480 – Fax: 024.37831484',
                    style: pw.TextStyle(font: ttf, fontSize: 9),
                  ),
                  pw.Text(
                    'Website: http://hoanmyhotelsupply.com/',
                    style: pw.TextStyle(font: ttf, fontSize: 9),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MST: 0102630297',
                  style: pw.TextStyle(font: ttf, fontSize: 9),
                ),
                pw.Text(
                  'Email: info@hoanmyhotelsupply.com',
                  style: pw.TextStyle(font: ttf, fontSize: 9),
                ),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 20),

        pw.Center(
          child: pw.Text(
            'PURCHASE ORDER',
            style: pw.TextStyle(
              font: ttf,
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),

        pw.SizedBox(height: 5),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Kind attention: ...........', 
              style: pw.TextStyle(font: ttf, fontSize: 10),
            ),
            pw.Row(
              children: [
                pw.Text(
                  'Purchase Order#: ',
                  style: pw.TextStyle(font: ttf, fontSize: 10),
                ),
                pw.Text(
                  order.soPhieu ?? 'N/A',
                  style: pw.TextStyle(font: ttf, fontSize: 10),
                ),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 5),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'Date (YYYY-MM-DD): ',
              style: pw.TextStyle(font: ttf, fontSize: 10),
            ),
            pw.Text(
              order.ngay ?? formattedDate,
              style: pw.TextStyle(font: ttf, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Font ttf, pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: pw.TextStyle(font: ttf, fontSize: 8),
      ),
    );
  }

  static pw.Widget _buildSummarySection(DonHangModel order, pw.Font ttf) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TỔNG',
                style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                _formatCurrency(order.tongTien),
                style: pw.TextStyle(font: ttf, fontSize: 10),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TỔNG VAT',
                style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                _formatCurrency(order.vat10),
                style: pw.TextStyle(font: ttf, fontSize: 10),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TỔNG CỘNG',
                style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                _formatCurrency(order.tongCong),
                style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatureSection(pw.MemoryImage? qrImagePdf, DonHangModel order, pw.Font ttf) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        qrImagePdf != null ?
          pw.Container(
            width: 100,
            child: pw.Column(
              children: [
                pw.Image(qrImagePdf, width: 80, height: 80),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Mã đơn: ${order.soPhieu}',
                  style: pw.TextStyle(font: ttf, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ) : pw.SizedBox(width: 100),

        pw.Expanded(
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              _buildSignatureBox('Purchase Staff', ttf, nvkd: order.nguoiTao),
              _buildSignatureBox('Purchase Manager', ttf, nvkd: order.nguoiTao),
            ],
          ),
        ),
      ],
    );
  }

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
          title: Text('Phiếu xuất kho'), 
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Bạn muốn làm gì với phiếu xuất kho?'), 

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
                await Printing.layoutPdf(
                  onLayout: (PdfPageFormat format) async => pdfFile.readAsBytes(),
                  name: 'PXK_$orderNumber.pdf',
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
                await Share.shareFiles(
                  [pdfFile.path],
                  mimeTypes: ['application/pdf'],
                  subject: 'Phiếu xuất kho $orderNumber',
                  text: 'Phiếu xuất kho mã: $orderNumber',
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

  static pw.Widget _buildSignatureBox(String title, pw.Font font, {String? nvkd}) {
    final List<String> validNVKD = [
      'hm.trangiang', 'hm.tranly', 'hm.dinhmai', 'hm.hoangthao', 'hm.vutoan',
      'hm.lehoa', 'hm.lemanh', 'hm.nguyentoan', 'hm.nguyennga', 'hm.conghai',
      'hm.thuytrang', 'hm.nguyenvy', 'hm.phiminh', 'hm.doanly'
    ];

    String name = '';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          '(ký, ghi rõ họ tên)',
          style: pw.TextStyle(
            font: font,
            fontSize: 8,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
        pw.SizedBox(height: 55),
        if (name.isNotEmpty)
          pw.Text(
            name,
            style: pw.TextStyle(
              font: font,
              fontSize: 9,
            ),
          ),
      ],
    );
  }

  static String _formatCurrency(int? value) {
    if (value == null) return '0';
    final formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(value);
  }
}