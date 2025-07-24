import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'db_helper.dart';
import 'table_models.dart';
import 'dart:math';

class ReportConfig {
  final String audience;
  final Map<String, double> categoryRatings;
  final String improvementSuggestions;

  ReportConfig({
    required this.audience,
    required this.categoryRatings,
    required this.improvementSuggestions,
  });

  // Add JSON serialization methods
  Map<String, dynamic> toJson() {
    return {
      'audience': audience,
      'categoryRatings': categoryRatings,
      'improvementSuggestions': improvementSuggestions,
    };
  }

  factory ReportConfig.fromJson(Map<String, dynamic> json) {
    return ReportConfig(
      audience: json['audience'] ?? 'Ban quản lý',
      categoryRatings: Map<String, double>.from(json['categoryRatings'] ?? {}),
      improvementSuggestions: json['improvementSuggestions'] ?? '',
    );
  }
}

class ProjectTimeline3FileGenerator {
  static Future<String?> generateReport({
    required String projectName,
    required DateTime selectedMonth,
    required String username,
    required List<dynamic> imageCountData,
    ReportConfig? reportConfig,
    Map<int, List<Map<String, dynamic>>>? selectedWeeklyImages,
  }) async {
    try {
      final fontData = await rootBundle.load('assets/fonts/RobotoCondensed-Regular.ttf');
      final ttf = pw.Font.ttf(fontData);
      
      final logoData = await rootBundle.load('assets/logo.png');
      final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

      final detailedData = await _getDetailedReportData(projectName, selectedMonth);
      
      final pdf = pw.Document();

      final monthYear = DateFormat('MM/yyyy').format(selectedMonth);
      final reportDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
      final day = DateFormat('dd').format(DateTime.now());
      final month = DateFormat('MM').format(DateTime.now());
      final year = DateFormat('yyyy').format(DateTime.now());
      
      final weeklyData = _groupDataByWeek(detailedData);
      final topicData = _analyzeTopics(detailedData);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header with logo and updated title (removed report date)
              pw.Container(
                padding: pw.EdgeInsets.only(bottom: 20),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.blue, width: 2),
                  ),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 80,
                      height: 80,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'BÁO CÁO DỊCH VỤ VỆ SINH THÁNG $monthYear',
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            'của CÔNG TY TNHH HOÀN MỸ',
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Updated greeting
              pw.Text(
                'Kính gửi ${reportConfig?.audience ?? 'Ban lãnh đạo'}. Dự án: $projectName',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 14,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),

              pw.SizedBox(height: 20),

              // Updated introduction text (no longer in container/box)
              pw.Text(
                'Công ty TNHH Hoàn Mỹ trân trọng cảm ơn Quý Khách hàng đã hợp tác với Công ty chúng tôi trong thời gian qua.',
                style: pw.TextStyle(font: ttf, fontSize: 12),
              ),
              pw.SizedBox(height: 12),
              
              pw.Text(
                'Nhằm nâng cao Chất lượng dịch vụ, Công ty chúng tôi xin gửi tới Quý Khách hàng Báo cáo Dịch vụ vệ sinh Tháng $monthYear bao gồm:',
                style: pw.TextStyle(font: ttf, fontSize: 12),
              ),
              pw.SizedBox(height: 16),
              
              pw.Text(
                '1. CƠ SỞ ĐÁNH GIÁ DỊCH VỤ VỆ SINH:',
                style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              
              pw.Padding(
                padding: pw.EdgeInsets.only(left: 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('- Công việc Giám sát thường xuyên và đột xuất', style: pw.TextStyle(font: ttf, fontSize: 11)),
                    pw.SizedBox(height: 4),
                    pw.Text('- Khối lượng công việc thực hiện', style: pw.TextStyle(font: ttf, fontSize: 11)),
                    pw.SizedBox(height: 4),
                    pw.Text('- Tần suất công việc thực hiện', style: pw.TextStyle(font: ttf, fontSize: 11)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              
              pw.Text(
                '2. KẾT QUẢ ĐÁNH GIÁ',
                style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),

              pw.SizedBox(height: 25),

              // A. Weekly progress chart
              pw.Text(
                'A. TỔNG QUAN TIẾN ĐỘ THEO TUẦN',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 15),
              
              _buildWeeklyChart(ttf, weeklyData),

              pw.SizedBox(height: 25),

              // B. Topic distribution (only PHÂN BỐ THEO CHỦ ĐỀ)
              if (topicData.isNotEmpty) ...[
                pw.Text(
                  'B. PHÂN BỐ THEO CHỦ ĐỀ',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 15),
                
                _buildTopicCountBarChart(ttf, topicData),

                pw.SizedBox(height: 25),

                // C. Overall effectiveness
                pw.Text(
                  'C. HIỆU QUẢ TỔNG THỂ',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 15),

                _buildEffectivenessBarChart(ttf, topicData),
                
                pw.SizedBox(height: 25),
              ],

              // D. Category Ratings as Table
              if (reportConfig != null && reportConfig.categoryRatings.isNotEmpty) ...[
                pw.Text(
                  'D. KẾT QUẢ ĐÁNH GIÁ',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 15),
                
                _buildCategoryRatingsTable(ttf, reportConfig.categoryRatings),
                
                pw.SizedBox(height: 25),
              ],

              // E. Improvement suggestions
              if (reportConfig != null && reportConfig.improvementSuggestions.isNotEmpty) ...[
                pw.Text(
                  'E. Tồn tại và Đề xuất Giải pháp cải tiến Dịch vụ từ Công ty TNHH Hoàn Mỹ (nếu có)',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 15),
                
                pw.Container(
                  padding: pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.orange50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.orange200),
                  ),
                  child: pw.Text(
                    reportConfig.improvementSuggestions,
                    style: pw.TextStyle(font: ttf, fontSize: 12),
                  ),
                ),
                
                pw.SizedBox(height: 25),
              ],

              // F. Response section
              pw.Text(
                'F. Theo Ông (Bà) Hoàn Mỹ cần làm gì để cải tiến dịch vụ:',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 15),
              
              pw.Container(
                height: 100,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Container(), // Empty space for response
              ),
              
              pw.SizedBox(height: 40),

              // Footer information
              pw.Text(
                'Báo cáo này được trích xuất từ Dữ liệu của Công ty TNHH Hoàn Mỹ ngày $day tháng $month năm $year và là tài liệu đặc quyền của Công ty TNHH Hoàn Mỹ',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              
              pw.SizedBox(height: 15),
              
              pw.Text(
                'Báo cáo sinh ra tự động từ hệ thống Hoàn Mỹ. Mọi thông tin vui lòng liên hệ nhân viên kinh doanh tương ứng.',
                style: pw.TextStyle(font: ttf, fontSize: 8, fontStyle: pw.FontStyle.italic),
              ),
              
              pw.SizedBox(height: 20),
              
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'CÔNG TY TNHH HOÀN MỸ',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ];
          },
        ),
      );

      // Add weekly images pages with selected images
      if (selectedWeeklyImages != null) {
        for (var entry in selectedWeeklyImages.entries) {
          final weekNumber = entry.key;
          final selectedImages = entry.value;
          
          if (selectedImages.isNotEmpty) {
            final downloadedImages = await _downloadWeeklyImages(selectedImages, weekNumber);
            
            pdf.addPage(
              pw.MultiPage(
                pageFormat: PdfPageFormat.a4,
                margin: pw.EdgeInsets.all(32),
                build: (pw.Context context) {
                  return [
                    pw.Container(
                      padding: pw.EdgeInsets.only(bottom: 15),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(color: PdfColors.blue, width: 1),
                        ),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text(
                            'HÌNH ẢNH MINH HỌA CÔNG VIỆC - TUẦN $weekNumber',
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.Spacer(),
                          pw.Text(
                            '(${selectedImages.length} hình ảnh được chọn)',
                            style: pw.TextStyle(font: ttf, fontSize: 12, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                    
                    pw.SizedBox(height: 20),
                    
                    ..._buildWeeklyImagesGrid(ttf, downloadedImages),
                  ];
                },
              ),
            );
          }
        }
      }

      // Save PDF to file
      final directory = await getApplicationDocumentsDirectory();
final reportFolder = Directory('${directory.path}/BaoCao_DuAn');

if (!await reportFolder.exists()) {
  await reportFolder.create(recursive: true);
}

// Generate new filename format: YYYYMMDDHHMMSS + baocao + random number
final now = DateTime.now();
final timestamp = DateFormat('yyyyMMddHHmmss').format(now);
final random = Random();
final randomNumber = 1000000 + random.nextInt(9000000); // Generate random number from 1000000 to 9999999
final fileName = '${timestamp}baocao$randomNumber.pdf';
final filePath = '${reportFolder.path}/$fileName';

final file = File(filePath);
await file.writeAsBytes(await pdf.save());

return filePath;
    } catch (e) {
      print('Error generating PDF report: $e');
      return null;
    }
  }

  // New method to build category ratings as a table
  static pw.Widget _buildCategoryRatingsTable(pw.Font ttf, Map<String, double> categoryRatings) {
    // Group categories
    List<String> giaiPhapCategories = [];
    double machineRating = 0.0;
    double employeeRating = 0.0;
    
    categoryRatings.forEach((key, value) {
      if (key == 'Máy móc, trang thiết bị, dụng cụ làm việc') {
        machineRating = value;
      } else if (key == 'Tác phong làm việc của nhân viên') {
        employeeRating = value;
      } else {
        giaiPhapCategories.add(key);
      }
    });

    final averageRating = _calculateAverageRating(categoryRatings);

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.blue100),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(12),
              child: pw.Text('Danh mục đánh giá', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(12),
              child: pw.Text('Điểm đánh giá (%)', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(12),
              child: pw.Text('Ghi chú', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
        
        // Group 1: GiaiPhap categories
        if (giaiPhapCategories.isNotEmpty) ...[
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColors.grey100),
            children: [
              pw.Padding(
                padding: pw.EdgeInsets.all(12),
                child: pw.Text('Nhóm 1: Các khu vực thực hiện', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Padding(padding: pw.EdgeInsets.all(12), child: pw.Container()),
              pw.Padding(padding: pw.EdgeInsets.all(12), child: pw.Container()),
            ],
          ),
          ...giaiPhapCategories.map((category) => pw.TableRow(
            children: [
              pw.Padding(
                padding: pw.EdgeInsets.all(12),
                child: pw.Text('  • $category', style: pw.TextStyle(font: ttf, fontSize: 11)),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(12),
                child: pw.Text('${categoryRatings[category]!.toStringAsFixed(1)}% - ${_getRatingLabel(categoryRatings[category]!)}', 
                style: pw.TextStyle(font: ttf, fontSize: 11)),
              ),
              pw.Padding(padding: pw.EdgeInsets.all(12), child: pw.Container()),
            ],
          )),
        ],
        
        // Group 2: Machine and equipment
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(12),
              child: pw.Text('Nhóm 2: Trang thiết bị', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(padding: pw.EdgeInsets.all(12), child: pw.Container()),
            pw.Padding(padding: pw.EdgeInsets.all(12), child: pw.Container()),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(12),
              child: pw.Text('  • Máy móc, trang thiết bị, dụng cụ làm việc', style: pw.TextStyle(font: ttf, fontSize: 11)),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(12),
              child: pw.Text('${machineRating.toStringAsFixed(1)}% - ${_getRatingLabel(machineRating)}', 
              style: pw.TextStyle(font: ttf, fontSize: 11)),
            ),
            pw.Padding(padding: pw.EdgeInsets.all(12), child: pw.Container()),
          ],
        ),
        
        // Group 3: Employee performance
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(12),
              child: pw.Text('Nhóm 3: Nhân viên', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(padding: pw.EdgeInsets.all(12), child: pw.Container()),
            pw.Padding(padding: pw.EdgeInsets.all(12), child: pw.Container()),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(12),
              child: pw.Text('  • Tác phong làm việc của nhân viên', style: pw.TextStyle(font: ttf, fontSize: 11)),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(12),
              child: pw.Text('${employeeRating.toStringAsFixed(1)}% - ${_getRatingLabel(employeeRating)}', 
              style: pw.TextStyle(font: ttf, fontSize: 11)),
            ),
            pw.Padding(padding: pw.EdgeInsets.all(12), child: pw.Container()),
          ],
        ),
        
        // Final average
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.blue50),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(12),
              child: pw.Text('ĐÁNH GIÁ TRUNG BÌNH TỔNG THỂ', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(12),
              child: pw.Text('${averageRating.toStringAsFixed(1)}% - ${_getRatingLabel(averageRating)}', 
              style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
            ),
            pw.Padding(padding: pw.EdgeInsets.all(12), child: pw.Container()),
          ],
        ),
      ],
    );
  }

  static double _calculateAverageRating(Map<String, double> categoryRatings) {
    if (categoryRatings.isEmpty) return 0.0;
    final total = categoryRatings.values.fold<double>(0.0, (sum, rating) => sum + rating);
    return total / categoryRatings.length;
  }

  static String _getRatingLabel(double rating) {
    if (rating >= 80) return 'Xuất sắc';
    if (rating >= 70) return 'Tốt';
    if (rating >= 60) return 'Khá';
    if (rating >= 50) return 'Trung bình';
    return 'Cần cải thiện';
  }

  // Rest of the existing methods remain the same...
  static Future<List<Map<String, dynamic>>> _getDetailedReportData(String projectName, DateTime selectedMonth) async {
    try {
      final dbHelper = DBHelper();
      final db = await dbHelper.database;
      
      DateTime startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
      DateTime endOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
      
      final results = await db.rawQuery('''
        SELECT 
          Ngay,
          Gio,
          PhanLoai,
          KetQua,
          ChiTiet,
          ChiTiet2,
          HinhAnh,
          GiaiPhap,
          ViTri
        FROM ${DatabaseTables.taskHistoryTable}
        WHERE BoPhan = ?
        AND Ngay >= ? AND Ngay < ?
        ORDER BY Ngay ASC, Gio ASC
      ''', [projectName, startOfMonth.toIso8601String(), endOfMonth.toIso8601String()]);

      return results;
    } catch (e) {
      print('Error getting detailed data: $e');
      return [];
    }
  }

  static List<WeeklyData> _groupDataByWeek(List<Map<String, dynamic>> data) {
    Map<int, WeeklyData> weeklyMap = {};
    
    for (var item in data) {
      try {
        final date = DateTime.parse(item['Ngay']);
        final weekNumber = _getWeekNumber(date);
        
        if (!weeklyMap.containsKey(weekNumber)) {
          weeklyMap[weekNumber] = WeeklyData(
            weekNumber: weekNumber,
            startDate: _getStartOfWeek(date),
            endDate: _getEndOfWeek(date),
            totalReports: 0,
            imageCount: 0,
            goodResults: 0,
            warningResults: 0,
            badResults: 0,
            images: [],
          );
        }
        
        final weekData = weeklyMap[weekNumber]!;
        weekData.totalReports++;
        
        if (item['HinhAnh'] != null && item['HinhAnh'].toString().isNotEmpty) {
          weekData.imageCount++;
        }
        
        final result = item['KetQua']?.toString() ?? '';
        if (result.contains('✔️')) {
          weekData.goodResults++;
        } else if (result.contains('⚠️')) {
          weekData.warningResults++;
        } else if (result.contains('❌')) {
          weekData.badResults++;
        } else {
          weekData.goodResults++;
        }
      } catch (e) {
        print('Error processing item for week grouping: $e');
      }
    }
    
    return weeklyMap.values.toList()..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));
  }

  static Map<String, TopicData> _analyzeTopics(List<Map<String, dynamic>> data) {
    Map<String, TopicData> topics = {};
    
    for (var item in data) {
      final topic = item['PhanLoai']?.toString() ?? 'Khác';
      final result = item['KetQua']?.toString() ?? '';
      
      if (!topics.containsKey(topic)) {
        topics[topic] = TopicData(
          name: topic,
          totalCount: 0,
          goodCount: 0,
          warningCount: 0,
          badCount: 0,
        );
      }
      
      final topicData = topics[topic]!;
      topicData.totalCount++;
      
      if (result.contains('✔️')) {
        topicData.goodCount++;
      } else if (result.contains('⚠️')) {
        topicData.warningCount++;
      } else if (result.contains('❌')) {
        topicData.badCount++;
      } else {
        topicData.goodCount++;
      }
    }
    
    return topics;
  }

  static Future<List<Map<String, dynamic>>> _downloadWeeklyImages(List<Map<String, dynamic>> imageList, int weekNumber) async {
    List<Map<String, dynamic>> downloadedImages = [];
    
    for (int i = 0; i < imageList.length; i++) {
      final imageData = imageList[i];
      try {
        final response = await http.get(Uri.parse(imageData['url'])).timeout(Duration(seconds: 10));
        if (response.statusCode == 200) {
          downloadedImages.add({
            'imageBytes': response.bodyBytes,
            'area': imageData['area'],
            'detail': imageData['detail'],
            'detail2': imageData['detail2'],
            'date': imageData['date'],
            'location': imageData['location'],
          });
        }
      } catch (e) {
        print('Error downloading image for week $weekNumber: $e');
        downloadedImages.add({
          'imageBytes': null,
          'area': imageData['area'],
          'detail': imageData['detail'],
          'detail2': imageData['detail2'],
          'date': imageData['date'],
          'location': imageData['location'],
        });
      }
    }
    
    return downloadedImages;
  }

  static pw.Widget _buildWeeklyChart(pw.Font ttf, List<WeeklyData> weeklyData) {
  if (weeklyData.isEmpty) return pw.Container();

  final maxReports = weeklyData.map((w) => w.totalReports).reduce(max).toDouble();
  final maxImages = weeklyData.map((w) => w.imageCount).reduce(max).toDouble();
  final maxValue = max(maxReports, maxImages);
  
  // Ensure minimum scale to avoid division by zero
  final chartMaxValue = maxValue > 0 ? maxValue : 1.0;

  return pw.Container(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Chart title
        pw.Text(
          'Biểu đồ tiến độ theo tuần',
          style: pw.TextStyle(
            font: ttf,
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 15),
        
        // Horizontal bars
        ...weeklyData.map((week) {
          final reportsWidth = (week.totalReports / chartMaxValue) * 300; // 300 is max bar width
          final imagesWidth = (week.imageCount / chartMaxValue) * 300;
          
          // Ensure minimum visible width for non-zero values
          final minBarWidth = 5.0;
          final adjustedReportsWidth = week.totalReports > 0 
              ? max(reportsWidth, minBarWidth) 
              : 0.0;
          final adjustedImagesWidth = week.imageCount > 0 
              ? max(imagesWidth, minBarWidth) 
              : 0.0;

          return pw.Container(
            margin: pw.EdgeInsets.only(bottom: 20),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Week label
                pw.Container(
                  width: 80,
                  child: pw.Text(
                    'Tuần ${week.weekNumber}',
                    style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                
                pw.SizedBox(width: 15),
                
                // Bars container
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Reports bar
                      pw.Container(
                        margin: pw.EdgeInsets.only(bottom: 5),
                        child: pw.Row(
                          children: [
                            pw.Container(
                              width: adjustedReportsWidth,
                              height: 20,
                              decoration: pw.BoxDecoration(
                                color: PdfColors.blue500,
                                borderRadius: pw.BorderRadius.circular(3),
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Text(
                              'Báo cáo: ${week.totalReports}',
                              style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.blue700),
                            ),
                          ],
                        ),
                      ),
                      
                      // Images bar
                      pw.Row(
                        children: [
                          pw.Container(
                            width: adjustedImagesWidth,
                            height: 20,
                            decoration: pw.BoxDecoration(
                              color: PdfColors.green500,
                              borderRadius: pw.BorderRadius.circular(3),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            'Hình ảnh: ${week.imageCount}',
                            style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.green700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        
        pw.SizedBox(height: 15),
        
        // Summary
        pw.Container(
          padding: pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Tổng quan:',
                      style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Tổng báo cáo: ${weeklyData.fold<int>(0, (sum, week) => sum + week.totalReports)}',
                      style: pw.TextStyle(font: ttf, fontSize: 10),
                    ),
                    pw.Text(
                      'Tổng hình ảnh: ${weeklyData.fold<int>(0, (sum, week) => sum + week.imageCount)}',
                      style: pw.TextStyle(font: ttf, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

 static pw.Widget _buildTopicCountBarChart(pw.Font ttf, Map<String, TopicData> topicData) {
   final sortedTopics = topicData.values.toList()..sort((a, b) => b.totalCount.compareTo(a.totalCount));
   final totalCount = sortedTopics.fold<int>(0, (sum, topic) => sum + topic.totalCount);
   
   if (totalCount == 0) return pw.Container();
   
   List<TopicData> displayTopics = [];
   int otherCount = 0;
   
   for (var topic in sortedTopics) {
     final percentage = (topic.totalCount / totalCount) * 100;
     if (percentage >= 2.0 && displayTopics.length < 6) {
       displayTopics.add(topic);
     } else {
       otherCount += topic.totalCount;
     }
   }
   
   if (otherCount > 0) {
     displayTopics.add(TopicData(name: 'Khác', totalCount: otherCount));
   }
   
   final colors = [
     PdfColors.blue500, PdfColors.green500, PdfColors.orange500, 
     PdfColors.purple500, PdfColors.red500, PdfColors.teal500,
     PdfColors.amber500, PdfColors.grey500
   ];
   
   return pw.Column(
     crossAxisAlignment: pw.CrossAxisAlignment.start,
     children: [
       pw.Container(
         height: 40,
         width: double.infinity,
         decoration: pw.BoxDecoration(
           border: pw.Border.all(color: PdfColors.grey400),
         ),
         child: pw.Row(
           children: displayTopics.asMap().entries.map((entry) {
             final index = entry.key;
             final topic = entry.value;
             final widthPercentage = topic.totalCount / totalCount;
             
             return pw.Expanded(
               flex: (widthPercentage * 1000).round(),
               child: pw.Container(
                 color: colors[index % colors.length],
                 child: pw.Center(
                   child: pw.Text(
                     '${(widthPercentage * 100).toStringAsFixed(0)}%',
                     style: pw.TextStyle(
                       font: ttf, 
                       fontSize: 10, 
                       color: PdfColors.white,
                       fontWeight: pw.FontWeight.bold,
                     ),
                   ),
                 ),
               ),
             );
           }).toList(),
         ),
       ),
       
       pw.SizedBox(height: 15),
       
       pw.Wrap(
         spacing: 15,
         runSpacing: 8,
         children: displayTopics.asMap().entries.map((entry) {
           final index = entry.key;
           final topic = entry.value;
           final percentage = (topic.totalCount / totalCount * 100).toStringAsFixed(1);
           
           return pw.Container(
             width: 160,
             child: pw.Row(
               children: [
                 pw.Container(
                   width: 12,
                   height: 8,
                   color: colors[index % colors.length],
                 ),
                 pw.SizedBox(width: 8),
                 pw.Expanded(
                   child: pw.Text(
                     '${topic.name}: $percentage%',
                     style: pw.TextStyle(font: ttf, fontSize: 10),
                   ),
                 ),
               ],
             ),
           );
         }).toList(),
       ),
       
       pw.SizedBox(height: 15),
       pw.Container(
         padding: pw.EdgeInsets.all(12),
         decoration: pw.BoxDecoration(
           color: PdfColors.blue50,
         ),
         child: pw.Text(
           'Tổng cộng: $totalCount báo cáo',
           style: pw.TextStyle(
             font: ttf, 
             fontSize: 12, 
             fontWeight: pw.FontWeight.bold,
             color: PdfColors.blue700,
           ),
         ),
       ),
     ],
   );
 }

 static pw.Widget _buildEffectivenessBarChart(pw.Font ttf, Map<String, TopicData> topicData) {
   final totalGood = topicData.values.fold<int>(0, (sum, topic) => sum + topic.goodCount);
   final totalWarning = topicData.values.fold<int>(0, (sum, topic) => sum + topic.warningCount);
   final totalBad = topicData.values.fold<int>(0, (sum, topic) => sum + topic.badCount);
   final total = totalGood + totalWarning + totalBad;
   
   if (total == 0) return pw.Container();
   
   return pw.Column(
     crossAxisAlignment: pw.CrossAxisAlignment.start,
     children: [
       pw.Container(
         height: 40,
         width: double.infinity,
         decoration: pw.BoxDecoration(
           border: pw.Border.all(color: PdfColors.grey400),
         ),
         child: pw.Row(
           children: [
             if (totalGood > 0)
               pw.Expanded(
                 flex: totalGood,
                 child: pw.Container(
                   color: PdfColors.green500,
                   child: pw.Center(
                     child: pw.Text(
                       '${(totalGood / total * 100).toStringAsFixed(0)}%',
                       style: pw.TextStyle(
                         font: ttf, 
                         fontSize: 12, 
                         color: PdfColors.white,
                         fontWeight: pw.FontWeight.bold,
                       ),
                     ),
                   ),
                 ),
               ),
             if (totalWarning > 0)
               pw.Expanded(
                 flex: totalWarning,
                 child: pw.Container(
                   color: PdfColors.orange500,
                   child: pw.Center(
                     child: pw.Text(
                       '${(totalWarning / total * 100).toStringAsFixed(0)}%',
                       style: pw.TextStyle(
                         font: ttf, 
                         fontSize: 12, 
                         color: PdfColors.white,
                         fontWeight: pw.FontWeight.bold,
                       ),
                     ),
                   ),
                 ),
               ),
             if (totalBad > 0)
               pw.Expanded(
                 flex: totalBad,
                 child: pw.Container(
                   color: PdfColors.red500,
                   child: pw.Center(
                     child: pw.Text(
                       '${(totalBad / total * 100).toStringAsFixed(0)}%',
                       style: pw.TextStyle(
                         font: ttf, 
                         fontSize: 12, 
                         color: PdfColors.white,
                         fontWeight: pw.FontWeight.bold,
                       ),
                     ),
                   ),
                 ),
               ),
           ],
         ),
       ),
       
       pw.SizedBox(height: 15),
       
       pw.Row(
         children: [
           if (totalGood > 0) ...[
             pw.Container(width: 12, height: 8, color: PdfColors.green500),
             pw.SizedBox(width: 8),
             pw.Text(
               'Tốt: ${(totalGood / total * 100).toStringAsFixed(1)}% ($totalGood)',
               style: pw.TextStyle(font: ttf, fontSize: 10),
             ),
             pw.SizedBox(width: 20),
           ],
           if (totalWarning > 0) ...[
             pw.Container(width: 12, height: 8, color: PdfColors.orange500),
             pw.SizedBox(width: 8),
             pw.Text(
               'Cảnh báo: ${(totalWarning / total * 100).toStringAsFixed(1)}% ($totalWarning)',
               style: pw.TextStyle(font: ttf, fontSize: 10),
             ),
             pw.SizedBox(width: 20),
           ],
           if (totalBad > 0) ...[
             pw.Container(width: 12, height: 8, color: PdfColors.red500),
             pw.SizedBox(width: 8),
             pw.Text(
               'Xấu: ${(totalBad / total * 100).toStringAsFixed(1)}% ($totalBad)',
               style: pw.TextStyle(font: ttf, fontSize: 10),
             ),
           ],
         ],
       ),
       
       pw.SizedBox(height: 15),
       pw.Container(
         padding: pw.EdgeInsets.all(12),
         decoration: pw.BoxDecoration(
           color: PdfColors.green50,
         ),
         child: pw.Text(
           'Tổng cộng: $total kết quả',
           style: pw.TextStyle(
             font: ttf, 
             fontSize: 12, 
             fontWeight: pw.FontWeight.bold,
             color: PdfColors.green700,
           ),
         ),
       ),
     ],
   );
 }

 static List<pw.Widget> _buildWeeklyImagesGrid(pw.Font ttf, List<Map<String, dynamic>> images) {
   List<pw.Widget> widgets = [];
   
   for (int i = 0; i < images.length; i += 2) {
     List<pw.Widget> rowImages = [];
     
     for (int j = i; j < min(i + 2, images.length); j++) {
       final imageData = images[j];
       rowImages.add(
         pw.Expanded(
           child: pw.Container(
             margin: pw.EdgeInsets.all(8),
             decoration: pw.BoxDecoration(
               border: pw.Border.all(color: PdfColors.grey300),
               borderRadius: pw.BorderRadius.circular(8),
             ),
             child: pw.Column(
               crossAxisAlignment: pw.CrossAxisAlignment.start,
               children: [
                 pw.Container(
                   height: 150,
                   width: double.infinity,
                   child: imageData['imageBytes'] != null
                       ? pw.ClipRRect(
                           //borderRadius: pw.BorderRadius.only(
                           //  topLeft: pw.Radius.circular(8),
                           //  topRight: pw.Radius.circular(8),
                           //),
                           child: pw.Image(
                             pw.MemoryImage(imageData['imageBytes']),
                             fit: pw.BoxFit.cover,
                           ),
                         )
                       : pw.Container(
                           decoration: pw.BoxDecoration(
                             color: PdfColors.grey200,
                             //borderRadius: pw.BorderRadius.only(
                             //  topLeft: pw.Radius.circular(8),
                            //   topRight: pw.Radius.circular(8),
                            // ),
                           ),
                           child: pw.Center(
                             child: pw.Text(
                               'Không thể tải hình ảnh',
                               style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey600),
                               textAlign: pw.TextAlign.center,
                             ),
                           ),
                         ),
                 ),
                 
                 pw.Padding(
                   padding: pw.EdgeInsets.all(8),
                   child: pw.Column(
                     crossAxisAlignment: pw.CrossAxisAlignment.start,
                     children: [
                       if (imageData['area'].toString().isNotEmpty)
                         pw.Text(
                           'Khu vực: ${imageData['area']}',
                           style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold),
                         ),
                       pw.Text(
                         DateFormat('dd/MM/yyyy').format(imageData['date']),
                         style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey600),
                       ),
                       if (imageData['detail'].toString().isNotEmpty)
                         pw.Container(
                           margin: pw.EdgeInsets.only(top: 4),
                           child: pw.Text(
                             imageData['detail'],
                             style: pw.TextStyle(font: ttf, fontSize: 9),
                             maxLines: 2,
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
     
     if (rowImages.length == 1) {
       rowImages.add(pw.Expanded(child: pw.Container()));
     }
     
     widgets.add(
       pw.Row(
         crossAxisAlignment: pw.CrossAxisAlignment.start,
         children: rowImages,
       ),
     );
     
     if (i + 2 < images.length) {
       widgets.add(pw.SizedBox(height: 15));
     }
   }
   
   return widgets;
 }

 static int _getWeekNumber(DateTime date) {
   final startOfYear = DateTime(date.year, 1, 1);
   final dayOfYear = date.difference(startOfYear).inDays + 1;
   return ((dayOfYear - 1) / 7).floor() + 1;
 }

 static DateTime _getStartOfWeek(DateTime date) {
   final daysFromMonday = date.weekday - 1;
   return date.subtract(Duration(days: daysFromMonday));
 }

 static DateTime _getEndOfWeek(DateTime date) {
   final daysToSunday = 7 - date.weekday;
   return date.add(Duration(days: daysToSunday));
 }

 static Future<void> openFile(String filePath) async {
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
   }
 }
}

class WeeklyData {
 final int weekNumber;
 final DateTime startDate;
 final DateTime endDate;
 int totalReports;
 int imageCount;
 int goodResults;
 int warningResults;
 int badResults;
 List<Map<String, dynamic>> images;

 WeeklyData({
   required this.weekNumber,
   required this.startDate,
   required this.endDate,
   this.totalReports = 0,
   this.imageCount = 0,
   this.goodResults = 0,
   this.warningResults = 0,
   this.badResults = 0,
   required this.images,
 });
}

class TopicData {
 final String name;
 int totalCount;
 int goodCount;
 int warningCount;
 int badCount;

 TopicData({
   required this.name,
   this.totalCount = 0,
   this.goodCount = 0,
   this.warningCount = 0,
   this.badCount = 0,
 });
}