import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class ProjectTimeline3ReportSender {
  static const String baseUrl = 'https://hmbeacon-81200125587.asia-east2.run.app';
  
  static Future<void> sendReportToCompany({
    required BuildContext context,
    required String username,
    required String projectName,
    required String filePath,
  }) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Đang gửi báo cáo về công ty...'),
                SizedBox(height: 8),
                Text(
                  'Vui lòng đợi',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      // Upload file to server
      final result = await _uploadReportToServer(
        username: username,
        projectName: projectName,
        filePath: filePath,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Generate QR code and show success dialog
      await _showUploadSuccessDialog(
        context: context,
        accessUrl: result['accessUrl']!,  // Fixed: Added ! to ensure non-null
        fileName: filePath.split('/').last,
        projectName: projectName,
        password: result['password']!,    // Fixed: Added ! to ensure non-null
      );

    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error dialog
      _showErrorDialog(
        context: context,
        message: 'Lỗi khi gửi báo cáo: ${e.toString()}',
      );
    }
  }

  // Fixed: Changed return type from Future<String> to Future<Map<String, String>>
  static Future<Map<String, String>> _uploadReportToServer({
    required String username,
    required String projectName,
    required String filePath,
  }) async {
    try {
      final file = File(filePath);
      final fileName = file.path.split('/').last;
      
      // Check if file exists
      if (!await file.exists()) {
        throw Exception('File không tồn tại: $filePath');
      }

      // Create multipart request
      final uri = Uri.parse('$baseUrl/projectbaocao');
      final request = http.MultipartRequest('POST', uri);
      
      // Add form fields
      request.fields['username'] = username;
      request.fields['project_name'] = projectName;
      request.fields['file_name'] = fileName;
      
      // Add file
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: fileName,
      );
      request.files.add(multipartFile);

      // Add headers
      request.headers.addAll({
        'Accept': 'application/json',
      });

      print('Uploading report to server...');
      print('Username: $username');
      print('Project: $projectName');
      print('File: $fileName');

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Upload response status: ${response.statusCode}');
      print('Upload response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['success'] == true && responseData['access_url'] != null) {
          // Extract password from report_info
          final password = responseData['report_info']['password'] ?? '';
          
          // Fixed: Return proper Map<String, String>
          return {
            'accessUrl': responseData['access_url'] as String,
            'password': password as String,
          };
        } else {
          throw Exception(responseData['message'] ?? 'Không nhận được URL truy cập từ server');
        }
      } else if (response.statusCode == 413) {
        throw Exception('File quá lớn. Vui lòng thử lại với file nhỏ hơn.');
      } else if (response.statusCode == 400) {
        final responseData = json.decode(response.body);
        throw Exception(responseData['message'] ?? 'Dữ liệu gửi không hợp lệ');
      } else if (response.statusCode == 500) {
        throw Exception('Lỗi server. Vui lòng thử lại sau.');
      } else {
        throw Exception('Lỗi không xác định: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading report: $e');
      if (e.toString().contains('SocketException') || e.toString().contains('Connection')) {
        throw Exception('Lỗi kết nối mạng. Vui lòng kiểm tra internet.');
      } else if (e.toString().contains('TimeoutException')) {
        throw Exception('Hết thời gian chờ. Vui lòng thử lại.');
      } else {
        rethrow;
      }
    }
  }

  static Future<void> _showUploadSuccessDialog({
    required BuildContext context,
    required String accessUrl,
    required String fileName,
    required String projectName,
    required String password,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            title: Row(
              children: [
                Icon(Icons.cloud_done, color: Colors.green),
                SizedBox(width: 8),
                Text('Gửi báo cáo thành công'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Báo cáo đã được gửi lên server thành công!'),
                SizedBox(height: 12),
                
                // Report info (without file name)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.picture_as_pdf, size: 16, color: Colors.blue[700]),
                          SizedBox(width: 6),
                          Text(
                            'Thông tin báo cáo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('Dự án: $projectName', style: TextStyle(fontSize: 13)),
                      Text('Thời gian: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', 
                           style: TextStyle(fontSize: 13)),
                      SizedBox(height: 8),
                      // Show password for access
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.vpn_key, size: 16, color: Colors.green[700]),
                            SizedBox(width: 6),
                            Text(
                              'Mã truy cập: ',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green[700],
                              ),
                            ),
                            Text(
                              password,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 16),
                
                // QR Code section
                Text(
                  'Mã QR truy cập báo cáo:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                
                // QR Code display
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: QrImageView(
                        data: accessUrl,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.all(16),
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.blue[700],
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black87,
                        ),
                        errorStateBuilder: (context, error) {
                          return Container(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error, color: Colors.red),
                                  SizedBox(height: 8),
                                  Text(
                                    'Lỗi tạo QR code',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 12),
                
                // URL display
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    accessUrl,
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
                  await _copyUrlToClipboard(context, accessUrl);
                },
                icon: Icon(Icons.copy, size: 16),
                label: Text('Copy URL'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop(); // Close dialog first
                  await _shareQrCode(context, accessUrl, projectName, password);
                },
                icon: Icon(Icons.share, size: 16),
                label: Text('Chia sẻ QR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _copyUrlToClipboard(BuildContext context, String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Đã copy URL vào clipboard'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Lỗi khi copy URL'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  static Future<void> _shareQrCode(
    BuildContext context, 
    String accessUrl, 
    String projectName, 
    String password
  ) async {
    try {
      // Generate QR code image
      final qrPainter = QrPainter(
        data: accessUrl,
        version: QrVersions.auto,
        color: Colors.black,
        emptyColor: Colors.white,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.blue[700]!,
        ),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black87,
        ),
      );

      // Convert to image
      final picData = await qrPainter.toImageData(512);
      if (picData == null) {
        throw Exception('Không thể tạo hình ảnh QR code');
      }

      final bytes = picData.buffer.asUint8List();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final qrFileName = 'QR_${projectName.replaceAll(RegExp(r'[^\w\s-]'), '')}_${timestamp}.png';

      if (Platform.isAndroid || Platform.isIOS) {
        // Mobile: Use share_plus
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$qrFileName');
        await file.writeAsBytes(bytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: '''
Mã QR truy cập báo cáo dự án

📋 Dự án: $projectName
🔑 Mã truy cập: $password
⏰ Thời gian: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}
🔗 Link: $accessUrl

Quét mã QR hoặc truy cập link để xem báo cáo trực tuyến.
          '''.trim(),
          subject: 'Mã QR báo cáo - $projectName',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Đã chia sẻ mã QR thành công'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // Desktop: Save to folder
        final directory = await getApplicationDocumentsDirectory();
        final qrFolder = Directory('${directory.path}/QR_BaoCao');
        
        // Create folder if it doesn't exist
        if (!await qrFolder.exists()) {
          await qrFolder.create(recursive: true);
        }
        
        final filePath = '${qrFolder.path}/$qrFileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        // Show success dialog for desktop
        await _showQrSaveSuccessDialog(context, qrFolder.path, qrFileName, projectName, password);
      }

    } catch (e) {
      print('Error sharing QR code: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Lỗi khi chia sẻ QR code'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  static Future<void> _showQrSaveSuccessDialog(
    BuildContext context,
    String folderPath,
    String fileName,
    String projectName,
    String password
  ) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Lưu QR code thành công'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mã QR đã được lưu:'),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      fileName,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Dự án: $projectName',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      'Mã truy cập: $password',
                      style: TextStyle(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.bold),
                    ),
                  ],
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
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _openFolder(String folderPath) async {
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

  static void _showErrorDialog({
    required BuildContext context,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Lỗi gửi báo cáo'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange[600], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vui lòng kiểm tra kết nối mạng và thử lại sau.',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Đóng'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  } 
}