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

class ExportFormGenerator {
  static const double _pageMargin = 28.0;
  static const double _tableRowHeight = 25.0;
  static const double _tableHeaderHeight = 30.0;
  
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
      
      final pageHeight = PdfPageFormat.a4.height - (2 * _pageMargin);
      final headerHeight = _calculateHeaderHeight();
      final footerHeight = _calculateFooterHeight();
      final continuationHeaderHeight = 60.0;
      
      List<List<ChiTietDonModel>> pageItems = _distributeItemsAcrossPages(
        items, 
        pageHeight, 
        headerHeight, 
        footerHeight, 
        continuationHeaderHeight
      );
      
      for (int pageIndex = 0; pageIndex < pageItems.length; pageIndex++) {
        final isFirstPage = pageIndex == 0;
        final isLastPage = pageIndex == pageItems.length - 1;
        
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.copyWith(
              marginLeft: _pageMargin,
              marginRight: _pageMargin,
              marginTop: _pageMargin,
              marginBottom: _pageMargin
            ),
            build: (pw.Context context) {
              return _buildPageContent(
                order: order,
                items: pageItems[pageIndex],
                allItems: items,
                ttf: ttf,
                logoImage: logoImage,
                watermarkImage: watermarkImage,
                qrImagePdf: qrImagePdf,
                formattedDate: formattedDate,
                isFirstPage: isFirstPage,
                isLastPage: isLastPage,
                currentPage: pageIndex + 1,
                totalPages: pageItems.length,
              );
            },
          ),
        );
      }
      
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
  
  static List<List<ChiTietDonModel>> _distributeItemsAcrossPages(
    List<ChiTietDonModel> items,
    double pageHeight,
    double headerHeight,
    double footerHeight,
    double continuationHeaderHeight,
  ) {
    List<List<ChiTietDonModel>> pages = [];
    int currentIndex = 0;
    
    while (currentIndex < items.length) {
      bool isFirstPage = pages.isEmpty;
      double availableHeight = pageHeight;
      
      if (isFirstPage) {
        availableHeight -= headerHeight;
      } else {
        availableHeight -= continuationHeaderHeight;
      }
      
      double tableSpaceWithoutFooter = availableHeight;
      double tableSpaceWithFooter = availableHeight - footerHeight;
      
      double availableTableHeight = tableSpaceWithoutFooter - _tableHeaderHeight;
      int maxItemsWithoutFooter = (availableTableHeight / _tableRowHeight).floor();
      
      availableTableHeight = tableSpaceWithFooter - _tableHeaderHeight;
      int maxItemsWithFooter = (availableTableHeight / _tableRowHeight).floor();
      
      int remainingItems = items.length - currentIndex;
      int itemsForThisPage;
      
      if (remainingItems <= maxItemsWithFooter) {
        itemsForThisPage = remainingItems;
      } else if (remainingItems <= maxItemsWithoutFooter) {
        itemsForThisPage = maxItemsWithoutFooter - 3;
      } else {
        itemsForThisPage = maxItemsWithoutFooter;
      }
      
      itemsForThisPage = itemsForThisPage.clamp(1, remainingItems);
      
      int endIndex = currentIndex + itemsForThisPage;
      pages.add(items.sublist(currentIndex, endIndex));
      currentIndex = endIndex;
    }
    
    return pages;
  }
  
  static double _calculateHeaderHeight() {
    return 285.0;
  }
  
  static double _calculateFooterHeight() {
    return 160.0;
  }
  
  static pw.Widget _buildPageContent({
    required DonHangModel order,
    required List<ChiTietDonModel> items,
    required List<ChiTietDonModel> allItems,
    required pw.Font ttf,
    required pw.MemoryImage? logoImage,
    required pw.MemoryImage? watermarkImage,
    required pw.MemoryImage? qrImagePdf,
    required String formattedDate,
    required bool isFirstPage,
    required bool isLastPage,
    required int currentPage,
    required int totalPages,
  }) {
    return pw.Stack(
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
            if (isFirstPage) _buildHeader(order, ttf, logoImage, formattedDate),
            
            if (!isFirstPage) ...[
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'PHIẾU GIAO HÀNG (KIÊM PHIẾU XUẤT KHO) - Tiếp theo',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Số phiếu: ${order.soPhieu ?? 'N/A'}',
                    style: pw.TextStyle(font: ttf, fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
            ],
            
            if (totalPages > 1) ...[
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Trang $currentPage/$totalPages',
                  style: pw.TextStyle(font: ttf, fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 10),
            ],
            
            _buildItemsTable(items, ttf, true),
            
            if (!isLastPage) pw.Spacer(),
            
            if (isLastPage) ...[
              pw.SizedBox(height: 10),
              _buildFooter(order, ttf, qrImagePdf),
            ],
          ],
        ),
      ],
    );
  }
  
  static pw.Widget _buildHeader(DonHangModel order, pw.Font ttf, pw.MemoryImage? logoImage, String formattedDate) {
    return pw.Column(
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
            'PHIẾU GIAO HÀNG (KIÊM PHIẾU XUẤT KHO)',
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
              'Liên 2: Giao khách hàng',
              style: pw.TextStyle(font: ttf, fontSize: 10),
            ),
            pw.Row(
              children: [
                pw.Text(
                  'Số phiếu: ',
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
              'Ngày: ',
              style: pw.TextStyle(font: ttf, fontSize: 10),
            ),
            pw.Text(
              order.ngay ?? formattedDate,
              style: pw.TextStyle(font: ttf, fontSize: 10),
            ),
          ],
        ),
        
        pw.SizedBox(height: 10),
        
        pw.Table(
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
          columnWidths: {
            0: pw.FixedColumnWidth(100),
            1: pw.FixedColumnWidth(200),
            2: pw.FixedColumnWidth(100),
            3: pw.FixedColumnWidth(100),
          },
          children: [
            pw.TableRow(
              children: [
                _buildTableCell('Tên khách hàng:', ttf, align: pw.TextAlign.right),
                _buildTableCell(order.tenKhachHang2 ?? order.tenKhachHang ?? 'N/A', ttf),
                _buildTableCell('Người liên hệ:', ttf, align: pw.TextAlign.right),
                _buildTableCell(order.nguoiNhanHang ?? 'N/A', ttf),
              ],
            ),
            pw.TableRow(
              children: [
                _buildTableCell('Địa chỉ giao hàng:', ttf, align: pw.TextAlign.right),
                _buildTableCell(order.diaChiGiaoHang ?? order.diaChi ?? 'N/A', ttf),
                _buildTableCell('SĐT:', ttf, align: pw.TextAlign.right),
                _buildTableCell(order.sdtNguoiNhanHang ?? 'N/A', ttf),
              ],
            ),
            pw.TableRow(
              children: [
                _buildTableCell('MST:', ttf, align: pw.TextAlign.right),
                _buildTableCell(order.mst ?? 'N/A', ttf),
                _buildTableCell('Bộ phận:', ttf, align: pw.TextAlign.right),
                _buildTableCell(order.boPhanGiaoDich ?? 'N/A', ttf),
              ],
            ),
            pw.TableRow(
              children: [
                _buildTableCell('Điện thoại:', ttf, align: pw.TextAlign.right),
                _buildTableCell(order.sdtKhachHang ?? 'N/A', ttf),
                _buildTableCell('Theo PO:', ttf, align: pw.TextAlign.right),
                _buildTableCell(order.soPO ?? 'N/A', ttf),
              ],
            ),
            pw.TableRow(
              children: [
                _buildTableCell('Phương thức thanh toán:', ttf, align: pw.TextAlign.right),
                _buildTableCell(order.phuongThucThanhToan ?? 'Tiền mặt', ttf),
                _buildTableCell('NVKD:', ttf, align: pw.TextAlign.right),
                _buildTableCell(order.nguoiTao ?? 'N/A', ttf),
              ],
            ),
          ],
        ),
        
        pw.SizedBox(height: 15),
      ],
    );
  }
  
  static pw.Widget _buildItemsTable(List<ChiTietDonModel> items, pw.Font ttf, bool showHeader) {
    return pw.Table(
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
          children: [
            _buildTableCell('Tên hàng', ttf, isBold: true),
            _buildTableCell('Mã hàng', ttf, isBold: true),
            _buildTableCell('ĐVT', ttf, isBold: true),
            _buildTableCell('SL yêu cầu', ttf, isBold: true),
            _buildTableCell('SL thực giao', ttf, isBold: true),
            _buildTableCell('Đơn giá', ttf, isBold: true),
            _buildTableCell('%VAT', ttf, isBold: true),
            _buildTableCell('Thành tiền', ttf, isBold: true),
          ],
        ),
        
        ...items.map((item) {
          String slThucGiaoDisplay = (item.soLuongThucGiao == null || item.soLuongThucGiao == 0)
              ? ''
              : item.soLuongThucGiao!.toString();

          return pw.TableRow(
            children: [
              _buildTableCell(
                (item.tenHang != null && item.tenHang!.trim().isNotEmpty)
                    ? item.tenHang!
                    : ((item.idHang == "KHAC") 
                        ? 'N/A'
                        : ((item.idHang != null && item.idHang!.contains(' - ')) 
                            ? (() {
                                String str = item.idHang!;
                                int firstDash = str.indexOf(' - ');
                                int secondDash = str.indexOf(' - ', firstDash + 1);
                                
                                if (secondDash != -1) {
                                  return str.substring(secondDash + 3).trim();
                                } else {
                                  return str.substring(firstDash + 3).trim();
                                }
                              }())
                            : 'N/A')), 
                ttf
              ),
              _buildTableCell(
                (item.maHang != null && item.maHang!.trim().isNotEmpty)
                    ? item.maHang!
                    : ((item.idHang == "KHAC") 
                        ? 'N/A'
                        : ((item.idHang != null && item.idHang!.contains(' - ')) 
                            ? (() {
                                String str = item.idHang!;
                                int firstDash = str.indexOf(' - ');
                                int secondDash = str.indexOf(' - ', firstDash + 1);
                                
                                if (secondDash != -1) {
                                  return str.substring(0, secondDash).trim();
                                } else {
                                  return str.substring(0, firstDash).trim();
                                }
                              }())
                            : 'N/A')), 
                ttf
              ),
              _buildTableCell(item.donViTinh ?? 'N/A', ttf),
              _buildTableCell(item.soLuongYeuCau?.toString() ?? '0', ttf, align: pw.TextAlign.right),
              _buildTableCell(slThucGiaoDisplay, ttf, align: pw.TextAlign.right),
              _buildTableCell(_formatCurrency(item.donGia), ttf, align: pw.TextAlign.right),
              _buildTableCell(item.phanTramVAT?.toString() ?? '10%', ttf, align: pw.TextAlign.center),
              _buildTableCell(_formatCurrency(item.thanhTien), ttf, align: pw.TextAlign.right, textColor: PdfColors.red),
            ],
          );
        }).toList(),
      ],
    );
  }
  
  static pw.Widget _buildFooter(DonHangModel order, pw.Font ttf, pw.MemoryImage? qrImagePdf) {
    return pw.Column(
      children: [
        pw.Container(
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
        ),
        
        pw.SizedBox(height: 20),
        
        pw.Row(
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
              ) : pw.SizedBox(width: 0),
          
            pw.Expanded(
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSignatureBox('Người giao hàng', ttf, nvkd: order.nguoiTao),
                  _buildSignatureBox('Phòng kế toán', ttf, nvkd: order.nguoiTao),
                  _buildSignatureBox('Thủ kho', ttf, nvkd: order.nguoiTao),
                  _buildSignatureBox('Người nhận', ttf, nvkd: order.nguoiTao),
                ],
              ),
            ),
          ],
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
  
  static pw.Widget _buildTableCell(
    String text, 
    pw.Font font, {
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor textColor = PdfColors.black,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor,
        ),
        textAlign: align,
      ),
    );
  }
  
  static pw.Widget _buildSignatureBox(String title, pw.Font font, {String? nvkd}) {
    final List<String> validNVKD = [
      'hm.trangiang',
      'hm.tranly',
      'hm.dinhmai',
      'hm.hoangthao',
      'hm.vutoan',
      'hm.lehoa',
      'hm.lemanh',
      'hm.nguyentoan',
      'hm.nguyennga',
      'hm.conghai',
      'hm.thuytrang',
      'hm.nguyenvy',
      'hm.phiminh',
      'hm.doanly'
    ];
    
    bool isValidNVKD = nvkd != null && validNVKD.contains(nvkd.toLowerCase());
    
    String name = '';
    if (isValidNVKD) {
      if (title == 'Người giao hàng') {
        name = 'Phan Anh Viết';
      } else if (title == 'Phòng kế toán') {
        name = 'Lê Thị Thanh Hoa';
      } else if (title == 'Thủ kho') {
        name = 'Phí Thị Minh';
      }
    }
    
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