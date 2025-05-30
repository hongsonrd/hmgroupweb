import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' as pdfx;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'db_helper.dart';
import 'table_models.dart';

class PTFormGenerator {
 static Future<void> generatePTForm({
   required BuildContext context,
   required List<DonHangModel> orders,
   required String createdBy,
 }) async {
   try {
     final DBHelper dbHelper = DBHelper();
     List<PTFormItem> formItems = [];
     
     final canXuatOrders = orders.where((order) => 
       (order.trangThai?.toLowerCase() ?? '') == 'cần xuất'
     ).toList();
     
     for (var order in canXuatOrders) {
       if (order.soPhieu != null) {
         final items = await dbHelper.getChiTietDonBySoPhieu(order.soPhieu!);
         for (var item in items) {
           formItems.add(PTFormItem(
             idHang: item.idHang ?? '',
             soLuongYeuCau: item.soLuongYeuCau ?? 0.0,
             soLuongThucGiao: item.soLuongThucGiao,
             soPhieu: order.soPhieu ?? '',
             tenKhachHang: order.tenKhachHang2 ?? '',
             nguoiTao: order.nguoiTao ?? '',
           ));
         }
       }
     }
     
     formItems.sort((a, b) {
       int agentComparison = a.nguoiTao.compareTo(b.nguoiTao);
       if (agentComparison != 0) return agentComparison;
       return a.soPhieu.compareTo(b.soPhieu);
     });
     
     if (formItems.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Không có sản phẩm nào cần xuất'),
           backgroundColor: Colors.orange,
         ),
       );
       return;
     }
     
     await showDialog(
       context: context,
       builder: (context) => PTFormDialog(
         items: formItems,
         createdBy: createdBy,
       ),
     );
     
   } catch (e) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Lỗi khi tạo phiếu tổng: ${e.toString()}'),
         backgroundColor: Colors.red,
       ),
     );
   }
 }
}

class PTFormItem {
 final String idHang;
 final double soLuongYeuCau;
 final double? soLuongThucGiao;
 final String soPhieu;
 final String tenKhachHang;
 final String nguoiTao;
 
 PTFormItem({
   required this.idHang,
   required this.soLuongYeuCau,
   this.soLuongThucGiao,
   required this.soPhieu,
   required this.tenKhachHang,
   required this.nguoiTao,
 });
}

class PTFormDialog extends StatefulWidget {
 final List<PTFormItem> items;
 final String createdBy;
 
 const PTFormDialog({
   Key? key,
   required this.items,
   required this.createdBy,
 }) : super(key: key);
 
 @override
 _PTFormDialogState createState() => _PTFormDialogState();
}

class _PTFormDialogState extends State<PTFormDialog> {
 @override
 Widget build(BuildContext context) {
   final currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
   final currentTime = DateFormat('HH:mm').format(DateTime.now());
   
   return Dialog(
     insetPadding: EdgeInsets.all(16),
     child: Container(
       width: double.maxFinite,
       height: double.maxFinite,
       child: Column(
         children: [
           Container(
             padding: EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: Color(0xFF534b0d),
               borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
             ),
             child: Row(
               children: [
                 Icon(Icons.description, color: Colors.white),
                 SizedBox(width: 8),
                 Text(
                   'PHIẾU TỔNG CẦN XUẤT',
                   style: TextStyle(
                     color: Colors.white,
                     fontWeight: FontWeight.bold,
                     fontSize: 18,
                   ),
                 ),
                 Spacer(),
                 IconButton(
                   icon: Icon(Icons.close, color: Colors.white),
                   onPressed: () => Navigator.pop(context),
                 ),
               ],
             ),
           ),
           
           Container(
             padding: EdgeInsets.all(16),
             color: Colors.grey[100],
             child: Row(
               children: [
                 Expanded(
                   child: Text('Ngày tạo: $currentDate $currentTime'),
                 ),
                 Expanded(
                   child: Text('Người tạo: ${widget.createdBy}'),
                 ),
                 Expanded(
                   child: Text('Tổng SP: ${widget.items.length}'),
                 ),
               ],
             ),
           ),
           
           Expanded(
             child: SingleChildScrollView(
               child: Container(
                 width: double.infinity,
                 child: DataTable(
                   columnSpacing: 12,
                   horizontalMargin: 8,
                   headingRowColor: MaterialStateColor.resolveWith(
                     (states) => Color(0xFF534b0d).withOpacity(0.1),
                   ),
                   columns: [
                     DataColumn(
                       label: Text(
                         'STT',
                         style: TextStyle(fontWeight: FontWeight.bold),
                       ),
                     ),
                     DataColumn(
                       label: Text(
                         'Mã hàng - Tên hàng',
                         style: TextStyle(fontWeight: FontWeight.bold),
                       ),
                     ),
                     DataColumn(
                       label: Text(
                         'SL yêu cầu',
                         style: TextStyle(fontWeight: FontWeight.bold),
                       ),
                     ),
                     DataColumn(
                       label: Text(
                         'SL xuất',
                         style: TextStyle(fontWeight: FontWeight.bold),
                       ),
                     ),
                     DataColumn(
                       label: Text(
                         'Số phiếu',
                         style: TextStyle(fontWeight: FontWeight.bold),
                       ),
                     ),
                     DataColumn(
                       label: Text(
                         'Khách hàng',
                         style: TextStyle(fontWeight: FontWeight.bold),
                       ),
                     ),
                     DataColumn(
                       label: Text(
                         'Người tạo',
                         style: TextStyle(fontWeight: FontWeight.bold),
                       ),
                     ),
                   ],
                   rows: widget.items.asMap().entries.map((entry) {
                     final index = entry.key;
                     final item = entry.value;
                     
                     String productName = item.idHang;
                     if (item.idHang.contains(" - ")) {
                       //productName = item.idHang.split(" - ")[1];
                       productName = item.idHang;
                     }
                     
                     return DataRow(
                       cells: [
                         DataCell(Text('${index + 1}')),
                         DataCell(
                           Container(
                             constraints: BoxConstraints(maxWidth: 200),
                             child: Text(
                               productName,
                               overflow: TextOverflow.ellipsis,
                               maxLines: 2,
                             ),
                           ),
                         ),
                         DataCell(Text('${item.soLuongYeuCau.toStringAsFixed(item.soLuongYeuCau == item.soLuongYeuCau.toInt() ? 0 : 1)}')),
                         DataCell(
                           Text(
                             (item.soLuongThucGiao == null || item.soLuongThucGiao == 0) 
                               ? '' 
                               : '${item.soLuongThucGiao!.toStringAsFixed(item.soLuongThucGiao! == item.soLuongThucGiao!.toInt() ? 0 : 1)}',
                           ),
                         ),
                         DataCell(Text(item.soPhieu)),
                         DataCell(
                           Container(
                             constraints: BoxConstraints(maxWidth: 150),
                             child: Text(
                               item.tenKhachHang,
                               overflow: TextOverflow.ellipsis,
                             ),
                           ),
                         ),
                         DataCell(Text(item.nguoiTao)),
                       ],
                     );
                   }).toList(),
                 ),
               ),
             ),
           ),
           
           Container(
             padding: EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: Colors.grey[100],
               border: Border(top: BorderSide(color: Colors.grey[300]!)),
             ),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.end,
               children: [
                 TextButton(
                   onPressed: () => Navigator.pop(context),
                   child: Text('Đóng'),
                 ),
                 SizedBox(width: 8),
                 ElevatedButton.icon(
                   icon: Icon(Icons.share, color: Colors.white),
                   label: Text('Chia sẻ', style: TextStyle(color: Colors.white)),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.blue,
                   ),
                   onPressed: () => _sharePTForm(context),
                 ),
                 SizedBox(width: 8),
                 ElevatedButton.icon(
                   icon: Icon(Icons.print, color: Colors.white),
                   label: Text('In', style: TextStyle(color: Colors.white)),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Color(0xFF534b0d),
                   ),
                   onPressed: () => _printPTForm(context),
                 ),
               ],
             ),
           ),
         ],
       ),
     ),
   );
 }
 
 Future<void> _sharePTForm(BuildContext context) async {
   try {
     final pdf = await _generatePDF();
     
     final directory = await getTemporaryDirectory();
     final fileName = 'phieu_tong_can_xuat_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
     final filePath = '${directory.path}/$fileName';
     
     final file = File(filePath);
     await file.writeAsBytes(await pdf.save());
     
     await Share.shareXFiles(
       [XFile(filePath)],
       text: 'Phiếu tổng cần xuất',
     );
     
   } catch (e) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Lỗi khi chia sẻ: ${e.toString()}'),
         backgroundColor: Colors.red,
       ),
     );
   }
 }
 
 Future<void> _printPTForm(BuildContext context) async {
   try {
     final pdf = await _generatePDF();
     
     await Printing.layoutPdf(
       onLayout: (format) => pdf.save(),
       name: 'Phiếu tổng cần xuất',
     );
     
   } catch (e) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Lỗi khi in: ${e.toString()}'),
         backgroundColor: Colors.red,
       ),
     );
   }
 }
 
 Future<pw.Document> _generatePDF() async {
   final pdf = pw.Document();
   
   final fontData = await rootBundle.load("assets/fonts/RobotoCondensed-Regular.ttf");
   final ttf = pw.Font.ttf(fontData);
   
   final currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
   final currentTime = DateFormat('HH:mm').format(DateTime.now());
   
   pdf.addPage(
     pw.MultiPage(
       pageFormat: pdfx.PdfPageFormat.a4,
       margin: pw.EdgeInsets.all(20),
       build: (pw.Context context) {
         return [
           pw.Container(
             width: double.infinity,
             padding: pw.EdgeInsets.all(12),
             decoration: pw.BoxDecoration(
               color: pdfx.PdfColors.grey300,
               border: pw.Border.all(),
             ),
             child: pw.Column(
               children: [
                 pw.Text(
                   'PHIẾU TỔNG CẦN XUẤT',
                   style: pw.TextStyle(
                     font: ttf,
                     fontSize: 16,
                     fontWeight: pw.FontWeight.bold,
                   ),
                 ),
                 pw.SizedBox(height: 6),
                 pw.Row(
                   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                   children: [
                     pw.Text(
                       'Ngày tạo: $currentDate $currentTime',
                       style: pw.TextStyle(font: ttf, fontSize: 8),
                     ),
                     pw.Text(
                       'Người tạo: ${widget.createdBy}',
                       style: pw.TextStyle(font: ttf, fontSize: 8),
                     ),
                     pw.Text(
                       'Tổng SP: ${widget.items.length}',
                       style: pw.TextStyle(font: ttf, fontSize: 8),
                     ),
                   ],
                 ),
               ],
             ),
           ),
           
           pw.SizedBox(height: 12),
           
           pw.Table(
             border: pw.TableBorder.all(),
             columnWidths: {
               0: pw.FixedColumnWidth(25),
               1: pw.FlexColumnWidth(3),
               2: pw.FixedColumnWidth(45),
               3: pw.FixedColumnWidth(45),
               4: pw.FlexColumnWidth(1.5),
               5: pw.FlexColumnWidth(2),
               6: pw.FlexColumnWidth(1.2),
             },
             children: [
               pw.TableRow(
                 decoration: pw.BoxDecoration(
                   color: pdfx.PdfColors.grey300,
                 ),
                 children: [
                   _buildTableCell('STT', ttf, isBold: true, align: pw.TextAlign.center),
                   _buildTableCell('Mã hàng - Tên hàng', ttf, isBold: true),
                   _buildTableCell('SL yêu cầu', ttf, isBold: true, align: pw.TextAlign.center),
                   _buildTableCell('SL xuất', ttf, isBold: true, align: pw.TextAlign.center),
                   _buildTableCell('Số phiếu', ttf, isBold: true),
                   _buildTableCell('Khách hàng', ttf, isBold: true),
                   _buildTableCell('Người tạo', ttf, isBold: true),
                 ],
               ),
               
               ...widget.items.asMap().entries.map((entry) {
                 final index = entry.key;
                 final item = entry.value;
                 
                 String productName = item.idHang;
                 if (item.idHang.contains(" - ")) {
                   productName = item.idHang.split(" - ")[1];
                 }
                 
                 return pw.TableRow(
                   children: [
                     _buildTableCell('${index + 1}', ttf, align: pw.TextAlign.center),
                     _buildTableCell(productName, ttf),
                     _buildTableCell(
                       '${item.soLuongYeuCau.toStringAsFixed(item.soLuongYeuCau == item.soLuongYeuCau.toInt() ? 0 : 1)}',
                       ttf,
                       align: pw.TextAlign.center,
                     ),
                     _buildTableCell(
                       (item.soLuongThucGiao == null || item.soLuongThucGiao == 0) 
                         ? '' 
                         : '${item.soLuongThucGiao!.toStringAsFixed(item.soLuongThucGiao! == item.soLuongThucGiao!.toInt() ? 0 : 1)}',
                       ttf,
                       align: pw.TextAlign.center,
                     ),
                     _buildTableCell(item.soPhieu, ttf),
                     _buildTableCell(item.tenKhachHang, ttf),
                     _buildTableCell(item.nguoiTao, ttf),
                   ],
                 );
               }).toList(),
             ],
           ),
         ];
       },
     ),
   );
   
   return pdf;
 }
 
 static pw.Widget _buildTableCell(
   String text, 
   pw.Font font, {
   bool isBold = false,
   pw.TextAlign align = pw.TextAlign.left,
 }) {
   return pw.Padding(
     padding: pw.EdgeInsets.all(3),
     child: pw.Text(
       text,
       style: pw.TextStyle(
         font: font,
         fontSize: 10,
         fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
       ),
       textAlign: align,
     ),
   );
 }
}