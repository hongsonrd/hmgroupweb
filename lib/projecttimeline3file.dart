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

class ProjectTimeline3FileGenerator {
  static Future<String?> generateReport({
    required String projectName,
    required DateTime selectedMonth,
    required String username,
    required List<dynamic> imageCountData,
  }) async {
    try {
      // Load Vietnamese font and logo
      final fontData = await rootBundle.load('assets/fonts/RobotoCondensed-Regular.ttf');
      final ttf = pw.Font.ttf(fontData);
      
      final logoData = await rootBundle.load('assets/logo.png');
      final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

      // Get detailed data for analysis
      final detailedData = await _getDetailedReportData(projectName, selectedMonth);
      
      // Create PDF document
      final pdf = pw.Document();

      // Format data for report
      final monthYear = DateFormat('MM/yyyy').format(selectedMonth);
      final reportDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
      
      // Calculate statistics
      final weeklyData = _groupDataByWeek(detailedData);
      final topicData = _analyzeTopics(detailedData);
      final weeklyImages = await _getWeeklyImages(detailedData);

      // Add pages to PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header with logo and company info
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
                    // Logo
                    pw.Container(
                      width: 80,
                      height: 80,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(width: 20),
                    // Company info and title
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'CÔNG TY TNHH HOÀN MỸ',
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Text(
                            'BÁO CÁO DỊCH VỤ THÁNG $monthYear',
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            'Ngày báo cáo: $reportDate',
                            style: pw.TextStyle(font: ttf, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Combined greeting and project name
              pw.Text(
                'Kính gửi Ban lãnh đạo công ty, Ban quản lý dự án. Dự án: $projectName',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 14,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),

              pw.SizedBox(height: 20),

              // Explanatory text
              pw.Container(
                padding: pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.blue200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Báo cáo này bao gồm các phần chính sau:',
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      '• Tổng quan tiến độ theo tuần: Biểu đồ cột thể hiện số lượng báo cáo và hình ảnh mỗi tuần',
                      style: pw.TextStyle(font: ttf, fontSize: 12),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '• Phân tích theo chủ đề: Biểu đồ thanh ngang thể hiện phân bố công việc và hiệu quả thực hiện',
                      style: pw.TextStyle(font: ttf, fontSize: 12),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '• Hình ảnh minh họa: Các hình ảnh thực tế từ hiện trường được tổ chức theo tuần',
                      style: pw.TextStyle(font: ttf, fontSize: 12),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 25),

              // Weekly progress chart
              pw.Text(
                'TỔNG QUAN TIẾN ĐỘ THEO TUẦN',
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

              // Topics analysis with horizontal bar charts
              if (topicData.isNotEmpty) ...[
                pw.Text(
                  'PHÂN TÍCH THEO CHỦ ĐỀ BÁO CÁO',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 15),
                
                // Topic count and effectiveness horizontal bar charts
                _buildTopicCountBarChart(ttf, topicData),

pw.SizedBox(height: 25),

_buildEffectivenessBarChart(ttf, topicData),
                
                pw.SizedBox(height: 30),
                
                // Summary statistics table to fill space
                pw.Text(
                  'TỔNG KẾT THỐNG KÊ',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 15),
                
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.blue100),
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(12),
                          child: pw.Text('Chỉ tiêu', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(12),
                          child: pw.Text('Giá trị', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(12),
                          child: pw.Text('Tổng số tuần có hoạt động', style: pw.TextStyle(font: ttf)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(12),
                          child: pw.Text('${weeklyData.length} tuần', style: pw.TextStyle(font: ttf)),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(12),
                          child: pw.Text('Tổng số báo cáo trong tháng', style: pw.TextStyle(font: ttf)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(12),
child: pw.Text('${weeklyData.fold<int>(0, (sum, week) => sum + week.totalReports)} báo cáo', style: pw.TextStyle(font: ttf)),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(12),
                          child: pw.Text('Tổng số hình ảnh minh họa', style: pw.TextStyle(font: ttf)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(12),
child: pw.Text('${weeklyData.fold<int>(0, (sum, week) => sum + week.imageCount)} hình ảnh', style: pw.TextStyle(font: ttf)),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(12),
                          child: pw.Text('Số chủ đề công việc đã thực hiện', style: pw.TextStyle(font: ttf)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(12),
                          child: pw.Text('${topicData.length} chủ đề', style: pw.TextStyle(font: ttf)),
                        ),
                      ],
                    ),
                  ],
                ),
                
                pw.SizedBox(height: 25),
              ],
            ];
          },
        ),
      );

      // Add weekly images pages
      for (int weekIndex = 0; weekIndex < weeklyImages.length; weekIndex++) {
        final weekData = weeklyImages[weekIndex];
        if (weekData['images'].isNotEmpty) {
          final downloadedImages = await _downloadWeeklyImages(weekData['images'], weekIndex + 1);
          
          pdf.addPage(
            pw.MultiPage(
              pageFormat: PdfPageFormat.a4,
              margin: pw.EdgeInsets.all(32),
              build: (pw.Context context) {
                return [
                  // Week header
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
                          'HÌNH ẢNH MINH HỌA CÔNG VIỆC - TUẦN ${weekData['weekNumber']}',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.Spacer(),
                        pw.Text(
                          '(${DateFormat('dd/MM').format(weekData['startDate'])} - ${DateFormat('dd/MM').format(weekData['endDate'])})',
                          style: pw.TextStyle(font: ttf, fontSize: 12, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                  
                  pw.SizedBox(height: 20),
                  
                  // Images grid
                  ..._buildWeeklyImagesGrid(ttf, downloadedImages),
                ];
              },
            ),
          );
        }
      }

      // Save PDF to file
      final directory = await getApplicationDocumentsDirectory();
      final reportFolder = Directory('${directory.path}/BaoCao_DuAn');
      
      if (!await reportFolder.exists()) {
        await reportFolder.create(recursive: true);
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final sanitizedProjectName = projectName.replaceAll(RegExp(r'[^\w\s-]'), '');
      final fileName = 'BaoCao_${sanitizedProjectName}_${monthYear.replaceAll('/', '-')}_$timestamp.pdf';
      final filePath = '${reportFolder.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      return filePath;
    } catch (e) {
      print('Error generating PDF report: $e');
      return null;
    }
  }

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
          weekData.goodResults++; // Default to good if no emoji
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
        topicData.goodCount++; // Default to good
      }
    }
    
    return topics;
  }

  static Future<List<Map<String, dynamic>>> _getWeeklyImages(List<Map<String, dynamic>> data) async {
    Map<int, Map<String, dynamic>> weeklyImages = {};
    
    for (var item in data) {
      if (item['HinhAnh'] != null && item['HinhAnh'].toString().isNotEmpty) {
        try {
          final date = DateTime.parse(item['Ngay']);
          final weekNumber = _getWeekNumber(date);
          
          if (!weeklyImages.containsKey(weekNumber)) {
            weeklyImages[weekNumber] = {
              'weekNumber': weekNumber,
              'startDate': _getStartOfWeek(date),
              'endDate': _getEndOfWeek(date),
              'images': <Map<String, dynamic>>[],
            };
          }
          
          weeklyImages[weekNumber]!['images'].add({
            'url': item['HinhAnh'],
            'area': item['GiaiPhap'] ?? '',
            'detail': item['ChiTiet'] ?? '',
            'detail2': item['ChiTiet2'] ?? '',
            'date': date,
            'location': item['ViTri'] ?? '',
            'topic': item['PhanLoai'] ?? '',
          });
        } catch (e) {
          print('Error processing image for week grouping: $e');
        }
      }
    }
    
    // Improved image selection for diversity
    for (var weekData in weeklyImages.values) {
      final images = weekData['images'] as List<Map<String, dynamic>>;
      weekData['images'] = _selectDiverseImages(images, 10);
    }
    
    return weeklyImages.values.toList()..sort((a, b) => a['weekNumber'].compareTo(b['weekNumber']));
  }

  // Improved image selection for diversity
  static List<Map<String, dynamic>> _selectDiverseImages(List<Map<String, dynamic>> allImages, int maxCount) {
    if (allImages.length <= maxCount) return allImages;
    
    // Group images by date
    Map<String, List<Map<String, dynamic>>> imagesByDate = {};
    for (var image in allImages) {
      final dateKey = DateFormat('yyyy-MM-dd').format(image['date']);
      if (!imagesByDate.containsKey(dateKey)) {
        imagesByDate[dateKey] = [];
      }
      imagesByDate[dateKey]!.add(image);
    }
    
    // Group by area/topic for further diversity
    Map<String, List<Map<String, dynamic>>> imagesByArea = {};
    for (var image in allImages) {
      final areaKey = image['area'].toString().isEmpty ? image['topic'].toString() : image['area'].toString();
      if (!imagesByArea.containsKey(areaKey)) {
        imagesByArea[areaKey] = [];
      }
      imagesByArea[areaKey]!.add(image);
    }
    
    List<Map<String, dynamic>> selectedImages = [];
    Set<String> usedDates = {};
    Set<String> usedAreas = {};
    
    // Sort dates to ensure chronological distribution
    final sortedDates = imagesByDate.keys.toList()..sort();
    final sortedAreas = imagesByArea.keys.toList();
    
    // First pass: Select one image from each date, prioritizing different areas
    for (String dateKey in sortedDates) {
      if (selectedImages.length >= maxCount) break;
      
      final dateImages = imagesByDate[dateKey]!;
      // Sort by area diversity
      dateImages.sort((a, b) {
        final aArea = a['area'].toString().isEmpty ? a['topic'].toString() : a['area'].toString();
        final bArea = b['area'].toString().isEmpty ? b['topic'].toString() : b['area'].toString();
        
        // Prioritize unused areas
        if (!usedAreas.contains(aArea) && usedAreas.contains(bArea)) return -1;
        if (usedAreas.contains(aArea) && !usedAreas.contains(bArea)) return 1;
        
        // Then by detail length (more detailed descriptions preferred)
        return b['detail'].toString().length.compareTo(a['detail'].toString().length);
      });
      
      final selectedImage = dateImages.first;
      selectedImages.add(selectedImage);
      usedDates.add(dateKey);
      
      final area = selectedImage['area'].toString().isEmpty ? selectedImage['topic'].toString() : selectedImage['area'].toString();
      usedAreas.add(area);
    }
    
    // Second pass: Fill remaining slots with diverse images from different areas
    for (String areaKey in sortedAreas) {
      if (selectedImages.length >= maxCount) break;
      
      final areaImages = imagesByArea[areaKey]!;
      for (var image in areaImages) {
        if (selectedImages.length >= maxCount) break;
        
        final dateKey = DateFormat('yyyy-MM-dd').format(image['date']);
        
        // Skip if we already have too many from this date
        final imagesFromThisDate = selectedImages.where((img) => 
          DateFormat('yyyy-MM-dd').format(img['date']) == dateKey).length;
        
        if (imagesFromThisDate < 2 && !selectedImages.contains(image)) {
          selectedImages.add(image);
        }
      }
    }
    
    // Third pass: Fill any remaining slots with quality images
    if (selectedImages.length < maxCount) {
      final remainingImages = allImages.where((img) => !selectedImages.contains(img)).toList();
      remainingImages.sort((a, b) {
        // Sort by detail quality and date diversity
        return b['detail'].toString().length.compareTo(a['detail'].toString().length);
      });
      
      for (var image in remainingImages) {
        if (selectedImages.length >= maxCount) break;
        selectedImages.add(image);
      }
    }
    
    // Final sort by date for chronological order
    selectedImages.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    
    return selectedImages.take(maxCount).toList();
  }

  static Future<List<Map<String, dynamic>>> _downloadWeeklyImages(List<Map<String, dynamic>> imageList, int weekNumber) async {
    List<Map<String, dynamic>> downloadedImages = [];
    
    for (int i = 0; i < imageList.length && i < 10; i++) {
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
        // Add placeholder for failed downloads
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
  
  return pw.Container(
    height: 300,
    child: pw.Column(
      children: [
        // Chart area
        pw.Expanded(
          child: pw.Container(
            padding: pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                // Chart with gridlines and bars
                pw.Container(
                  height: 220,
                  child: pw.Stack(
                    children: [
                      // Horizontal gridlines WITHOUT numbers
                      pw.Positioned.fill(
                        child: pw.Column(
                          children: List.generate(5, (index) {
                            return pw.Expanded(
                              child: pw.Container(
                                decoration: pw.BoxDecoration(
                                  border: pw.Border(
                                    top: pw.BorderSide(
                                      color: index == 4 ? PdfColors.grey600 : PdfColors.grey300,
                                      width: index == 4 ? 1 : 0.5,
                                    ),
                                  ),
                                ),
                                // No text/numbers here - just empty gridlines
                              ),
                            );
                          }),
                        ),
                      ),
                      
                      // Chart bars
                      pw.Positioned.fill(
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: weeklyData.map((week) {
                            final chartHeight = 180.0;
                            final reportsHeight = maxValue > 0 ? (week.totalReports / maxValue) * chartHeight : 0.0;
                            final imagesHeight = maxValue > 0 ? (week.imageCount / maxValue) * chartHeight : 0.0;
                            
                            return pw.Expanded(
                              child: pw.Container(
                                margin: pw.EdgeInsets.symmetric(horizontal: 8),
                                child: pw.Column(
                                  mainAxisAlignment: pw.MainAxisAlignment.end,
                                  children: [
                                    // Numbers on top of bars
                                    pw.Container(
                                      height: 30,
                                      child: pw.Column(
                                        mainAxisAlignment: pw.MainAxisAlignment.end,
                                        children: [
                                          if (week.totalReports > 0)
                                            pw.Text(
                                              '${week.totalReports}',
                                              style: pw.TextStyle(font: ttf, fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
                                            ),
                                          if (week.imageCount > 0)
                                            pw.Text(
                                              '${week.imageCount}',
                                              style: pw.TextStyle(font: ttf, fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green700),
                                            ),
                                        ],
                                      ),
                                    ),
                                    
                                    pw.SizedBox(height: 5),
                                    
                                    // Bars
                                    pw.Row(
                                      mainAxisAlignment: pw.MainAxisAlignment.center,
                                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                                      children: [
                                        // Reports bar
                                        pw.Container(
                                          width: 25,
                                          height: reportsHeight,
                                          color: PdfColors.blue500,
                                        ),
                                        pw.SizedBox(width: 6),
                                        // Images bar
                                        pw.Container(
                                          width: 25,
                                          height: imagesHeight,
                                          color: PdfColors.green500,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 10),
                
                // Week labels
                pw.Row(
                  children: weeklyData.map((week) {
                    return pw.Expanded(
                      child: pw.Text(
                        'Tuần ${week.weekNumber}',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: ttf, fontSize: 10),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        
        pw.SizedBox(height: 10),
        
        // Legend
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Container(width: 20, height: 10, color: PdfColors.blue500),
            pw.SizedBox(width: 5),
            pw.Text('Báo cáo', style: pw.TextStyle(font: ttf, fontSize: 12)),
            pw.SizedBox(width: 30),
            pw.Container(width: 20, height: 10, color: PdfColors.green500),
            pw.SizedBox(width: 5),
            pw.Text('Hình ảnh', style: pw.TextStyle(font: ttf, fontSize: 12)),
          ],
        ),
      ],
    ),
  );
}

 static pw.Widget _buildTopicCountBarChart(pw.Font ttf, Map<String, TopicData> topicData) {
  final sortedTopics = topicData.values.toList()..sort((a, b) => b.totalCount.compareTo(a.totalCount));
final totalCount = sortedTopics.fold<int>(0, (sum, topic) => sum + topic.totalCount);
  
  if (totalCount == 0) return pw.Container();
  
  // Group small percentages into "Khác"
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
  
  // Add "Khác" if there are small percentages
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
      pw.Text(
        'PHÂN BỐ THEO CHỦ ĐỀ',
        style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
      ),
      pw.SizedBox(height: 15),
      
      // Horizontal stacked bar - square ends
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
      
      // Legend in grid layout
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
      
      // Total count
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
      pw.Text(
        'HIỆU QUẢ TỔNG THỂ',
        style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
      ),
      pw.SizedBox(height: 15),
      
      // Horizontal stacked bar - square ends
      pw.Container(
        height: 40,
        width: double.infinity,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
        ),
        child: pw.Row(
          children: [
            // Good results
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
            // Warning results
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
            // Bad results
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
      
      // Legend
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
      
      // Total count
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
   
   // Group images in rows of 2
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
                 // Image
                 pw.Container(
                   height: 150,
                   width: double.infinity,
                   child: imageData['imageBytes'] != null
                       ? pw.Image(
                           pw.MemoryImage(imageData['imageBytes']),
                           fit: pw.BoxFit.cover,
                         )
                       : pw.Container(
                           color: PdfColors.grey200,
                           child: pw.Center(
                             child: pw.Text(
                               'Không thể tải hình ảnh',
                               style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey600),
                               textAlign: pw.TextAlign.center,
                             ),
                           ),
                         ),
                 ),
                 
                 // Image info
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
     
     // Add empty space if odd number of images
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

 // Helper methods for week calculations
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

// Data classes
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