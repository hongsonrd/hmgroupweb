import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as Math;

class DailyReportScreen extends StatefulWidget {
final String reportUrl;
final String reportTitle;

const DailyReportScreen({
  Key? key,
  required this.reportUrl,
  required this.reportTitle,
}) : super(key: key);

@override
State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
InAppWebViewController? webViewController;
bool _isLoading = true;
bool _isExporting = false;

final Color appBarTop = Color(0xFF024965);
final Color appBarBottom = Color(0xFF03a6cf);

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(
        widget.reportTitle,
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [appBarTop, appBarBottom],
          ),
        ),
      ),
      iconTheme: IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          onPressed: _isExporting ? null : _exportToPdf,
          icon: _isExporting
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Icon(Icons.picture_as_pdf, color: Colors.white),
          tooltip: 'Xuất PDF',
        ),
        IconButton(
          onPressed: () {
            webViewController?.reload();
          },
          icon: Icon(Icons.refresh, color: Colors.white),
          tooltip: 'Làm mới',
        ),
      ],
    ),
    body: Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.reportUrl)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            databaseEnabled: true,
          ),
          onWebViewCreated: (controller) {
            webViewController = controller;
          },
          onLoadStart: (controller, url) {
            setState(() {
              _isLoading = true;
            });
          },
          onLoadStop: (controller, url) async {
            setState(() {
              _isLoading = false;
            });
            
            await Future.delayed(Duration(seconds: 2));
          },
        ),
        if (_isLoading)
          Center(
            child: CircularProgressIndicator(
              color: appBarBottom,
            ),
          ),
      ],
    ),
  );
}

Future<void> _exportToPdf() async {
  if (webViewController == null) {
    _showErrorDialog('Webview chưa sẵn sàng');
    return;
  }

  setState(() {
    _isExporting = true;
  });

  _showProgressDialog();

  try {
    await _createPdfFromWebpage();
  } catch (e) {
    Navigator.pop(context);
    _showErrorDialog('Lỗi khi xuất PDF: $e');
    print('PDF Export Error: $e');
  } finally {
    setState(() {
      _isExporting = false;
    });
  }
}

Future<void> _createPdfFromWebpage() async {
  try {
    final pdf = pw.Document();
    
    final fontData = await rootBundle.load('assets/fonts/RobotoCondensed-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    final modalInfo = await _getModalIframeInfo();
    
    if (modalInfo['hasModal'] == true) {
      print('Modal with iframe detected');
      await _captureIframeContent(pdf, ttf, modalInfo);
    } else {
      print('No modal found, using regular page scrolling');
      await _captureRegularContent(pdf, ttf);
    }

    await _savePdf(pdf);

  } catch (e) {
    Navigator.pop(context);
    _showErrorDialog('Lỗi khi tạo PDF: $e');
    print('PDF Creation Error: $e');
  }
}

Future<Map<String, dynamic>> _getModalIframeInfo() async {
  final result = await webViewController!.evaluateJavascript(source: '''
    (function() {
      try {
        var modal = document.getElementById('reportModal');
        var iframe = document.getElementById('modalIframe');
        
        if (modal && iframe && modal.style.display !== 'none') {
          var iframeDoc = iframe.contentDocument || iframe.contentWindow.document;
          if (iframeDoc && iframeDoc.readyState === 'complete') {
            var body = iframeDoc.body || iframeDoc.documentElement;
            var totalHeight = Math.max(
              body.scrollHeight || 0,
              body.offsetHeight || 0,
              iframeDoc.documentElement.clientHeight || 0,
              iframeDoc.documentElement.scrollHeight || 0,
              iframeDoc.documentElement.offsetHeight || 0
            );
            
            return JSON.stringify({
              hasModal: true,
              iframeLoaded: true,
              totalHeight: totalHeight,
              viewportHeight: iframe.clientHeight || 600,
              viewportWidth: iframe.clientWidth || 800
            });
          } else {
            return JSON.stringify({
              hasModal: true,
              iframeLoaded: false
            });
          }
        }
        
        return JSON.stringify({hasModal: false});
      } catch (e) {
        return JSON.stringify({
          hasModal: false,
          error: e.toString()
        });
      }
    })();
  ''');

  if (result is String && result.contains('"hasModal"')) {
    try {
      final Map<String, dynamic> parsed = {};
      final heightMatch = RegExp(r'"totalHeight":(\d+)').firstMatch(result);
      final viewportHeightMatch = RegExp(r'"viewportHeight":(\d+)').firstMatch(result);
      final viewportWidthMatch = RegExp(r'"viewportWidth":(\d+)').firstMatch(result);
      final hasModalMatch = RegExp(r'"hasModal":(true|false)').firstMatch(result);
      final iframeLoadedMatch = RegExp(r'"iframeLoaded":(true|false)').firstMatch(result);
      
      parsed['hasModal'] = hasModalMatch?.group(1) == 'true';
      parsed['iframeLoaded'] = iframeLoadedMatch?.group(1) == 'true';
      parsed['totalHeight'] = heightMatch != null ? int.parse(heightMatch.group(1)!) : 1000;
      parsed['viewportHeight'] = viewportHeightMatch != null ? int.parse(viewportHeightMatch.group(1)!) : 600;
      parsed['viewportWidth'] = viewportWidthMatch != null ? int.parse(viewportWidthMatch.group(1)!) : 800;
      
      return parsed;
    } catch (e) {
      print('Error parsing modal info: $e');
      return {'hasModal': false};
    }
  }
  
  return {'hasModal': false};
}

Future<void> _captureIframeContent(pw.Document pdf, pw.Font ttf, Map<String, dynamic> modalInfo) async {
  if (modalInfo['iframeLoaded'] != true) {
    print('Waiting for iframe to load...');
    await Future.delayed(Duration(seconds: 3));
    
    modalInfo = await _getModalIframeInfo();
    if (modalInfo['iframeLoaded'] != true) {
      throw Exception('Iframe failed to load properly');
    }
  }

  final totalHeight = (modalInfo['totalHeight'] as num).toDouble();
  final viewportHeight = (modalInfo['viewportHeight'] as num).toDouble();
  
  print('Iframe content dimensions: totalHeight=$totalHeight, viewportHeight=$viewportHeight');
  
  await webViewController!.evaluateJavascript(source: '''
    (function() {
      try {
        var iframe = document.getElementById('modalIframe');
        if (iframe && iframe.contentWindow) {
          iframe.contentWindow.scrollTo(0, 0);
          return true;
        }
        return false;
      } catch (e) {
        console.log('Error resetting iframe scroll:', e);
        return false;
      }
    })();
  ''');
  
  await Future.delayed(Duration(milliseconds: 1000));
  
  double currentPosition = 0;
  final stepSize = viewportHeight * 0.8;
  int sectionCount = 0;
  int maxSections = Math.max(20, (totalHeight / stepSize).ceil() + 2);
  
  while (currentPosition < totalHeight && sectionCount < maxSections) {
    print('Processing iframe section ${sectionCount + 1} at position: $currentPosition');
    
    _updateProgressDialog(sectionCount + 1);
    
    final scrollResult = await webViewController!.evaluateJavascript(source: '''
      (function() {
        try {
          var iframe = document.getElementById('modalIframe');
          if (iframe && iframe.contentWindow) {
            iframe.contentWindow.scrollTo(0, $currentPosition);
            
            var actualScroll = iframe.contentWindow.pageYOffset || 
                             iframe.contentWindow.document.documentElement.scrollTop || 0;
            return actualScroll;
          }
          return -1;
        } catch (e) {
          console.log('Error scrolling iframe:', e);
          return -1;
        }
      })();
    ''');
    
    print('Requested scroll: $currentPosition, Actual scroll: $scrollResult');
    
    await Future.delayed(Duration(milliseconds: 2000));
    
    final screenshot = await webViewController!.takeScreenshot(
      screenshotConfiguration: ScreenshotConfiguration(
        compressFormat: CompressFormat.PNG,
        quality: 90,
      ),
    );

    if (screenshot != null) {
      print('Screenshot captured for iframe section ${sectionCount + 1}');
      await _addScreenshotToPdf(pdf, screenshot, ttf, sectionCount, maxSections);
    } else {
      print('Failed to capture screenshot for iframe section ${sectionCount + 1}');
    }

    currentPosition += stepSize;
    sectionCount++;
    
    if (scrollResult != null && scrollResult is num) {
      final actualScrollPos = scrollResult.toDouble();
      if (actualScrollPos >= totalHeight - viewportHeight || 
          (currentPosition > stepSize && actualScrollPos == (currentPosition - stepSize))) {
        print('Reached end of iframe content at scroll position: $actualScrollPos');
        break;
      }
    }
  }
  
  await webViewController!.evaluateJavascript(source: '''
    (function() {
      try {
        var iframe = document.getElementById('modalIframe');
        if (iframe && iframe.contentWindow) {
          iframe.contentWindow.scrollTo(0, 0);
        }
      } catch (e) {
        console.log('Error resetting iframe scroll at end:', e);
      }
    })();
  ''');
  
  if (sectionCount == 0) {
    throw Exception('No screenshots were captured from iframe content');
  }
}

Future<void> _captureRegularContent(pw.Document pdf, pw.Font ttf) async {
  final result = await webViewController!.evaluateJavascript(source: '''
    (function() {
      try {
        var body = document.body || document.documentElement;
        var html = document.documentElement;
        
        var totalHeight = Math.max(
          body.scrollHeight || 0,
          body.offsetHeight || 0,
          html.clientHeight || 0,
          html.scrollHeight || 0,
          html.offsetHeight || 0
        );
        
        var viewportHeight = window.innerHeight || 600;
        var viewportWidth = window.innerWidth || 800;
        
        return JSON.stringify({
          totalHeight: totalHeight,
          viewportHeight: viewportHeight,
          viewportWidth: viewportWidth,
          success: true
        });
      } catch (e) {
        return JSON.stringify({
          totalHeight: 1000,
          viewportHeight: 600,
          viewportWidth: 800,
          success: false,
          error: e.toString()
        });
      }
    })();
  ''');

  Map<String, dynamic> dimensions;
  if (result is String && result.contains('"totalHeight"')) {
    final heightMatch = RegExp(r'"totalHeight":(\d+)').firstMatch(result);
    final viewportHeightMatch = RegExp(r'"viewportHeight":(\d+)').firstMatch(result);
    final viewportWidthMatch = RegExp(r'"viewportWidth":(\d+)').firstMatch(result);
    
    dimensions = {
      'totalHeight': heightMatch != null ? int.parse(heightMatch.group(1)!) : 1000,
      'viewportHeight': viewportHeightMatch != null ? int.parse(viewportHeightMatch.group(1)!) : 600,
      'viewportWidth': viewportWidthMatch != null ? int.parse(viewportWidthMatch.group(1)!) : 800,
    };
  } else {
    dimensions = {'totalHeight': 1000, 'viewportHeight': 600, 'viewportWidth': 800};
  }

  final totalHeight = (dimensions['totalHeight'] as num).toDouble();
  final viewportHeight = (dimensions['viewportHeight'] as num).toDouble();
  final viewportWidth = (dimensions['viewportWidth'] as num).toDouble();

  print('Page dimensions: ${viewportWidth}x${totalHeight}, Viewport: ${viewportWidth}x${viewportHeight}');

  await webViewController!.evaluateJavascript(source: 'window.scrollTo(0, 0);');
  await Future.delayed(Duration(milliseconds: 800));

  double currentPosition = 0;
  final stepSize = viewportHeight * 0.9;
  int sectionCount = 0;
  int maxSections = 20;

  while (currentPosition < totalHeight && sectionCount < maxSections) {
    print('Processing section ${sectionCount + 1} at position: $currentPosition');
    
    _updateProgressDialog(sectionCount + 1);
    
    await webViewController!.evaluateJavascript(
      source: 'window.scrollTo(0, $currentPosition);'
    );
    
    await Future.delayed(Duration(milliseconds: 1500));
    
    final scrollY = await webViewController!.evaluateJavascript(
      source: 'window.pageYOffset || document.documentElement.scrollTop;'
    );
    print('Expected: $currentPosition, Actual: $scrollY');

    final screenshot = await webViewController!.takeScreenshot(
      screenshotConfiguration: ScreenshotConfiguration(
        compressFormat: CompressFormat.PNG,
        quality: 85,
      ),
    );

    if (screenshot != null) {
      print('Screenshot captured, size: ${screenshot.length} bytes');
      
      await _addScreenshotToPdf(pdf, screenshot, ttf, sectionCount, maxSections);
      
      print('Screenshot processed and cleared from memory');
    } else {
      print('Failed to capture screenshot for section ${sectionCount + 1}');
    }

    currentPosition += stepSize;
    sectionCount++;
  }

  await webViewController!.evaluateJavascript(source: 'window.scrollTo(0, 0);');

  if (sectionCount == 0) {
    throw Exception('No screenshots were captured');
  }

  print('All sections processed, saving PDF...');
}

Future<void> _addScreenshotToPdf(
  pw.Document pdf, 
  Uint8List screenshot, 
  pw.Font ttf, 
  int sectionIndex,
  int totalSections
) async {
  try {
    final image = pw.MemoryImage(screenshot);
    
    final codec = await ui.instantiateImageCodec(screenshot);
    final frame = await codec.getNextFrame();
    final imageWidth = frame.image.width.toDouble();
    final imageHeight = frame.image.height.toDouble();
    
    print('Adding page ${sectionIndex + 1}: Image ${imageWidth}x${imageHeight}');
    
    final pageWidth = 800.0;
    final aspectRatio = imageHeight / imageWidth;
    final imageHeightInPdf = pageWidth * aspectRatio;
    
    final headerHeight = 60.0;
    final footerHeight = 30.0;
    final margin = 15.0;
    final totalPadding = headerHeight + footerHeight + (margin * 2) + 30;
    final pageHeight = imageHeightInPdf + totalPadding;
    
    final customPageFormat = PdfPageFormat(
      pageWidth,
      pageHeight,
      marginAll: margin,
    );
    
    pdf.addPage(
      pw.Page(
        pageFormat: customPageFormat,
        margin: pw.EdgeInsets.all(margin),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (sectionIndex == 0) 
                _buildPdfHeader(ttf)
              else 
                _buildPdfPageHeader(ttf, sectionIndex + 1),
              
              pw.SizedBox(height: 15),
              
              pw.Container(
                width: double.infinity,
                height: imageHeightInPdf,
                child: pw.Image(
                  image,
                  fit: pw.BoxFit.contain,
                  alignment: pw.Alignment.topCenter,
                ),
              ),
              
              pw.Spacer(),
              
              _buildPdfPageFooter(ttf, sectionIndex + 1, totalSections),
            ],
          );
        },
      ),
    );
    
    frame.image.dispose();
    codec.dispose();
    
    print('Page ${sectionIndex + 1} added to PDF successfully');
    
  } catch (e) {
    print('Error adding screenshot to PDF: $e');
    throw e;
  }
}

pw.Widget _buildPdfHeader(pw.Font ttf) {
  return pw.Container(
    width: double.infinity,
    padding: pw.EdgeInsets.only(bottom: 12),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: PdfColors.blue, width: 2),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Text(
            widget.reportTitle,
            style: pw.TextStyle(
              font: ttf,
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
        ),
        pw.Text(
          'HM Group',
          style: pw.TextStyle(
            font: ttf,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue700,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildPdfPageHeader(pw.Font ttf, int pageNumber) {
  return pw.Container(
    width: double.infinity,
    padding: pw.EdgeInsets.only(bottom: 10),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: PdfColors.blue300, width: 1),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          '${widget.reportTitle} - Trang $pageNumber',
          style: pw.TextStyle(
            font: ttf,
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue700,
          ),
        ),
        pw.Text(
          'HM Group',
          style: pw.TextStyle(
            font: ttf,
            fontSize: 10,
            color: PdfColors.grey600,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildPdfPageFooter(pw.Font ttf, int currentPage, int totalPages) {
  return pw.Container(
    width: double.infinity,
    padding: pw.EdgeInsets.only(top: 8),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: PdfColors.grey300),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'HM Group App',
          style: pw.TextStyle(
            font: ttf,
            fontSize: 8,
            color: PdfColors.grey600,
          ),
        ),
        pw.Text(
          'Trang $currentPage/$totalPages',
          style: pw.TextStyle(
            font: ttf,
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue600,
          ),
        ),
      ],
    ),
  );
}

void _showProgressDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Đang chụp và xử lý trang web...'),
          SizedBox(height: 8),
          Text(
            'Đang xử lý phần 1...',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            key: ValueKey('progress_text'),
          ),
        ],
      ),
    ),
  );
}

void _updateProgressDialog(int sectionNumber) {
  print('Processing section $sectionNumber');
}

Future<void> _savePdf(pw.Document pdf) async {
  final directory = await getApplicationDocumentsDirectory();
  final reportFolder = Directory('${directory.path}/BaoCao_HTML');
  
  if (!await reportFolder.exists()) {
    await reportFolder.create(recursive: true);
  }

  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final sanitizedTitle = widget.reportTitle.replaceAll(RegExp(r'[^\w\s-]'), '');
  final fileName = 'BaoCao_${sanitizedTitle}_$timestamp.pdf';
  final filePath = '${reportFolder.path}/$fileName';

  final file = File(filePath);
  await file.writeAsBytes(await pdf.save());

  Navigator.pop(context);
  _showSuccessDialog(filePath, fileName, reportFolder.path);
}

void _showSuccessDialog(String filePath, String fileName, String folderPath) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 28),
          SizedBox(width: 12),
          Text(
            'Xuất PDF thành công!',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('File đã được lưu tại:'),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tên file:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(fileName, style: TextStyle(fontSize: 12)),
                SizedBox(height: 8),
                Text(
                  'Đường dẫn:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  filePath,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Đóng'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _openFolder(folderPath);
          },
          icon: Icon(Icons.folder_open, size: 18),
          label: Text('Mở thư mục'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF33a7ce),
            foregroundColor: Colors.white,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _openFile(filePath);
          },
          icon: Icon(Icons.open_in_new, size: 18),
          label: Text('Mở file'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF2196F3),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );
}

void _showErrorDialog(String message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error, color: Colors.red, size: 28),
          SizedBox(width: 12),
          Text('Lỗi', style: TextStyle(color: Colors.red)),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Đóng'),
        ),
      ],
    ),
  );
}

Future<void> _openFile(String filePath) async {
  try {
    if (Platform.isWindows) {
      await Process.run('start', ['', filePath], runInShell: true);
    } else if (Platform.isMacOS) {
      await Process.run('open', [filePath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [filePath]);
    }
  } catch (e) {
    print('Error opening file: $e');
    _showErrorDialog('Không thể mở file: $e');
  }
}

Future<void> _openFolder(String folderPath) async {
  try {
    if (Platform.isWindows) {
      await Process.run('explorer', [folderPath], runInShell: true);
    } else if (Platform.isMacOS) {
      await Process.run('open', [folderPath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [folderPath]);
    }
  } catch (e) {
    print('Error opening folder: $e');
    _showErrorDialog('Không thể mở thư mục: $e');
  }
}
}