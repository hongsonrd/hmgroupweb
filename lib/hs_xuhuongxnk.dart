import 'package:flutter/material.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'table_models.dart';
import 'db_helper.dart';

class HSXuHuongXNKScreen extends StatefulWidget {
 const HSXuHuongXNKScreen({Key? key}) : super(key: key);

 @override
 _HSXuHuongXNKScreenState createState() => _HSXuHuongXNKScreenState();
}

class _HSXuHuongXNKScreenState extends State<HSXuHuongXNKScreen> with SingleTickerProviderStateMixin {
  Color _getGrowthColor(double? growth) {
  if (growth == null) return Colors.grey;
  if (growth > 10) return Colors.green;
  if (growth > 0) return Colors.lightGreen;
  if (growth < -10) return Colors.red;
  if (growth < 0) return Colors.orange;
  return Colors.blue;
}
 final DBHelper _dbHelper = DBHelper();
 bool _isLoading = false;
 bool _hasData = false;
 bool _hasDeepAnalysis = false;
 List<Map<String, dynamic>> _trendResults = [];
 Map<String, List<Map<String, dynamic>>> _branchResults = {};
 String _selectedBranch = 'Tất cả';
 List<String> _branches = ['Tất cả'];
 
 Map<String, List<double>> _seasonalData = {};
 Map<String, dynamic> _yoyData = {};
 Map<String, Map<String, dynamic>> _categoryData = {};
 
 late TabController _analysisTabController;
 String _selectedForecastMethod = 'ARIMA';
 List<String> _forecastMethods = ['Simple', 'Moving Average', 'Exponential Smoothing', 'ARIMA', 'Neural Network'];
 int _forecastHorizon = 30;
 bool _includeExternalFactors = true;
 bool _showConfidenceIntervals = true;
 
 Map<String, dynamic> _externalFactors = {
   'economicIndicators': {},
   'holidays': [],
   'weatherData': {},
   'marketTrends': {}
 };
 
 Map<String, Map<String, dynamic>> _forecastCache = {};

 @override
 void initState() {
   super.initState();
   _analysisTabController = TabController(length: 5, vsync: this);
   _loadPreferences();
 }

 Future<void> _loadPreferences() async {
   final prefs = await SharedPreferences.getInstance();
   setState(() {
     _selectedForecastMethod = prefs.getString('forecastMethod') ?? 'ARIMA';
     _forecastHorizon = prefs.getInt('forecastHorizon') ?? 30;
     _includeExternalFactors = prefs.getBool('includeExternalFactors') ?? true;
     _showConfidenceIntervals = prefs.getBool('showConfidenceIntervals') ?? true;
   });
 }

 Future<void> _savePreferences() async {
   final prefs = await SharedPreferences.getInstance();
   await prefs.setString('forecastMethod', _selectedForecastMethod);
   await prefs.setInt('forecastHorizon', _forecastHorizon);
   await prefs.setBool('includeExternalFactors', _includeExternalFactors);
   await prefs.setBool('showConfidenceIntervals', _showConfidenceIntervals);
 }

 @override
 void dispose() {
   _analysisTabController.dispose();
   super.dispose();
 }

 @override
 Widget build(BuildContext context) {
   final Color appBarTop = Color(0xFF534b0d);
   final Color appBarBottom = Color(0xFFb2a41f);
   
   return Scaffold(
     appBar: AppBar(
       title: Text(
         'Dự đoán xu hướng hàng (theo khoảng số ngày lựa chọn)',
         style: TextStyle(
          color: Colors.white,
           fontSize: 18,
           fontWeight: FontWeight.w600,
           letterSpacing: 0.5,
         ),
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
       leading: IconButton(
         icon: Icon(Icons.arrow_back),
         onPressed: () => Navigator.of(context).pop(),
       ),
       actions: [
         if (_hasData)
           TextButton.icon(
             icon: Icon(Icons.analytics_outlined, color: Colors.white),
             label: Text(
               'Phân tích sâu',
               style: TextStyle(color: Colors.white),
             ),
             onPressed: () {
               _showDeepAnalysisDialog();
             },
           ),
         IconButton(
           icon: Icon(Icons.settings),
           onPressed: () {
             _showSettingsDialog();
           },
         ),
       ],
     ),
     body: _isLoading 
         ? _buildLoadingView() 
         : _hasData 
             ? _buildResultsView() 
             : _buildInitialView(),
     floatingActionButton: _hasData ? FloatingActionButton(
       onPressed: () {
         _showExportDialog();
       },
       backgroundColor: Colors.orange,
       child: Icon(Icons.share),
     ) : null,
   );
 }

 Widget _buildInitialView() {
   return Center(
     child: Column(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
         Icon(
           Icons.trending_up,
           size: 80,
           color: Colors.orange,
         ),
         SizedBox(height: 24),
         Text(
           'Dự đoán xu hướng hàng',
           style: TextStyle(
             fontSize: 24,
             fontWeight: FontWeight.bold,
             color: Colors.orange,
           ),
         ),
         SizedBox(height: 16),
         Padding(
           padding: const EdgeInsets.symmetric(horizontal: 32.0),
           child: Text(
             'Tính năng này giúp phân tích và dự báo xu hướng tiêu thụ hàng hóa dựa trên dữ liệu lịch sử',
             textAlign: TextAlign.center,
             style: TextStyle(
               fontSize: 16,
               color: Colors.grey[600],
             ),
           ),
         ),
         SizedBox(height: 40),
         ElevatedButton(
           onPressed: () {
             _showForecastOptionsDialog();
           },
           style: ElevatedButton.styleFrom(
             backgroundColor: Colors.orange,
             padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
           ),
           child: Text(
             'Khám phá xu hướng',
             style: TextStyle(fontSize: 16),
           ),
         ),
         SizedBox(height: 16),
         TextButton(
           onPressed: () {
             _showImportDialog();
           },
           child: Text(
             'Nhập dữ liệu từ nguồn ngoài',
             style: TextStyle(
               color: Colors.grey[600],
             ),
           ),
         ),
       ],
     ),
   );
 }

 Widget _buildLoadingView() {
   return Center(
     child: Column(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
         CircularProgressIndicator(color: Colors.orange),
         SizedBox(height: 24),
         Text(
           'Đang phân tích dữ liệu...',
           style: TextStyle(
             fontSize: 18,
             color: Colors.grey[700],
           ),
         ),
         SizedBox(height: 8),
         Text(
           'Vui lòng đợi trong giây lát',
           style: TextStyle(
             fontSize: 14,
             color: Colors.grey[500],
           ),
         ),
       ],
     ),
   );
 }

 Widget _buildResultsView() {
   return Column(
     children: [
       Container(
         padding: EdgeInsets.all(16),
         color: Colors.grey[100],
         child: Row(
           children: [
             Text('Chi nhánh:', style: TextStyle(fontWeight: FontWeight.bold)),
             SizedBox(width: 16),
             Expanded(
               child: DropdownButton<String>(
                 value: _selectedBranch,
                 isExpanded: true,
                 onChanged: (String? newValue) {
                   if (newValue != null) {
                     setState(() {
                       _selectedBranch = newValue;
                     });
                   }
                 },
                 items: _branches.map((String branch) {
                   return DropdownMenuItem<String>(
                     value: branch,
                     child: Text(branch),
                   );
                 }).toList(),
               ),
             ),
           ],
         ),
       ),
       Expanded(
         child: _selectedBranch == 'Tất cả'
             ? _buildOverallResults()
             : _buildBranchResults(_selectedBranch),
       ),
     ],
   );
 }

 Widget _buildOverallResults() {
   return ListView.builder(
     padding: EdgeInsets.all(16),
     itemCount: _trendResults.length,
     itemBuilder: (context, index) {
       final item = _trendResults[index];
       
       return Card(
         margin: EdgeInsets.only(bottom: 16),
         child: InkWell(
           onTap: () {
             _showProductDetailDialog(item);
           },
           child: Padding(
             padding: EdgeInsets.all(16),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Container(
                       padding: EdgeInsets.all(8),
                       decoration: BoxDecoration(
                         color: Colors.orange[100],
                         borderRadius: BorderRadius.circular(8),
                       ),
                       child: Icon(
                         Icons.trending_up,
                         color: Colors.orange[800],
                         size: 24,
                       ),
                     ),
                     SizedBox(width: 16),
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(
                             item['product_name'] ?? 'Sản phẩm',
                             style: TextStyle(
                               fontSize: 18,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                           SizedBox(height: 4),
                           Text(
                             'Danh mục: ${item['category'] ?? 'Không phân loại'}',
                             style: TextStyle(
                               fontSize: 14,
                               color: Colors.grey[600],
                             ),
                           ),
                           Text(
                             'Thương hiệu: ${item['brand'] ?? 'Không xác định'}',
                             style: TextStyle(
                               fontSize: 14,
                               color: Colors.grey[600],
                             ),
                           ),
                         ],
                       ),
                     ),
                     Container(
                       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                       decoration: BoxDecoration(
                         color: _getTrendColor(item['trend_score']).withOpacity(0.1),
                         borderRadius: BorderRadius.circular(4),
                       ),
                       child: Text(
                         _getTrendLabel(item['trend_score']),
                         style: TextStyle(
                           color: _getTrendColor(item['trend_score']),
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     ),
                   ],
                 ),
                 SizedBox(height: 16),
                 Container(
                   height: 100,
                   child: _buildMiniChart(item),
                 ),
                 SizedBox(height: 16),
                 Row(
                   children: [
                     Expanded(
                       child: _buildStatisticItem(
                         'Lượng bán TB',
                         '${item['avg_quantity']?.toStringAsFixed(1) ?? '0'}',
                         Colors.blue,
                       ),
                     ),
                     Expanded(
                       child: _buildStatisticItem(
                         'Dự đoán',
                         '${item['forecast_quantity']?.toStringAsFixed(1) ?? '0'}',
                         Colors.orange,
                       ),
                     ),
                     Expanded(
                       child: _buildStatisticItem(
                         'Tồn kho',
                         '${item['current_stock']?.toStringAsFixed(1) ?? '0'}',
                         Colors.green,
                       ),
                     ),
                   ],
                 ),
                 SizedBox(height: 16),
                 Container(
                   padding: EdgeInsets.all(12),
                   decoration: BoxDecoration(
                     color: Colors.grey[100],
                     borderRadius: BorderRadius.circular(8),
                   ),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         'Khuyến nghị:',
                         style: TextStyle(fontWeight: FontWeight.bold),
                       ),
                       SizedBox(height: 8),
                       Text(item['recommendation'] ?? 'Không có khuyến nghị'),
                     ],
                   ),
                 ),
               ],
             ),
           ),
         ),
       );
     },
   );
 }

 Widget _buildMiniChart(Map<String, dynamic> item) {
   final List<FlSpot> historySpots = (item['history_data'] as List<double>? ?? [])
       .asMap()
       .entries
       .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
       .toList();
   
   final List<FlSpot> forecastSpots = (item['forecast_data'] as List<double>? ?? [])
       .asMap()
       .entries
       .map((entry) => FlSpot((historySpots.length + entry.key).toDouble(), entry.value))
       .toList();
   
   final List<FlSpot> upperBoundSpots = (item['upper_bound'] as List<double>? ?? [])
       .asMap()
       .entries
       .map((entry) => FlSpot((historySpots.length + entry.key).toDouble(), entry.value))
       .toList();
   
   final List<FlSpot> lowerBoundSpots = (item['lower_bound'] as List<double>? ?? [])
       .asMap()
       .entries
       .map((entry) => FlSpot((historySpots.length + entry.key).toDouble(), entry.value))
       .toList();
   
   return LineChart(
     LineChartData(
       gridData: FlGridData(show: false),
       titlesData: FlTitlesData(show: false),
       borderData: FlBorderData(show: false),
       lineBarsData: [
         LineChartBarData(
           spots: historySpots,
           isCurved: true,
           color: Colors.blue,
           barWidth: 2,
           dotData: FlDotData(show: false),
         ),
         LineChartBarData(
           spots: forecastSpots,
           isCurved: true,
           color: Colors.orange,
           barWidth: 2,
           dotData: FlDotData(show: false),
           dashArray: [5, 5],
         ),
         if (_showConfidenceIntervals)
           LineChartBarData(
             spots: upperBoundSpots,
             isCurved: true,
             color: Colors.orange.withOpacity(0.3),
             barWidth: 1,
             dotData: FlDotData(show: false),
           ),
         if (_showConfidenceIntervals)
           LineChartBarData(
             spots: lowerBoundSpots,
             isCurved: true,
             color: Colors.orange.withOpacity(0.3),
             barWidth: 1,
             dotData: FlDotData(show: false),
           ),
       ],
       lineTouchData: LineTouchData(enabled: false),
     ),
   );
 }

 Widget _buildBranchResults(String branch) {
   final branchData = _branchResults[branch] ?? [];
   
   if (branchData.isEmpty) {
     return Center(
       child: Text(
         'Không có dữ liệu cho chi nhánh này',
         style: TextStyle(
           fontSize: 16,
           color: Colors.grey[600],
         ),
       ),
     );
   }
   
   return ListView.builder(
     padding: EdgeInsets.all(16),
     itemCount: branchData.length,
     itemBuilder: (context, index) {
       final item = branchData[index];
       
       return Card(
         margin: EdgeInsets.only(bottom: 16),
         child: InkWell(
           onTap: () {
             _showProductDetailDialog(item);
           },
           child: Padding(
             padding: EdgeInsets.all(16),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Container(
                       padding: EdgeInsets.all(8),
                       decoration: BoxDecoration(
                         color: Colors.orange[100],
                         borderRadius: BorderRadius.circular(8),
                       ),
                       child: Icon(
                         Icons.trending_up,
                         color: Colors.orange[800],
                         size: 24,
                       ),
                     ),
                     SizedBox(width: 16),
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(
                             item['product_name'] ?? 'Sản phẩm',
                             style: TextStyle(
                               fontSize: 18,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                           SizedBox(height: 4),
                           Text(
                             'Danh mục: ${item['category'] ?? 'Không phân loại'}',
                             style: TextStyle(
                               fontSize: 14,
                               color: Colors.grey[600],
                             ),
                           ),
                         ],
                       ),
                     ),
                     Container(
                       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                       decoration: BoxDecoration(
                         color: _getTrendColor(item['trend_score']).withOpacity(0.1),
                         borderRadius: BorderRadius.circular(4),
                       ),
                       child: Text(
                         _getTrendLabel(item['trend_score']),
                         style: TextStyle(
                           color: _getTrendColor(item['trend_score']),
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     ),
                   ],
                 ),
                 SizedBox(height: 16),
                 Container(
                   height: 100,
                   child: _buildMiniChart(item),
                 ),
                 SizedBox(height: 16),
                 Row(
                   children: [
                     Expanded(
                       child: _buildStatisticItem(
                         'Lượng bán TB',
                         '${item['avg_quantity']?.toStringAsFixed(1) ?? '0'}',
                         Colors.blue,
                       ),
                     ),
                     Expanded(
                       child: _buildStatisticItem(
                         'Dự đoán',
                         '${item['forecast_quantity']?.toStringAsFixed(1) ?? '0'}',
                         Colors.orange,
                       ),
                     ),
                     Expanded(
                       child: _buildStatisticItem(
                         'Tồn kho',
                         '${item['current_stock']?.toStringAsFixed(1) ?? '0'}',
                         Colors.green,
                       ),
                     ),
                   ],
                 ),
                 SizedBox(height: 16),
                 Container(
                   padding: EdgeInsets.all(12),
                   decoration: BoxDecoration(
                     color: Colors.grey[100],
                     borderRadius: BorderRadius.circular(8),
                   ),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         'Khuyến nghị:',
                         style: TextStyle(fontWeight: FontWeight.bold),
                       ),
                       SizedBox(height: 8),
                       Text(item['recommendation'] ?? 'Không có khuyến nghị'),
                     ],
                   ),
                 ),
               ],
             ),
           ),
         ),
       );
     },
   );
 }

 Widget _buildStatisticItem(String label, String value, Color color) {
   return Column(
     children: [
       Text(
         label,
         style: TextStyle(
           fontSize: 12,
           color: Colors.grey[600],
         ),
       ),
       SizedBox(height: 4),
       Text(
         value,
         style: TextStyle(
           fontSize: 18,
           fontWeight: FontWeight.bold,
           color: color,
         ),
       ),
     ],
   );
 }

 void _showForecastOptionsDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Tùy chọn dự báo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description of forecast methods
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '💎Simple: Phương pháp đơn giản theo Naïve, dùng cho các sản phẩm mới bán, ít dữ liệu (dự báo 1-4 tuần)\n'
                '💎MovingAverage: Phương pháp trung bình động, sử dụng cho các sản phẩm biến động mạnh thời gian ngắn (dự báo 1-6 tuần)\n'
                '💎ExponentialSmoothing: Làm mịn theo hàm mũ phù hợp với các sản phẩm hay có tính lặp lại theo mùa, theo thời gian (dự báo 1-3 tháng)\n'
                '💎ARIMA: Phương pháp tiêu chuẩn, dự đoán nhiều chiều (dự báo 1-6 tháng\n'
                '💎NeuralNetwork: Phương pháp thực nghiệm dự đoán sử dụng AI (dự báo 1-12 tháng)\n'
                '💎Bấm 1 điểm trên thanh thời gian để chọn khoảng dự báo (0-90 ngày), dữ liệu dự báo là 800 đơn hàng gần nhất\n'
                'Các nội dung khác:\n'
                '-Độ co giãn theo giá: mức độ biến động của lượng bán tương quan với giá bán\n'
                '-Điểm xu hướng: -100 (xu hướng giảm) > +100 (xu hướng tăng)\n'
                '-Độ tin cậy dự báo: 0-100%, càng cao càng chính xác\n'
                '-Biểu đồ đường xanh = lượng bán lịch sử\n'
                '-Biểu đồ đường vàng = lượng bán dự kiến\n'
                '-1 điểm trên biểu đồ = ngày dự kiến trong tương lai, số dự báo-số dự báo tối đa-số dự báo tối thiểu',
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Phương pháp dự báo:'),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _selectedForecastMethod,
              isExpanded: true,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedForecastMethod = newValue;
                  });
                  Navigator.pop(context);
                  _showForecastOptionsDialog();
                }
              },
              items: _forecastMethods.map((String method) {
                return DropdownMenuItem<String>(
                  value: method,
                  child: Text(method),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Khoảng thời gian dự báo (ngày):'),
            const SizedBox(height: 8),
            Slider(
              value: _forecastHorizon.toDouble(),
              min: 7,
              max: 90,
              divisions: 83,
              label: _forecastHorizon.toString(),
              onChanged: (double value) {
                setState(() {
                  _forecastHorizon = value.toInt();
                });
                Navigator.pop(context);
                _showForecastOptionsDialog();
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Sử dụng yếu tố bên ngoài'),
              subtitle: const Text('Thời tiết, lễ, sự kiện,...'),
              value: _includeExternalFactors,
              onChanged: (bool value) {
                setState(() {
                  _includeExternalFactors = value;
                });
                Navigator.pop(context);
                _showForecastOptionsDialog();
              },
            ),
            SwitchListTile(
              title: const Text('Hiển thị khoảng tin cậy'),
              subtitle: const Text('Dải giá trị dự báo có thể'),
              value: _showConfidenceIntervals,
              onChanged: (bool value) {
                setState(() {
                  _showConfidenceIntervals = value;
                });
                Navigator.pop(context);
                _showForecastOptionsDialog();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Huỷ bỏ'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            _savePreferences();
            _performTrendAnalysis();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
          ),
          child: const Text('Bắt đầu phân tích'),
        ),
      ],
    ),
  );
}

 void _showSettingsDialog() {
   showDialog(
     context: context,
     builder: (context) => AlertDialog(
       title: Text('Cài đặt'),
       content: SingleChildScrollView(
         child: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text('Phương pháp dự báo:'),
             SizedBox(height: 8),
             DropdownButton<String>(
               value: _selectedForecastMethod,
               isExpanded: true,
               onChanged: (String? newValue) {
                 if (newValue != null) {
                   setState(() {
                     _selectedForecastMethod = newValue;
                   });
                 }
               },
               items: _forecastMethods.map((String method) {
                 return DropdownMenuItem<String>(
                   value: method,
                   child: Text(method),
                 );
               }).toList(),
             ),
             SizedBox(height: 16),
             Text('Khoảng thời gian dự báo (ngày): $_forecastHorizon'),
             SizedBox(height: 8),
             Slider(
               value: _forecastHorizon.toDouble(),
               min: 7,
               max: 90,
               divisions: 83,
               label: _forecastHorizon.toString(),
               onChanged: (double value) {
                 setState(() {
                   _forecastHorizon = value.toInt();
                 });
               },
             ),
             SizedBox(height: 16),
             SwitchListTile(
               title: Text('Sử dụng yếu tố bên ngoài'),
               subtitle: Text('Thời tiết, lễ, sự kiện,...'),
               value: _includeExternalFactors,
               onChanged: (bool value) {
                 setState(() {
                   _includeExternalFactors = value;
                 });
               },
             ),
             SwitchListTile(
               title: Text('Hiển thị khoảng tin cậy'),
               subtitle: Text('Dải giá trị dự báo có thể'),
               value: _showConfidenceIntervals,
               onChanged: (bool value) {
                 setState(() {
                   _showConfidenceIntervals = value;
                 });
               },
             ),
           ],
         ),
       ),
       actions: [
         TextButton(
           onPressed: () => Navigator.of(context).pop(),
           child: Text('Huỷ bỏ'),
         ),
         ElevatedButton(
           onPressed: () {
             Navigator.of(context).pop();
             _savePreferences();
             if (_hasData) {
               _performTrendAnalysis();
             }
           },
           style: ElevatedButton.styleFrom(
             backgroundColor: Colors.orange,
           ),
           child: Text('Lưu cài đặt'),
         ),
       ],
     ),
   );
 }

 void _showProductDetailDialog(Map<String, dynamic> product) {
   showDialog(
     context: context,
     builder: (context) => Dialog(
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(12),
       ),
       insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
       child: Container(
         width: double.maxFinite,
         height: MediaQuery.of(context).size.height * 0.8,
         padding: EdgeInsets.all(16),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Expanded(
                   child: Text(
                     product['product_name'] ?? 'Chi tiết sản phẩm',
                     style: TextStyle(
                       fontSize: 18,
                       fontWeight: FontWeight.bold,
                     ),
                     overflow: TextOverflow.ellipsis,
                   ),
                 ),
                 IconButton(
                   icon: Icon(Icons.close),
                   onPressed: () => Navigator.of(context).pop(),
                 ),
               ],
             ),
             SizedBox(height: 16),
             Expanded(
               child: SingleChildScrollView(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Card(
                       elevation: 2,
                       child: Padding(
                         padding: EdgeInsets.all(16),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               'Thông tin chung',
                               style: TextStyle(
                                 fontSize: 16,
                                 fontWeight: FontWeight.bold,
                               ),
                             ),
                             SizedBox(height: 12),
                             _buildInfoRow('Mã sản phẩm:', product['product_id'] ?? 'N/A'),
                             _buildInfoRow('Danh mục:', product['category'] ?? 'Không phân loại'),
                             _buildInfoRow('Thương hiệu:', product['brand'] ?? 'Không xác định'),
                             _buildInfoRow('Xuất xứ:', product['origin'] ?? 'Không xác định'),
                             _buildInfoRow('Đơn vị:', product['unit'] ?? 'Không xác định'),
                           ],
                         ),
                       ),
                     ),
                     SizedBox(height: 16),
                     Card(
                       elevation: 2,
                       child: Padding(
                         padding: EdgeInsets.all(16),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               'Biểu đồ dự báo',
                               style: TextStyle(
                                 fontSize: 16,
                                 fontWeight: FontWeight.bold,
                               ),
                             ),
                             SizedBox(height: 12),
                             Container(
                               height: 300,
                               child: _buildDetailChart(product),
                             ),
                             SizedBox(height: 12),
                             Text(
                               'Phương pháp dự báo: $_selectedForecastMethod',
                               style: TextStyle(
                                 fontSize: 12,
                                 color: Colors.grey[600],
                               ),
                             ),
                           ],
                         ),
                       ),
                     ),
                     SizedBox(height: 16),
                     Card(
                       elevation: 2,
                       child: Padding(
                         padding: EdgeInsets.all(16),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               'Phân tích chi tiết',
                               style: TextStyle(
                                 fontSize: 16,
                                 fontWeight: FontWeight.bold,
                               ),
                             ),
                             SizedBox(height: 12),
                             _buildMetricRow('Lượng bán trung bình:', '${product['avg_quantity']?.toStringAsFixed(1) ?? '0'}', Colors.blue),
                             _buildMetricRow('Dự đoán tiêu thụ:', '${product['forecast_quantity']?.toStringAsFixed(1) ?? '0'}', Colors.orange),
                             _buildMetricRow('Tồn kho hiện tại:', '${product['current_stock']?.toStringAsFixed(1) ?? '0'}', Colors.green),
                             _buildMetricRow('Điểm xu hướng:', product['trend_score']?.toStringAsFixed(1) ?? '0', _getTrendColor(product['trend_score'])),
                             _buildMetricRow('Độ tin cậy dự báo:', '${product['forecast_accuracy'] ?? 0}%', Colors.purple),
                           ],
                         ),
                       ),
                     ),
                     SizedBox(height: 16),
                     Card(
                       elevation: 2,
                       child: Padding(
                         padding: EdgeInsets.all(16),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               'Khuyến nghị',
                               style: TextStyle(
                                 fontSize: 16,
                                 fontWeight: FontWeight.bold,
                               ),
                             ),
                             SizedBox(height: 12),
                             Text(product['recommendation'] ?? 'Không có khuyến nghị'),
                             SizedBox(height: 8),
                             if (product['recommendation_details'] != null)
                               Container(
                                 margin: EdgeInsets.only(top: 8),
                                 padding: EdgeInsets.all(8),
                                 decoration: BoxDecoration(
                                   color: Colors.grey[100],
                                   borderRadius: BorderRadius.circular(4),
                                 ),
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     for (var detail in product['recommendation_details'])
                                       Padding(
                                         padding: EdgeInsets.only(bottom: 4),
                                         child: Row(
                                           crossAxisAlignment: CrossAxisAlignment.start,
                                           children: [
                                             Icon(Icons.arrow_right, size: 16, color: Colors.grey[600]),
                                             SizedBox(width: 4),
                                             Expanded(
                                               child: Text(
                                                 detail,
                                                 style: TextStyle(
                                                   fontSize: 14,
                                                   color: Colors.grey[800],
                                                 ),
                                               ),
                                             ),
                                           ],
                                         ),
                                       ),
                                   ],
                                 ),
                               ),
                           ],
                         ),
                       ),
                     ),
                     SizedBox(height: 16),
                     Card(
                       elevation: 2,
                       child: Padding(
                         padding: EdgeInsets.all(16),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               'Yếu tố ảnh hưởng',
                               style: TextStyle(
                                 fontSize: 16,
                                 fontWeight: FontWeight.bold,
                               ),
                             ),
                             SizedBox(height: 12),
                             for (var factor in product['influence_factors'] ?? [])
                               Padding(
                                 padding: EdgeInsets.only(bottom: 8),
                                 child: Row(
                                   children: [
                                     Container(
                                       width: 24,
                                       height: 24,
                                       decoration: BoxDecoration(
                                         color: _getFactorColor(factor['impact']).withOpacity(0.1),
                                         shape: BoxShape.circle,
                                       ),
                                       child: Icon(
                                         _getFactorIcon(factor['type']),
                                         size: 14,
                                         color: _getFactorColor(factor['impact']),
                                       ),
                                     ),
                                     SizedBox(width: 8),
                                     Expanded(
                                       child: Text(factor['name']),
                                     ),
                                     Container(
                                       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                       decoration: BoxDecoration(
                                         color: _getFactorColor(factor['impact']).withOpacity(0.1),
                                         borderRadius: BorderRadius.circular(4),
                                       ),
                                       child: Text(
                                         '${factor['impact'] > 0 ? '+' : ''}${factor['impact']}%',
                                         style: TextStyle(
                                           color: _getFactorColor(factor['impact']),
                                           fontWeight: FontWeight.bold,
                                           fontSize: 12,
                                         ),
                                       ),
                                     ),
                                   ],
                                 ),
                               ),
                           ],
                         ),
                       ),
                     ),
                   ],
                 ),
               ),
             ),
             SizedBox(height: 16),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 OutlinedButton.icon(
                   icon: Icon(Icons.share),
                   label: Text('Chia sẻ'),
                   onPressed: () {
                     _exportProduct(product);
                   },
                 ),
                 ElevatedButton.icon(
                   icon: Icon(Icons.update),
                   label: Text('Cập nhật dự báo'),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.orange,
                   ),
                   onPressed: () {
                     Navigator.of(context).pop();
                     _updateProductForecast(product);
                   },
                 ),
               ],
             ),
           ],
         ),
       ),
     ),
   );
 }

 void _showDeepAnalysisDialog() {
   showDialog(
     context: context,
     builder: (context) => Dialog(
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(12),
       ),
       insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
       child: Container(
         width: double.maxFinite,
         height: MediaQuery.of(context).size.height * 0.8,
         padding: EdgeInsets.all(16),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text(
                   'Phân tích chuyên sâu',
                   style: TextStyle(
                     fontSize: 18,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
                 IconButton(
                   icon: Icon(Icons.close),
                   onPressed: () => Navigator.of(context).pop(),
                 ),
               ],
             ),
             SizedBox(height: 16),
             TabBar(
               controller: _analysisTabController,
               labelColor: Colors.orange,
               unselectedLabelColor: Colors.grey,
               indicatorColor: Colors.orange,
               tabs: [
                 Tab(text: 'Theo mùa'),
                 Tab(text: 'So sánh năm'),
                 Tab(text: 'Theo danh mục'),
                 Tab(text: 'Tương quan'),
                 Tab(text: 'Dự báo tương lai'),
               ],
             ),
             Expanded(
               child: TabBarView(
                 controller: _analysisTabController,
                 children: [
                   _buildSeasonalAnalysisView(),
                   _buildYearOverYearView(),
                   _buildCategoryAnalysisView(),
                   _buildCorrelationAnalysisView(),
                   _buildFutureForecastView(),
                 ],
               ),
             ),
           ],
         ),
       ),
     ),
   );
 }

 Widget _buildSeasonalAnalysisView() {
   final monthNames = [
     'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 
     'Tháng 5', 'Tháng 6', 'Tháng 7', 'Tháng 8',
     'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'
   ];
   
   List<Map<String, dynamic>> monthlyData = [];
   _seasonalData.forEach((key, values) {
     if (key.startsWith('month_')) {
       int monthIndex = int.tryParse(key.substring(6)) ?? 0;
       if (monthIndex >= 1 && monthIndex <= 12) {
         double avgSales = values.isNotEmpty
             ? values.reduce((a, b) => a + b) / values.length
             : 0.0;
         
         monthlyData.add({
           'month': monthNames[monthIndex - 1],
           'monthIndex': monthIndex,
           'avgSales': avgSales,
           'values': values,
         });
       }
     }
   });
   
   monthlyData.sort((a, b) => a['monthIndex'].compareTo(b['monthIndex']));
   
   final List<FlSpot> spots = monthlyData
       .map((item) => FlSpot(item['monthIndex'].toDouble(), item['avgSales']))
       .toList();
   
   return SingleChildScrollView(
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Container(
           padding: EdgeInsets.all(16),
           margin: EdgeInsets.only(bottom: 16),
           decoration: BoxDecoration(
             color: Colors.orange.withOpacity(0.1),
             borderRadius: BorderRadius.circular(8),
           ),
           child: Text(
             'Phân tích theo mùa hiển thị lượng mua trung bình mỗi tháng qua các năm. '
             'Điều này giúp phát hiện mẫu mua hàng theo mùa và lập kế hoạch tồn kho hiệu quả.',
             style: TextStyle(
               fontSize: 14,
               color: Colors.grey[800],
             ),
           ),
         ),
         Container(
           height: 300,
           padding: EdgeInsets.all(8),
           child: LineChart(
             LineChartData(
               gridData: FlGridData(
                 show: true,
                 drawVerticalLine: true,
                 horizontalInterval: 10,
                 verticalInterval: 1,
               ),
               titlesData: FlTitlesData(
                 show: true,
                 bottomTitles: AxisTitles(
                   sideTitles: SideTitles(
                     showTitles: true,
                     reservedSize: 30,
                     getTitlesWidget: (value, meta) {
                       if (value.toInt() < 1 || value.toInt() > 12) return const Text('');
                       return Text(
                         'T${value.toInt()}',
                         style: TextStyle(
                           color: Colors.grey[600],
                           fontSize: 10,
                         ),
                       );
                     },
                   ),
                 ),
                 leftTitles: AxisTitles(
                   sideTitles: SideTitles(
                     showTitles: true,
                     reservedSize: 40,
                     getTitlesWidget: (value, meta) {
                       return Text(
                         value.toInt().toString(),
                         style: TextStyle(
                           color: Colors.grey[600],
                           fontSize: 10,
                         ),
                       );
                     },
                   ),
                 ),
                 topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                 rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
               ),
               borderData: FlBorderData(show: true),
               lineBarsData: [
                 LineChartBarData(
                   spots: spots,
                   isCurved: true,
                   color: Colors.orange,
                   barWidth: 3,
                   dotData: FlDotData(show: true),
                   belowBarData: BarAreaData(
                     show: true,
                     color: Colors.orange.withOpacity(0.2),
                   ),
                 ),
               ],
               minX: 1,
               maxX: 12,
               minY: 0,
             ),
           ),
         ),
         SizedBox(height: 20),
         Text(
           'Chi tiết theo tháng',
           style: TextStyle(
             fontSize: 16,
             fontWeight: FontWeight.bold,
           ),
         ),
         SizedBox(height: 8),
         ListView.builder(
           shrinkWrap: true,
           physics: NeverScrollableScrollPhysics(),
           itemCount: monthlyData.length,
           itemBuilder: (context, index) {
             final item = monthlyData[index];
             return Card(
               margin: EdgeInsets.only(bottom: 8),
               child: Padding(
                 padding: EdgeInsets.all(16),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text(
                           item['month'],
                           style: TextStyle(
                             fontSize: 16,
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                         Text(
                           'Trung bình: ${item['avgSales'].toStringAsFixed(1)}',
                           style: TextStyle(
                             fontSize: 16,
                             fontWeight: FontWeight.bold,
                             color: Colors.orange,
                           ),
                         ),
                       ],
                     ),
                     SizedBox(height: 8),
                     Text(
                       'Xu hướng: ${_getMonthlyTrend(item['monthIndex'])}',
                       style: TextStyle(
                         color: Colors.grey[700],
                       ),
                     ),
                     SizedBox(height: 16),
                     Text(
                       'Các yếu tố ảnh hưởng:',
                       style: TextStyle(
                         fontSize: 14,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                     SizedBox(height: 8),
                     _getMonthlyInfluenceFactors(item['monthIndex']),
                   ],
                 ),
               ),
             );
           },
         ),
       ],
     ),
   );
 }

 Widget _buildYearOverYearView() {
   if (_yoyData.isEmpty || !_yoyData.containsKey('yoyGrowth')) {
     return Center(
       child: Text('Không đủ dữ liệu để phân tích so sánh năm.'),
     );
   }
   
   final yoyGrowth = _yoyData['yoyGrowth'] as Map<dynamic, dynamic>;
   
   List<Map<String, dynamic>> yearData = [];
   yoyGrowth.forEach((year, monthData) {
     yearData.add({
       'year': year,
       'monthData': monthData,
     });
   });
   
   yearData.sort((a, b) => a['year'].toString().compareTo(b['year'].toString()));
   
   List<List<FlSpot>> yearSpots = [];
   List<Color> yearColors = [
     Colors.blue,
     Colors.red,
     Colors.green,
     Colors.purple,
     Colors.orange,
   ];
   
   for (int i = 0; i < yearData.length; i++) {
     final monthData = yearData[i]['monthData'] as Map<dynamic, dynamic>;
     List<FlSpot> spots = [];
     
     for (int month = 1; month <= 12; month++) {
       final growth = monthData[month.toString()] != null
           ? _getDoubleValue(monthData[month.toString()])
           : 0.0;
           
       spots.add(FlSpot(month.toDouble(), growth));
     }
     
     yearSpots.add(spots);
   }
   
   return SingleChildScrollView(
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Container(
           padding: EdgeInsets.all(16),
           margin: EdgeInsets.only(bottom: 16),
           decoration: BoxDecoration(
             color: Colors.orange.withOpacity(0.1),
             borderRadius: BorderRadius.circular(8),
           ),
           child: Text(
             'Phân tích so sánh năm hiển thị tăng trưởng so với cùng kỳ năm trước. '
             'Điều này giúp đánh giá hiệu suất kinh doanh và xu hướng dài hạn.',
             style: TextStyle(
               fontSize: 14,
               color: Colors.grey[800],
             ),
           ),
         ),
         Container(
           height: 300,
           padding: EdgeInsets.all(8),
           child: LineChart(
             LineChartData(
               gridData: FlGridData(
                 show: true,
                 drawVerticalLine: true,
                 horizontalInterval: 5,
                 verticalInterval: 1,
               ),
               titlesData: FlTitlesData(
                 show: true,
                 bottomTitles: AxisTitles(
                   sideTitles: SideTitles(
                     showTitles: true,
                     reservedSize: 30,
                     getTitlesWidget: (value, meta) {
                       if (value.toInt() < 1 || value.toInt() > 12) return const Text('');
                       return Text(
                         'T${value.toInt()}',
                         style: TextStyle(
                           color: Colors.grey[600],
                           fontSize: 10,
                         ),
                       );
                     },
                   ),
                 ),
                 leftTitles: AxisTitles(
                   sideTitles: SideTitles(
                     showTitles: true,
                     reservedSize: 40,
                     getTitlesWidget: (value, meta) {
                       return Text(
                         '${value.toInt()}%',
                         style: TextStyle(
                           color: Colors.grey[600],
                           fontSize: 10,
                         ),
                       );
                     },
                   ),
                 ),
                 topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                 rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
               ),
               borderData: FlBorderData(show: true),
               lineBarsData: List.generate(
                 yearSpots.length,
                 (index) => LineChartBarData(
                   spots: yearSpots[index],
                   isCurved: true,
                   color: yearColors[index % yearColors.length],
                   barWidth: 3,
                   dotData: FlDotData(show: true),
                 ),
               ),
               minX: 1,
               maxX: 12,
               minY: -20,
               maxY: 20,
             ),
           ),
         ),
         Padding(
           padding: EdgeInsets.all(8),
           child: Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: List.generate(
               yearData.length,
               (index) => Container(
                 margin: EdgeInsets.symmetric(horizontal: 8),
                 child: Row(
                   children: [
                     Container(
                       width: 12,
                       height: 12,
                       color: yearColors[index % yearColors.length],
                     ),
                     SizedBox(width: 4),
                     Text(yearData[index]['year'].toString()),
                   ],
                 ),
               ),
             ),
           ),
         ),
         SizedBox(height: 20),
         Text(
           'Chi tiết theo năm',
           style: TextStyle(
             fontSize: 16,
             fontWeight: FontWeight.bold,
           ),
         ),
         SizedBox(height: 8),
         ListView.builder(
           shrinkWrap: true,
           physics: NeverScrollableScrollPhysics(),
           itemCount: yearData.length,
           itemBuilder: (context, index) {
             final item = yearData[index];
             final monthData = item['monthData'] as Map<dynamic, dynamic>;
             
             double yearAvgGrowth = 0.0;
             int validMonths = 0;
             
             for (int month = 1; month <= 12; month++) {
               final growth = monthData[month.toString()] != null
                   ? _getDoubleValue(monthData[month.toString()])
                   : null;
               
               if (growth != null) {
                 yearAvgGrowth += growth;
                 validMonths++;
               }
             }
             
             yearAvgGrowth = validMonths > 0 ? yearAvgGrowth / validMonths : 0.0;
             
             return Card(
               margin: EdgeInsets.only(bottom: 16),
               child: Padding(
                 padding: EdgeInsets.all(16),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text(
                           'Năm ${item['year']}',
                           style: TextStyle(
                             fontSize: 18,
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                         Container(
                           padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                           decoration: BoxDecoration(
                             color: _getGrowthColor(yearAvgGrowth).withOpacity(0.1),
                             borderRadius: BorderRadius.circular(4),
                           ),
                           child: Text(
                             'TT TB: ${yearAvgGrowth.toStringAsFixed(1)}%',
                             style: TextStyle(
                               color: _getGrowthColor(yearAvgGrowth),
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                         ),
                       ],
                     ),
                     SizedBox(height: 12),
                     GridView.builder(
                       shrinkWrap: true,
                       physics: NeverScrollableScrollPhysics(),
                       gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                         crossAxisCount: 3,
                         childAspectRatio: 2.5,
                       ),
                       itemCount: 12,
                       itemBuilder: (context, monthIndex) {
                         final month = (monthIndex + 1).toString();
                         final growth = monthData[month] != null
                             ? _getDoubleValue(monthData[month])
                             : null;
                         
                         Color growthColor = Colors.grey;
                         if (growth != null) {
                           growthColor = _getGrowthColor(growth);
                         }
                         
                         return Container(
                           padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                           child: Column(
                             children: [
                               Text(
                                 'T${monthIndex + 1}',
                                 style: TextStyle(
                                   fontSize: 12,
                                   color: Colors.grey[700],
                                 ),
                               ),
                               Text(
                                 growth != null
                                     ? '${growth.toStringAsFixed(1)}%'
                                     : '-',
                                 style: TextStyle(
                                   fontSize: 14,
                                   fontWeight: FontWeight.bold,
                                   color: growthColor,
                                 ),
                               ),
                             ],
                           ),
                         );
                       },
                     ),
                   ],
                 ),
               ),
             );
           },
         ),
       ],
     ),
   );
 }

 Widget _buildCategoryAnalysisView() {
   if (_categoryData.isEmpty) {
     return Center(
       child: Text('Không đủ dữ liệu để phân tích theo danh mục.'),
     );
   }
   
   List<Map<String, dynamic>> categoryItems = [];
   _categoryData.forEach((category, data) {
     categoryItems.add({
       'category': category,
       'data': data,
     });
   });
   
   categoryItems.sort((a, b) {
     final aTotal = a['data']['totalQuantity'] ?? 0.0;
     final bTotal = b['data']['totalQuantity'] ?? 0.0;
     return bTotal.compareTo(aTotal);
   });
   
   List<PieChartSectionData> pieChartSections = [];
   List<Color> categoryColors = [
     Colors.blue,
     Colors.red,
     Colors.green,
     Colors.orange,
     Colors.purple,
     Colors.teal,
     Colors.pink,
     Colors.amber,
     Colors.indigo,
     Colors.lime,
   ];
   
   double totalQuantity = 0.0;
   for (var item in categoryItems) {
     final data = item['data'] as Map<String, dynamic>;
     totalQuantity += data['totalQuantity'] as double? ?? 0.0;
   }
   
   for (int i = 0; i < categoryItems.length; i++) {
     final item = categoryItems[i];
     final data = item['data'] as Map<String, dynamic>;
     final quantity = data['totalQuantity'] as double? ?? 0.0;
     
     if (i < 5 || quantity / totalQuantity > 0.05) {
       pieChartSections.add(
         PieChartSectionData(
           value: quantity,
           title: '${((quantity / totalQuantity) * 100).toStringAsFixed(1)}%',
           color: categoryColors[i % categoryColors.length],
           radius: 100,
           titleStyle: TextStyle(
             color: Colors.white,
             fontWeight: FontWeight.bold,
             fontSize: 12,
           ),
         ),
       );
     } else {
       pieChartSections.add(
         PieChartSectionData(
           value: quantity,
           title: '',
           color: Colors.grey,
           radius: 100,
         ),
       );
     }
   }
   
   return SingleChildScrollView(
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Container(
           padding: EdgeInsets.all(16),
           margin: EdgeInsets.only(bottom: 16),
           decoration: BoxDecoration(
             color: Colors.orange.withOpacity(0.1),
             borderRadius: BorderRadius.circular(8),
           ),
           child: Text(
             'Phân tích theo danh mục hiển thị xu hướng tiêu thụ của từng nhóm sản phẩm. '
             'Điều này giúp xác định danh mục nào đang phát triển hoặc suy giảm.',
             style: TextStyle(
               fontSize: 14,
               color: Colors.grey[800],
             ),
           ),
         ),
         Container(
           height: 300,
           padding: EdgeInsets.all(8),
           child: Row(
             children: [
               Expanded(
                 child: PieChart(
                   PieChartData(
                     sections: pieChartSections,
                     centerSpaceRadius: 40,
                     sectionsSpace: 2,
                   ),
                 ),
               ),
               SizedBox(width: 16),
               Expanded(
                 child: ListView.builder(
                   shrinkWrap: true,
                   itemCount: min(categoryItems.length, 5),
                   itemBuilder: (context, index) {
                     final item = categoryItems[index];
                     final data = item['data'] as Map<String, dynamic>;
                     final quantity = data['totalQuantity'] as double? ?? 0.0;
                     
                     return Container(
                       margin: EdgeInsets.only(bottom: 8),
                       child: Row(
                         children: [
                           Container(
                             width: 12,
                             height: 12,
                             color: categoryColors[index % categoryColors.length],
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: Text(
                               item['category'] ?? 'Không phân loại',
                               style: TextStyle(fontSize: 12),
                               overflow: TextOverflow.ellipsis,
                             ),
                           ),
                           Text(
                             '${((quantity / totalQuantity) * 100).toStringAsFixed(1)}%',
                             style: TextStyle(
                               fontWeight: FontWeight.bold,
                               fontSize: 12,
                             ),
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
         SizedBox(height: 20),
         Text(
           'Chi tiết theo danh mục',
           style: TextStyle(
             fontSize: 16,
             fontWeight: FontWeight.bold,
           ),
         ),
         SizedBox(height: 8),
         ListView.builder(
           shrinkWrap: true,
           physics: NeverScrollableScrollPhysics(),
           itemCount: categoryItems.length,
           itemBuilder: (context, index) {
             final item = categoryItems[index];
             final data = item['data'] as Map<String, dynamic>;
             final trendColor = data['trend'] == 'Tăng'
                 ? Colors.green
                 : data['trend'] == 'Giảm'
                     ? Colors.red
                     : Colors.orange;
             
             return Card(
               margin: EdgeInsets.only(bottom: 16),
               child: Padding(
                 padding: EdgeInsets.all(16),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Expanded(
                           child: Text(
                             item['category'] ?? 'Không phân loại',
                             style: TextStyle(
                               fontSize: 18,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                         ),
                         Container(
                           padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                           decoration: BoxDecoration(
                             color: trendColor.withOpacity(0.1),
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: Text(
                             data['trend'] ?? 'Ổn định',
                             style: TextStyle(
                               color: trendColor,
                               fontWeight: FontWeight.bold,
                               fontSize: 14,
                             ),
                           ),
                         ),
                       ],
                     ),
                     SizedBox(height: 16),
                     Row(
                       children: [
                         Expanded(
                           child: _buildStatisticItem(
                             'Tổng số đơn',
                             '${data['totalSales'] ?? 0}',
                             Colors.blue,
                           ),
                         ),
                         Expanded(
                           child: _buildStatisticItem(
                             'Tổng số lượng',
                             '${(data['totalQuantity'] as double?)?.toStringAsFixed(1) ?? '0'}',
                             Colors.purple,
                           ),
                         ),
                         Expanded(
                           child: _buildStatisticItem(
                             'Tăng trưởng TB',
                             '${(data['avgMonthlyGrowth'] as double?)?.toStringAsFixed(1) ?? '0'}%',
                             trendColor,
                           ),
                         ),
                       ],
                     ),
                     SizedBox(height: 16),
                     Text(
                       'Phân tích:',
                       style: TextStyle(
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                     SizedBox(height: 8),
                     Text(_getCategoryAnalysis(item['category'], data)),
                     SizedBox(height: 16),
                     Text(
                       'Top sản phẩm:',
                       style: TextStyle(
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                     SizedBox(height: 8),
                     if (data.containsKey('topProducts'))
                       ListView.builder(
                         shrinkWrap: true,
                         physics: NeverScrollableScrollPhysics(),
                         itemCount: (data['topProducts'] as List?)?.length ?? 0,
                         itemBuilder: (context, productIndex) {
                           final product = (data['topProducts'] as List)[productIndex];
                           return Padding(
                             padding: EdgeInsets.only(bottom: 8),
                             child: Row(
                               children: [
                                 Text('${productIndex + 1}.'),
                                 SizedBox(width: 8),
                                 Expanded(
                                   child: Text(product['name'] ?? 'Sản phẩm'),
                                 ),
                                 Container(
                                   padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                   decoration: BoxDecoration(
                                     color: Colors.grey[200],
                                     borderRadius: BorderRadius.circular(4),
                                   ),
                                   child: Text(
                                     '${product['quantity']?.toStringAsFixed(1) ?? '0'}',
                                     style: TextStyle(
                                       fontWeight: FontWeight.bold,
                                       fontSize: 12,
                                     ),
                                   ),
                                 ),
                               ],
                             ),
                           );
                         },
                       ),
                   ],
                 ),
               ),
             );
           },
         ),
       ],
     ),
   );
 }

 Widget _buildCorrelationAnalysisView() {
   final Map<String, dynamic> correlationData = {
     'priceQuantity': -0.75,
     'holidaySales': 0.62,
     'weatherSales': 0.45,
     'weekdaySales': -0.15,
     'promotionSales': 0.85,
   };
   
   final List<Map<String, dynamic>> factorItems = [
     {'name': 'Giá sản phẩm & Lượng bán', 'value': correlationData['priceQuantity'], 'icon': Icons.attach_money},
     {'name': 'Ngày lễ & Doanh số', 'value': correlationData['holidaySales'], 'icon': Icons.celebration},
     {'name': 'Thời tiết & Doanh số', 'value': correlationData['weatherSales'], 'icon': Icons.cloud},
     {'name': 'Ngày trong tuần & Doanh số', 'value': correlationData['weekdaySales'], 'icon': Icons.date_range},
     {'name': 'Khuyến mại & Doanh số', 'value': correlationData['promotionSales'], 'icon': Icons.local_offer},
   ];
   
   return SingleChildScrollView(
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Container(
           padding: EdgeInsets.all(16),
           margin: EdgeInsets.only(bottom: 16),
           decoration: BoxDecoration(
             color: Colors.orange.withOpacity(0.1),
             borderRadius: BorderRadius.circular(8),
           ),
           child: Text(
             'Phân tích tương quan hiển thị mối quan hệ giữa các yếu tố khác nhau và doanh số bán hàng. '
             'Giá trị càng gần 1 hoặc -1 càng thể hiện mối tương quan mạnh.',
             style: TextStyle(
               fontSize: 14,
               color: Colors.grey[800],
             ),
           ),
         ),
         Container(
           height: 300,
           padding: EdgeInsets.all(8),
           child: BarChart(
             BarChartData(
               alignment: BarChartAlignment.center,
               maxY: 1,
               minY: -1,
               groupsSpace: 12,
               gridData: FlGridData(
                 show: true,
                 horizontalInterval: 0.25,
               ),
               borderData: FlBorderData(show: true),
               titlesData: FlTitlesData(
                 show: true,
                 bottomTitles: AxisTitles(
                   sideTitles: SideTitles(
                     showTitles: true,
                     reservedSize: 30,
                     getTitlesWidget: (value, meta) {
                       if (value.toInt() < 0 || value.toInt() >= factorItems.length) return const Text('');
                       return Padding(
                         padding: const EdgeInsets.only(top: 8.0),
                         child: Icon(
                           factorItems[value.toInt()]['icon'],
                           size: 18,
                           color: Colors.grey[600],
                         ),
                       );
                     },
                   ),
                 ),
                 leftTitles: AxisTitles(
                   sideTitles: SideTitles(
                     showTitles: true,
                     reservedSize: 40,
                     getTitlesWidget: (value, meta) {
                       return Text(
                         value.toStringAsFixed(1),
                         style: TextStyle(
                           color: Colors.grey[600],
                           fontSize: 10,
                         ),
                       );
                     },
                   ),
                 ),
                 topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                 rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
               ),
               barGroups: List.generate(
                 factorItems.length,
                 (index) => BarChartGroupData(
                   x: index,
                   barRods: [
                     BarChartRodData(
                       toY: factorItems[index]['value'],
                       color: factorItems[index]['value'] >= 0 ? Colors.blue : Colors.red,
                       width: 20,
                       borderRadius: BorderRadius.only(
                         topLeft: Radius.circular(5),
                         topRight: Radius.circular(5),
                         bottomLeft: factorItems[index]['value'] < 0 ? Radius.circular(0) : Radius.circular(5),
                         bottomRight: factorItems[index]['value'] < 0 ? Radius.circular(0) : Radius.circular(5),
                       ),
                     ),
                   ],
                 ),
               ),
             ),
           ),
         ),
         Padding(
           padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
           child: Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Container(
                 width: 12,
                 height: 12,
                 color: Colors.blue,
               ),
               SizedBox(width: 4),
               Text('Tương quan dương'),
               SizedBox(width: 16),
               Container(
                 width: 12,
                 height: 12,
                 color: Colors.red,
               ),
               SizedBox(width: 4),
               Text('Tương quan âm'),
             ],
           ),
         ),
         SizedBox(height: 20),
         Text(
           'Chi tiết tương quan',
           style: TextStyle(
             fontSize: 16,
             fontWeight: FontWeight.bold,
           ),
         ),
         SizedBox(height: 8),
         ListView.builder(
           shrinkWrap: true,
           physics: NeverScrollableScrollPhysics(),
           itemCount: factorItems.length,
           itemBuilder: (context, index) {
             final item = factorItems[index];
             final correlationStrength = _getCorrelationStrength(item['value']);
             final correlationColor = item['value'] >= 0 ? Colors.blue : Colors.red;
             
             return Card(
               margin: EdgeInsets.only(bottom: 8),
               child: Padding(
                 padding: EdgeInsets.all(16),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       children: [
                         Icon(item['icon'], color: correlationColor),
                         SizedBox(width: 8),
                         Expanded(
                           child: Text(
                             item['name'],
                             style: TextStyle(
                               fontSize: 16,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                         ),
                         Container(
                           padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                           decoration: BoxDecoration(
                             color: correlationColor.withOpacity(0.1),
                             borderRadius: BorderRadius.circular(4),
                           ),
                           child: Text(
                             item['value'].toStringAsFixed(2),
                             style: TextStyle(
                               color: correlationColor,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                         ),
                       ],
                     ),
                     SizedBox(height: 8),
                     Text(
                       'Mức độ tương quan: $correlationStrength',
                       style: TextStyle(
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                     SizedBox(height: 4),
                     Text(_getCorrelationExplanation(item)),
                   ],
                 ),
               ),
             );
           },
         ),
       ],
     ),
   );
 }

 Widget _buildFutureForecastView() {
   final List<double> historicalData = List.generate(24, (index) => 50 + 10 * sin(index * 0.5) + Random().nextDouble() * 10);
   final List<double> forecastData = List.generate(12, (index) => 60 + 15 * sin((index + 24) * 0.5) + Random().nextDouble() * 5);
   final List<double> upperBoundData = List.generate(12, (index) => forecastData[index] + 10 + index);
   final List<double> lowerBoundData = List.generate(12, (index) => forecastData[index] - 10 - index * 0.5);
   
   final List<FlSpot> historySpots = historicalData
       .asMap()
       .entries
       .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
       .toList();
   
   final List<FlSpot> forecastSpots = forecastData
       .asMap()
       .entries
       .map((entry) => FlSpot((historySpots.length + entry.key).toDouble(), entry.value))
       .toList();
   
   final List<FlSpot> upperBoundSpots = upperBoundData
       .asMap()
       .entries
       .map((entry) => FlSpot((historySpots.length + entry.key).toDouble(), entry.value))
       .toList();
   
   final List<FlSpot> lowerBoundSpots = lowerBoundData
       .asMap()
       .entries
       .map((entry) => FlSpot((historySpots.length + entry.key).toDouble(), entry.value))
       .toList();
   
   return SingleChildScrollView(
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Container(
           padding: EdgeInsets.all(16),
           margin: EdgeInsets.only(bottom: 16),
           decoration: BoxDecoration(
             color: Colors.orange.withOpacity(0.1),
             borderRadius: BorderRadius.circular(8),
           ),
           child: Text(
             'Dự báo tương lai hiển thị xu hướng tiêu thụ dự kiến trong 12 tháng tới. '
             'Khoảng tin cậy cho biết mức độ chắc chắn của dự báo.',
             style: TextStyle(
               fontSize: 14,
               color: Colors.grey[800],
             ),
           ),
         ),
         Container(
           height: 300,
           padding: EdgeInsets.all(8),
           child: LineChart(
             LineChartData(
               gridData: FlGridData(
                 show: true,
                 drawVerticalLine: true,
                 horizontalInterval: 10,
                 verticalInterval: 6,
               ),
               titlesData: FlTitlesData(
                 show: true,
                 bottomTitles: AxisTitles(
                   sideTitles: SideTitles(
                     showTitles: true,
                     reservedSize: 30,
                     interval: 6,
                     getTitlesWidget: (value, meta) {
                       if (value % 6 != 0) return const Text('');
                       final date = DateTime.now().subtract(Duration(days: ((24 - value) * 30).toInt()));
                       if (value < 24) {
                         return Text(
                           '${date.month}/${date.year}',
                           style: TextStyle(
                             color: Colors.grey[600],
                             fontSize: 10,
                           ),
                         );
                       } else {
                         return Text(
                           '${date.month}/${date.year}',
                           style: TextStyle(
                             color: Colors.orange,
                             fontSize: 10,
                             fontWeight: FontWeight.bold,
                           ),
                         );
                       }
                     },
                   ),
                 ),
                 leftTitles: AxisTitles(
                   sideTitles: SideTitles(
                     showTitles: true,
                     reservedSize: 40,
                     getTitlesWidget: (value, meta) {
                       return Text(
                         value.toInt().toString(),
                         style: TextStyle(
                           color: Colors.grey[600],
                           fontSize: 10,
                         ),
                       );
                     },
                   ),
                 ),
                 topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                 rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
               ),
               borderData: FlBorderData(show: true),
               lineBarsData: [
                 LineChartBarData(
                   spots: historySpots,
                   isCurved: true,
                   color: Colors.blue,
                   barWidth: 3,
                   dotData: FlDotData(show: false),
                 ),
                 LineChartBarData(
                   spots: forecastSpots,
                   isCurved: true,
                   color: Colors.orange,
                   barWidth: 3,
                   dotData: FlDotData(show: false),
                   dashArray: [5, 5],
                 ),
                 LineChartBarData(
                   spots: upperBoundSpots,
                   isCurved: true,
                   color: Colors.orange.withOpacity(0.3),
                   barWidth: 1,
                   dotData: FlDotData(show: false),
                 ),
                 LineChartBarData(
                   spots: lowerBoundSpots,
                   isCurved: true,
                   color: Colors.orange.withOpacity(0.3),
                   barWidth: 1,
                   dotData: FlDotData(show: false),
                 ),
               ],
               lineTouchData: LineTouchData(
                 touchTooltipData: LineTouchTooltipData(
                   tooltipBgColor: Colors.white,
                   getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                     return touchedBarSpots.map((barSpot) {
                       final flSpot = barSpot;
                       final date = DateTime.now().subtract(Duration(days: ((24 - flSpot.x) * 30).toInt()));
                       String formattedDate = '${date.month}/${date.year}';
                       
                       return LineTooltipItem(
                         '$formattedDate: ${flSpot.y.toStringAsFixed(1)}',
                         TextStyle(
                           color: barSpot.barIndex == 0 ? Colors.blue : Colors.orange,
                           fontWeight: FontWeight.bold,
                         ),
                       );
                     }).toList();
                   },
                 ),
               ),
             ),
           ),
         ),
         Padding(
           padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
           child: Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Container(
                 width: 12,
                 height: 12,
                 color: Colors.blue,
               ),
               SizedBox(width: 4),
               Text('Dữ liệu lịch sử'),
               SizedBox(width: 16),
               Container(
                 width: 12,
                 height: 12,
                 color: Colors.orange,
               ),
               SizedBox(width: 4),
               Text('Dự báo'),
               SizedBox(width: 16),
               Container(
                 width: 12,
                 height: 12,
                 color: Colors.orange.withOpacity(0.3),
               ),
               SizedBox(width: 4),
               Text('Khoảng tin cậy'),
             ],
           ),
         ),
         SizedBox(height: 20),
         Card(
           margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
           child: Padding(
             padding: EdgeInsets.all(16),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(
                   'Tổng quan xu hướng tương lai',
                   style: TextStyle(
                     fontSize: 16,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
                 SizedBox(height: 16),
                 Text(
                   'Dự báo cho thấy xu hướng tăng nhẹ trong 12 tháng tới với biến động theo mùa. Dựa trên phân tích dữ liệu lịch sử, các yếu tố thời vụ và phương pháp ARIMA, dự kiến doanh số sẽ tăng khoảng 15% so với cùng kỳ năm trước.',
                   style: TextStyle(
                     color: Colors.grey[800],
                   ),
                 ),
                 SizedBox(height: 16),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Expanded(
                       child: _buildMetricItem(
                         'Tăng trưởng dự kiến',
                         '15%',
                         Icons.trending_up,
                         Colors.green,
                       ),
                     ),
                     Expanded(
                       child: _buildMetricItem(
                         'Độ tin cậy',
                         '78%',
                         Icons.verified,
                         Colors.blue,
                       ),
                     ),
                     Expanded(
                       child: _buildMetricItem(
                         'Biến động',
                         'Trung bình',
                         Icons.swap_vert,
                         Colors.orange,
                       ),
                     ),
                   ],
                 ),
               ],
             ),
           ),
         ),
         Card(
           margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
           child: Padding(
             padding: EdgeInsets.all(16),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(
                   'Khuyến nghị chiến lược',
                   style: TextStyle(
                     fontSize: 16,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
                 SizedBox(height: 16),
                 ListView(
                   shrinkWrap: true,
                   physics: NeverScrollableScrollPhysics(),
                   children: [
                     _buildRecommendationItem(
                       'Tăng lượng hàng dự trữ vào tháng 5-6 để đáp ứng nhu cầu cao điểm tháng 7-8',
                       Colors.orange,
                     ),
                     _buildRecommendationItem(
                       'Xem xét triển khai chương trình khuyến mãi trong các tháng có doanh số thấp (2-3 và 9-10)',
                       Colors.purple,
                     ),
                     _buildRecommendationItem(
                       'Điều chỉnh các thông số dự báo mỗi quý để đảm bảo độ chính xác',
                       Colors.blue,
                     ),
                     _buildRecommendationItem(
                       'Chuẩn bị nguồn lực để đáp ứng mức tăng trưởng dự kiến 15%',
                       Colors.green,
                     ),
                   ],
                 ),
               ],
             ),
           ),
         ),
       ],
     ),
   );
 }

 Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
   return Column(
     children: [
       Container(
         padding: EdgeInsets.all(8),
         decoration: BoxDecoration(
           color: color.withOpacity(0.1),
           shape: BoxShape.circle,
         ),
         child: Icon(
           icon,
           color: color,
           size: 20,
         ),
       ),
       SizedBox(height: 8),
       Text(
         value,
         style: TextStyle(
           fontSize: 16,
           fontWeight: FontWeight.bold,
           color: color,
         ),
       ),
       SizedBox(height: 4),
       Text(
         label,
         style: TextStyle(
           fontSize: 12,
           color: Colors.grey[600],
         ),
         textAlign: TextAlign.center,
       ),
     ],
   );
 }

 Widget _buildRecommendationItem(String text, Color color) {
   return Container(
     margin: EdgeInsets.only(bottom: 12),
     child: Row(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Container(
           margin: EdgeInsets.only(top: 2),
           width: 8,
           height: 8,
           decoration: BoxDecoration(
             shape: BoxShape.circle,
             color: color,
           ),
         ),
         SizedBox(width: 8),
         Expanded(
           child: Text(text),
         ),
       ],
     ),
   );
 }

 Widget _buildDetailChart(Map<String, dynamic> product) {
   final List<FlSpot> historySpots = (product['history_data'] as List<double>? ?? [])
       .asMap()
       .entries
       .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
       .toList();
   
   final List<FlSpot> forecastSpots = (product['forecast_data'] as List<double>? ?? [])
       .asMap()
       .entries
       .map((entry) => FlSpot((historySpots.length + entry.key).toDouble(), entry.value))
       .toList();
   
   final List<FlSpot> upperBoundSpots = (product['upper_bound'] as List<double>? ?? [])
       .asMap()
       .entries
       .map((entry) => FlSpot((historySpots.length + entry.key).toDouble(), entry.value))
       .toList();
   
   final List<FlSpot> lowerBoundSpots = (product['lower_bound'] as List<double>? ?? [])
       .asMap()
       .entries
       .map((entry) => FlSpot((historySpots.length + entry.key).toDouble(), entry.value))
       .toList();
   
   return LineChart(
     LineChartData(
       gridData: FlGridData(
         show: true,
         drawVerticalLine: true,
         horizontalInterval: 10,
         verticalInterval: 5,
       ),
       titlesData: FlTitlesData(
         show: true,
         bottomTitles: AxisTitles(
           sideTitles: SideTitles(
             showTitles: true,
             reservedSize: 30,
             interval: 5,
             getTitlesWidget: (value, meta) {
               if (value % 5 != 0) return const Text('');
               return Text(
                 value.toInt().toString(),
                 style: TextStyle(
                   color: Colors.grey[600],
                   fontSize: 10,
                 ),
               );
             },
           ),
         ),
         leftTitles: AxisTitles(
           sideTitles: SideTitles(
             showTitles: true,
             reservedSize: 40,
             getTitlesWidget: (value, meta) {
               return Text(
                 value.toInt().toString(),
                 style: TextStyle(
                   color: Colors.grey[600],
                   fontSize: 10,
                 ),
               );
             },
           ),
         ),
         topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
         rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
       ),
       borderData: FlBorderData(show: true),
       lineBarsData: [
         LineChartBarData(
           spots: historySpots,
           isCurved: true,
           color: Colors.blue,
           barWidth: 3,
           dotData: FlDotData(show: false),
           belowBarData: BarAreaData(
             show: true,
             color: Colors.blue.withOpacity(0.1),
           ),
         ),
         LineChartBarData(
           spots: forecastSpots,
           isCurved: true,
           color: Colors.orange,
           barWidth: 3,
           dotData: FlDotData(show: false),
           belowBarData: BarAreaData(
             show: true,
             color: Colors.orange.withOpacity(0.1),
           ),
           dashArray: [5, 5],
         ),
         if (_showConfidenceIntervals)
           LineChartBarData(
             spots: upperBoundSpots,
             isCurved: true,
             color: Colors.orange.withOpacity(0.5),
             barWidth: 1,
             dotData: FlDotData(show: false),
           ),
         if (_showConfidenceIntervals)
           LineChartBarData(
             spots: lowerBoundSpots,
             isCurved: true,
             color: Colors.orange.withOpacity(0.5),
             barWidth: 1,
             dotData: FlDotData(show: false),
           ),
       ],
       lineTouchData: LineTouchData(
         touchTooltipData: LineTouchTooltipData(
           tooltipBgColor: Colors.white,
           getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
             return touchedBarSpots.map((barSpot) {
               final flSpot = barSpot;
               
               return LineTooltipItem(
                 '${flSpot.x.toInt()}: ${flSpot.y.toStringAsFixed(1)}',
                 TextStyle(
                   color: barSpot.barIndex == 0 ? Colors.blue : Colors.orange,
                   fontWeight: FontWeight.bold,
                 ),
               );
             }).toList();
           },
         ),
       ),
     ),
   );
 }

 Widget _buildInfoRow(String label, String value) {
   return Padding(
     padding: const EdgeInsets.only(bottom: 8.0),
     child: Row(
       children: [
         Text(
           label,
           style: TextStyle(
             color: Colors.grey[600],
             fontSize: 14,
           ),
         ),
         SizedBox(width: 8),
         Text(
           value,
           style: TextStyle(
             fontWeight: FontWeight.bold,
             fontSize: 14,
           ),
         ),
       ],
     ),
   );
 }

 Widget _buildMetricRow(String label, String value, Color color) {
   return Padding(
     padding: const EdgeInsets.only(bottom: 12.0),
     child: Row(
       children: [
         Text(
           label,
           style: TextStyle(
             fontSize: 14,
           ),
         ),
         Spacer(),
         Container(
           padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
           decoration: BoxDecoration(
             color: color.withOpacity(0.1),
             borderRadius: BorderRadius.circular(4),
           ),
           child: Text(
             value,
             style: TextStyle(
               color: color,
               fontWeight: FontWeight.bold,
               fontSize: 14,
             ),
           ),
         ),
       ],
     ),
   );
 }

 void _showImportDialog() {
   showDialog(
     context: context,
     builder: (context) => AlertDialog(
       title: Text('Nhập dữ liệu'),
       content: Column(
         mainAxisSize: MainAxisSize.min,
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text('Chọn nguồn dữ liệu:'),
           SizedBox(height: 16),
           ListTile(
             leading: Icon(Icons.file_copy),
             title: Text('Tệp CSV'),
             subtitle: Text('Nhập từ tệp CSV'),
             onTap: () {
               Navigator.of(context).pop();
               _importFromCSV();
             },
           ),
           ListTile(
             leading: Icon(Icons.cloud_upload),
             title: Text('API'),
             subtitle: Text('Kết nối với API bên ngoài'),
             onTap: () {
               Navigator.of(context).pop();
               _importFromAPI();
             },
           ),
           ListTile(
             leading: Icon(Icons.cloud_download),
             title: Text('Dữ liệu mẫu'),
             subtitle: Text('Sử dụng dữ liệu mẫu'),
             onTap: () {
               Navigator.of(context).pop();
               _loadSampleData();
             },
           ),
         ],
       ),
       actions: [
         TextButton(
           onPressed: () => Navigator.of(context).pop(),
           child: Text('Huỷ bỏ'),
         ),
       ],
     ),
   );
 }

 void _showExportDialog() {
   showDialog(
     context: context,
     builder: (context) => AlertDialog(
       title: Text('Xuất dữ liệu'),
       content: Column(
         mainAxisSize: MainAxisSize.min,
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text('Chọn định dạng xuất:'),
           SizedBox(height: 16),
           ListTile(
             leading: Icon(Icons.table_chart),
             title: Text('CSV'),
             subtitle: Text('Xuất ra tệp CSV'),
             onTap: () {
               Navigator.of(context).pop();
               _exportToCSV();
             },
           ),
           ListTile(
             leading: Icon(Icons.bar_chart),
             title: Text('Báo cáo PDF'),
             subtitle: Text('Xuất báo cáo dạng PDF'),
             onTap: () {
               Navigator.of(context).pop();
               _exportToPDF();
             },
           ),
           ListTile(
             leading: Icon(Icons.share),
             title: Text('Chia sẻ kết quả'),
             subtitle: Text('Chia sẻ tóm tắt kết quả'),
             onTap: () {
               Navigator.of(context).pop();
               _shareResults();
             },
           ),
         ],
       ),
       actions: [
         TextButton(
           onPressed: () => Navigator.of(context).pop(),
           child: Text('Huỷ bỏ'),
         ),
       ],
     ),
   );
 }

 Future<void> _performTrendAnalysis() async {
   setState(() {
     _isLoading = true;
   });

   try {
     if (_includeExternalFactors) {
       await _fetchExternalFactors();
     }
     
     // Step 1: Get all branches
     final branches = await _dbHelper.getAllBranches();
     final allBranches = ['Tất cả', ...branches];
     
     // Step 2: Get completed orders
     final orders = await _dbHelper.getCompletedOrderItems();
     
     // Step 3: Get product information
     final products = await _dbHelper.getAllProducts();
     
     // Step 4: Get stock information
     final stockLevels = await _dbHelper.getAllStockLevels();
     
     // Step 5: Build branch-specific analysis
     Map<String, List<Map<String, dynamic>>> branchResults = {};
     List<Map<String, dynamic>> overallResults = [];
     
     for (String branch in branches) {
       final branchOrders = orders.where((order) => order['chiNhanh'] == branch).toList();
       final results = _analyzeTrends(branchOrders, products, stockLevels, branch);
       branchResults[branch] = results;
     }
     
     // Step 6: Build overall analysis
     overallResults = _analyzeTrends(orders, products, stockLevels, 'all');
     
     // Update state with results
     setState(() {
       _branches = allBranches;
       _branchResults = branchResults;
       _trendResults = overallResults;
       _isLoading = false;
       _hasData = true;
     });
     
     // Step 7: Perform deeper analysis if enough data
     if (orders.length > 30) {
       try {
         // Seasonal analysis
         final seasonalAnalysis = _analyzeSeasonalTrends(orders);
         
         // Year-over-year analysis
         final yoyAnalysis = _yearOverYearAnalysis(orders);
         
         // Category analysis
         final categoryAnalysis = _categoryAnalysis(orders, products);
         
         // Update state with deeper analysis
         setState(() {
           _seasonalData = seasonalAnalysis;
           _yoyData = yoyAnalysis;
           _categoryData = categoryAnalysis;
           _hasDeepAnalysis = true;
         });
       } catch (e) {
         print('Error in deep analysis: $e');
         // Continue even if deep analysis fails
       }
     }
   } catch (e) {
     print('Error in trend analysis: $e');
     
     setState(() {
       _isLoading = false;
     });
     
     // Show error message
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Lỗi khi phân tích xu hướng: ${e.toString()}'),
         backgroundColor: Colors.red,
         duration: Duration(seconds: 5),
       ),
     );
   }
 }

 List<Map<String, dynamic>> _analyzeTrends(
   List<Map<String, dynamic>> orders,
   List<Map<String, dynamic>> products,
   List<Map<String, dynamic>> stockLevels,
   String branch
 ) {
   // Group orders by product ID
   Map<String, List<Map<String, dynamic>>> productOrders = {};
   
   for (var order in orders) {
     final productId = order['idHang']?.toString() ?? '';
     if (productId.isNotEmpty) {
       if (!productOrders.containsKey(productId)) {
         productOrders[productId] = [];
       }
       productOrders[productId]?.add(order);
     }
   }
   
   // Analyze each product
   List<Map<String, dynamic>> results = [];
   
   productOrders.forEach((productId, orderList) {
     try {
       // Get product info
       final productInfo = products.firstWhere(
         (p) => p['uid'] == productId,
         orElse: () => {'TenSanPham': 'Sản phẩm không xác định'},
       );
       
       // Get current stock
       double currentStock = 0.0;
       if (branch == 'all') {
         // Sum up stock across all branches for this product
         final relevantStocks = stockLevels.where((s) => s['maHangID'] == productId);
         currentStock = relevantStocks.fold(0.0, (double sum, stock) {
           return sum + _getDoubleValue(stock['soLuongHienTai']);
         });
       } else {
         // Get stock for this branch and product
         final branchStock = stockLevels.firstWhere(
           (s) => s['maHangID'] == productId && s['khoHangID'] == branch,
           orElse: () => {'soLuongHienTai': 0},
         );
         currentStock = _getDoubleValue(branchStock['soLuongHienTai']);
       }
       
       // Sort orders by date
       orderList.sort((a, b) {
         final aDate = DateTime.tryParse(a['updateTime'] ?? '') ?? DateTime(2000);
         final bDate = DateTime.tryParse(b['updateTime'] ?? '') ?? DateTime(2000);
         return aDate.compareTo(bDate);
       });
       
       // Extract quantities for time series analysis
       List<double> quantities = [];
       for (var order in orderList) {
         quantities.add(_getDoubleValue(order['soLuongYeuCau']));
       }
       
       // Calculate statistics
       double avgQuantity = quantities.isNotEmpty 
           ? quantities.reduce((a, b) => a + b) / quantities.length 
           : 0.0;
       
       // Apply selected forecasting method
       Map<String, dynamic> forecastResult = _applyForecastMethod(quantities);
       
       // Extract forecast values
       double forecastQuantity = forecastResult['nextValue'] ?? avgQuantity;
       List<double> forecastData = forecastResult['forecast'] ?? [];
       List<double> upperBound = forecastResult['upperBound'] ?? [];
       List<double> lowerBound = forecastResult['lowerBound'] ?? [];
       
       // Calculate trend score
       double trendScore = _calculateTrendScore(quantities, forecastData);
       
       // Generate recommendation
       String recommendation = _generateRecommendation(
         avgQuantity, 
         forecastQuantity, 
         currentStock,
         productInfo['TenSanPham'] ?? 'sản phẩm này',
         trendScore,
       );
       
       // Generate detailed recommendations
       List<String> recommendationDetails = _generateDetailedRecommendations(
         avgQuantity,
         forecastQuantity,
         currentStock,
         trendScore,
         quantities,
       );
       
       // Generate influence factors
       List<Map<String, dynamic>> influenceFactors = _generateInfluenceFactors(
         productId,
         productInfo,
         quantities,
         forecastData,
       );
       
       // Add to results
       results.add({
         'product_id': productId,
         'product_name': productInfo['TenSanPham'] ?? 'Sản phẩm không xác định',
         'category': productInfo['PhanLoai1'] ?? 'Không phân loại',
         'brand': productInfo['ThuongHieu'] ?? 'Không xác định',
         'origin': productInfo['XuatXu'] ?? 'Không xác định',
         'unit': productInfo['DonVi'] ?? 'Cái',
         'avg_quantity': avgQuantity,
         'forecast_quantity': forecastQuantity,
         'current_stock': currentStock,
         'trend_score': trendScore,
         'trend': _getTrendLabel(trendScore),
         'forecast_accuracy': _calculateForecastAccuracy(quantities),
         'recommendation': recommendation,
         'recommendation_details': recommendationDetails,
         'history_data': quantities,
         'forecast_data': forecastData,
         'upper_bound': upperBound,
         'lower_bound': lowerBound,
         'influence_factors': influenceFactors,
       });
     } catch (e) {
       print('Error analyzing product $productId: $e');
       // Continue with next product
     }
   });
   
   // Sort results by forecast quantity (descending)
   results.sort((a, b) => (b['forecast_quantity'] ?? 0).compareTo(a['forecast_quantity'] ?? 0));
   
   // Cache forecast results
   for (var result in results) {
     _forecastCache[result['product_id']] = {
       'timestamp': DateTime.now().millisecondsSinceEpoch,
       'data': result,
     };
   }
   
   // Return top products
   return results.take(20).toList();
 }

 Map<String, dynamic> _applyForecastMethod(List<double> data) {
   if (data.isEmpty) {
     return {
       'nextValue': 0.0,
       'forecast': <double>[],
       'upperBound': <double>[],
       'lowerBound': <double>[],
     };
   }
   
   switch (_selectedForecastMethod) {
     case 'Simple':
       return _simpleForecasting(data);
     case 'Moving Average':
       return _movingAverageForecasting(data);
     case 'Exponential Smoothing':
       return _exponentialSmoothingForecasting(data);
     case 'ARIMA':
       return _arimaForecasting(data);
     case 'Neural Network':
       return _neuralNetworkForecasting(data);
     default:
       return _arimaForecasting(data);
   }
 }

 Map<String, dynamic> _simpleForecasting(List<double> data) {
   if (data.isEmpty) return {'nextValue': 0.0, 'forecast': [], 'upperBound': [], 'lowerBound': []};
   if (data.length == 1) return {'nextValue': data[0], 'forecast': [data[0]], 'upperBound': [data[0] * 1.2], 'lowerBound': [data[0] * 0.8]};
   
   // Linear regression
   int n = data.length;
   List<double> x = List.generate(n, (i) => i.toDouble());
   
   double sumX = x.reduce((a, b) => a + b);
   double sumY = data.reduce((a, b) => a + b);
   double sumXY = 0.0;
   double sumX2 = 0.0;
   
   for (int i = 0; i < n; i++) {
     sumXY += x[i] * data[i];
     sumX2 += x[i] * x[i];
   }
   
   double slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
   double intercept = (sumY - slope * sumX) / n;
   
   // Generate forecast for future periods
   List<double> forecast = [];
   List<double> upper = [];
   List<double> lower = [];
   
   for (int i = 0; i < _forecastHorizon; i++) {
     double nextX = n + i.toDouble();
     double nextY = intercept + slope * nextX;
     forecast.add(max(0.0, nextY));
     
     // Simple confidence intervals
     double error = 0.0;
     for (int j = 0; j < n; j++) {
       double predicted = intercept + slope * j;
       error += pow(data[j] - predicted, 2);
     }
     error = sqrt(error / n) * (1 + (i + 1) / 10);
     
     upper.add(max(0.0, nextY + error));
     lower.add(max(0.0, nextY - error));
   }
   
   return {
     'nextValue': forecast.isNotEmpty ? forecast[0] : (intercept + slope * n),
     'forecast': forecast,
     'upperBound': upper,
     'lowerBound': lower,
   };
 }

 Map<String, dynamic> _movingAverageForecasting(List<double> data) {
   if (data.isEmpty) return {'nextValue': 0.0, 'forecast': [], 'upperBound': [], 'lowerBound': []};
   if (data.length == 1) return {'nextValue': data[0], 'forecast': [data[0]], 'upperBound': [data[0] * 1.2], 'lowerBound': [data[0] * 0.8]};
   
   // Calculate optimal window size (between 2 and 5)
   int windowSize = min(5, max(2, data.length ~/ 3));
   
   // For short data, use smaller window
   if (data.length < 10) {
     windowSize = min(windowSize, data.length ~/ 2);
   }
   
   // Calculate the last moving average
   List<double> lastWindow = data.sublist(data.length - windowSize);
   double nextValue = lastWindow.reduce((a, b) => a + b) / windowSize;
   
   // Generate forecast
   List<double> forecast = [];
   List<double> upper = [];
   List<double> lower = [];
   
   // Calculate average error
   double sumError = 0.0;
   int errorCount = 0;
   
   for (int i = windowSize; i < data.length; i++) {
     double ma = 0.0;
     for (int j = 0; j < windowSize; j++) {
       ma += data[i - j - 1];
     }
     ma /= windowSize;
     sumError += (data[i] - ma).abs();
     errorCount++;
   }
   
   double avgError = errorCount > 0 ? sumError / errorCount : data.last * 0.1;
   
   // First forecast is the most recent moving average
   forecast.add(nextValue);
   upper.add(nextValue + avgError);
   lower.add(max(0.0, nextValue - avgError));
   
   // For subsequent periods, assume the same value with widening bounds
   for (int i = 1; i < _forecastHorizon; i++) {
     forecast.add(nextValue);
     upper.add(nextValue + avgError * (1 + i * 0.1));
     lower.add(max(0.0, nextValue - avgError * (1 + i * 0.1)));
   }
   
   return {
     'nextValue': nextValue,
     'forecast': forecast,
     'upperBound': upper,
     'lowerBound': lower,
   };
 }

 Map<String, dynamic> _exponentialSmoothingForecasting(List<double> data) {
   if (data.isEmpty) return {'nextValue': 0.0, 'forecast': [], 'upperBound': [], 'lowerBound': []};
   if (data.length == 1) return {'nextValue': data[0], 'forecast': [data[0]], 'upperBound': [data[0] * 1.2], 'lowerBound': [data[0] * 0.8]};
   
   // Find optimal alpha
   double bestAlpha = 0.3; // Default
   double minError = double.infinity;
   
   // Try different alpha values to find the best one
   for (double alpha = 0.1; alpha <= 0.9; alpha += 0.1) {
     double error = 0.0;
     double forecast = data[0];
     
     for (int i = 1; i < data.length; i++) {
       forecast = alpha * data[i-1] + (1 - alpha) * forecast;
       error += pow(data[i] - forecast, 2);
     }
     
     if (error < minError) {
       minError = error;
       bestAlpha = alpha;
     }
   }
   
   // Calculate final forecast
   double lastForecast = data[0];
   List<double> errors = [];
   
   for (int i = 1; i < data.length; i++) {
     double newForecast = bestAlpha * data[i-1] + (1 - bestAlpha) * lastForecast;
     errors.add((data[i] - newForecast).abs());
     lastForecast = newForecast;
   }
   
   // Calculate last value
   double nextValue = bestAlpha * data.last + (1 - bestAlpha) * lastForecast;
   
   // Calculate average error
   double avgError = errors.isNotEmpty ? errors.reduce((a, b) => a + b) / errors.length : data.last * 0.1;
   
   // Generate forecast
   List<double> forecast = [];
   List<double> upper = [];
   List<double> lower = [];
   
   // First forecast
   forecast.add(nextValue);
   upper.add(nextValue + avgError);
   lower.add(max(0.0, nextValue - avgError));
   
   // Subsequent forecasts (constant for exponential smoothing)
   double currentForecast = nextValue;
   for (int i = 1; i < _forecastHorizon; i++) {
     forecast.add(currentForecast);
     upper.add(currentForecast + avgError * (1 + i * 0.2));
     lower.add(max(0.0, currentForecast - avgError * (1 + i * 0.2)));
   }
   
   return {
     'nextValue': nextValue,
     'forecast': forecast,
     'upperBound': upper,
     'lowerBound': lower,
   };
 }

 Map<String, dynamic> _arimaForecasting(List<double> data) {
   if (data.isEmpty) return {'nextValue': 0.0, 'forecast': [], 'upperBound': [], 'lowerBound': []};
   if (data.length == 1) return {'nextValue': data[0], 'forecast': [data[0]], 'upperBound': [data[0] * 1.2], 'lowerBound': [data[0] * 0.8]};
   
   // Simplified ARIMA(1,1,1) implementation
   // Step 1: Difference the data
   List<double> diffData = [];
   for (int i = 1; i < data.length; i++) {
     diffData.add(data[i] - data[i-1]);
   }
   
   // Step 2: Estimate AR(1) coefficient
   double arCoef = 0.0;
   double sumProduct = 0.0;
   double sumSquared = 0.0;
   
   for (int i = 1; i < diffData.length; i++) {
     sumProduct += diffData[i] * diffData[i-1];
     sumSquared += diffData[i-1] * diffData[i-1];
   }
   
   if (sumSquared > 0) {
     arCoef = sumProduct / sumSquared;
   }
   
   // Cap AR coefficient to ensure stability
   arCoef = max(-0.99, min(0.99, arCoef));
   
   // Step 3: Estimate MA(1) coefficient - simplified approach
   double maCoef = 0.5; // Simplified estimate
   
   // Step 4: Forecast
   List<double> forecast = [];
   List<double> upper = [];
   List<double> lower = [];
   
   // Calculate average error
   double sumError = 0.0;
   int errorCount = 0;
   
   for (int i = 1; i < diffData.length; i++) {
     double predicted = arCoef * diffData[i-1];
     sumError += (diffData[i] - predicted).abs();
     errorCount++;
   }
   
   double avgError = errorCount > 0 ? sumError / errorCount : diffData.last.abs() * 0.1;
   
   // First forecast for differenced series
   double lastDiff = diffData.last;
   double nextDiff = arCoef * lastDiff;
   
   // Convert back to original scale
   double nextValue = data.last + nextDiff;
   forecast.add(nextValue);
   upper.add(nextValue + avgError);
   lower.add(max(0.0, nextValue - avgError));
   
   // For remaining periods
   double currentValue = nextValue;
   double currentDiff = nextDiff;
   
   for (int i = 1; i < _forecastHorizon; i++) {
     currentDiff = arCoef * currentDiff;
     currentValue += currentDiff;
     
     forecast.add(currentValue);
     upper.add(currentValue + avgError * (1 + i * 0.3));
     lower.add(max(0.0, currentValue - avgError * (1 + i * 0.3)));
   }
   
   return {
     'nextValue': nextValue,
     'forecast': forecast,
     'upperBound': upper,
     'lowerBound': lower,
   };
 }

 Map<String, dynamic> _neuralNetworkForecasting(List<double> data) {
   if (data.isEmpty) return {'nextValue': 0.0, 'forecast': [], 'upperBound': [], 'lowerBound': []};
   if (data.length == 1) return {'nextValue': data[0], 'forecast': [data[0]], 'upperBound': [data[0] * 1.2], 'lowerBound': [data[0] * 0.8]};
   
   // For a simple forecast, use exponential smoothing with trend and seasonality detection
   // In a real implementation, this would use an actual neural network library
   
   // Normalize the data
   double minValue = data.reduce(min);
   double maxValue = data.reduce(max);
   double range = maxValue - minValue > 0 ? maxValue - minValue : 1.0;
   
   List<double> normalized = data.map((v) => (v - minValue) / range).toList();
   
   // Detect season length (if any)
   int seasonLength = _detectSeasonLength(normalized);
   
   // Forecast using triple exponential smoothing (Holt-Winters)
   double alpha = 0.3; // Smoothing factor
   double beta = 0.1;  // Trend factor
   double gamma = 0.1; // Seasonal factor
   
   // Initialize level, trend, and seasonal components
   double level = normalized[0];
   double trend = normalized.length > 1 ? (normalized[1] - normalized[0]) : 0.0;
   List<double> seasonal = List.filled(max(1, seasonLength), 0.0);
   
   // Initialize seasonal factors
   if (seasonLength > 1 && normalized.length >= seasonLength) {
     for (int i = 0; i < seasonLength; i++) {
       seasonal[i] = normalized[i] / level;
     }
   } else {
     seasonal[0] = 1.0;
   }
   
   // Apply triple smoothing
   for (int i = 0; i < normalized.length; i++) {
     int season = seasonLength > 1 ? i % seasonLength : 0;
     double levelPrev = level;
     
     if (seasonLength > 1) {
       level = alpha * (normalized[i] / seasonal[season]) + (1 - alpha) * (level + trend);
       trend = beta * (level - levelPrev) + (1 - beta) * trend;
       seasonal[season] = gamma * (normalized[i] / level) + (1 - gamma) * seasonal[season];
     } else {
       level = alpha * normalized[i] + (1 - alpha) * (level + trend);
       trend = beta * (level - levelPrev) + (1 - beta) * trend;
     }
   }
   
   // Generate forecast
   List<double> normalizedForecast = [];
   List<double> normalizedUpper = [];
   List<double> normalizedLower = [];
   
   for (int i = 0; i < _forecastHorizon; i++) {
     int season = seasonLength > 1 ? (normalized.length + i) % seasonLength : 0;
     double forecast = (level + (i + 1) * trend) * (seasonLength > 1 ? seasonal[season] : 1.0);
     
     normalizedForecast.add(forecast);
     
     // Uncertainty increases with time
     double uncertainty = 0.1 + 0.01 * i;
     normalizedUpper.add(min(1.0, forecast + uncertainty));
     normalizedLower.add(max(0.0, forecast - uncertainty));
   }
   
   // De-normalize
   List<double> forecast = normalizedForecast.map((v) => v * range + minValue).toList();
   List<double> upper = normalizedUpper.map((v) => v * range + minValue).toList();
   List<double> lower = normalizedLower.map((v) => v * range + minValue).toList();
   
   return {
     'nextValue': forecast.isNotEmpty ? forecast[0] : (data.last + trend * range),
     'forecast': forecast,
     'upperBound': upper,
     'lowerBound': lower,
   };
 }

 int _detectSeasonLength(List<double> data) {
   if (data.length < 4) return 1; // Not enough data
   
   // Try common season lengths (12 for monthly, 4 for quarterly, 7 for weekly)
   List<int> candidateSeasons = [4, 7, 12];
   double bestCorrelation = 0.0;
   int bestSeason = 1;
   
   for (int seasonLength in candidateSeasons) {
     if (data.length < seasonLength * 2) continue;
     
     double correlation = 0.0;
     int count = 0;
     
     for (int i = 0; i < data.length - seasonLength; i++) {
       correlation += data[i] * data[i + seasonLength];
       count++;
     }
     
     correlation = count > 0 ? correlation / count : 0.0;
     
     if (correlation > bestCorrelation) {
       bestCorrelation = correlation;
       bestSeason = seasonLength;
     }
   }
   
   return bestCorrelation > 0.3 ? bestSeason : 1;
 }

 double _calculateTrendScore(List<double> historical, List<double> forecast) {
   if (historical.isEmpty || forecast.isEmpty) return 0.0;
   
   // Calculate recent trend
   int recentWindow = min(6, historical.length);
   List<double> recent = historical.sublist(historical.length - recentWindow);
   
   double recentStart = recent.first;
   double recentEnd = recent.last;
   double recentChange = recentEnd - recentStart;
   double recentPercentChange = recentStart > 0 ? (recentChange / recentStart) * 100 : 0.0;
   
   // Calculate forecast trend
   double forecastStart = forecast.first;
   double forecastEnd = forecast.last;
   double forecastChange = forecastEnd - forecastStart;
   double forecastPercentChange = forecastStart > 0 ? (forecastChange / forecastStart) * 100 : 0.0;
   
   // Combine with weights
   double trendScore = (recentPercentChange * 0.4) + (forecastPercentChange * 0.6);
   
   // Apply external factor influence
   if (_includeExternalFactors) {
     double externalInfluence = _calculateExternalFactorInfluence();
     trendScore = trendScore * (1 + externalInfluence);
   }
   
   // Cap the score
   return max(-100.0, min(100.0, trendScore));
 }

 double _calculateExternalFactorInfluence() {
   // Simplified external factor influence (random in this demo)
   // In a real implementation, this would use actual external data
   return _includeExternalFactors ? (Random().nextDouble() * 0.3 - 0.15) : 0.0;
 }

 int _calculateForecastAccuracy(List<double> data) {
   if (data.length < 6) return 70; // Default
   
   // Calculate accuracy based on past performance
   List<double> errors = [];
   List<double> historical = data.sublist(0, data.length - 1);
   Map<String, dynamic> pastForecast = _applyForecastMethod(historical);
   
   double actual = data.last;
   double predicted = pastForecast['nextValue'] ?? historical.last;
   
   double error = ((actual - predicted).abs() / (actual > 0 ? actual : 1)) * 100;
   int accuracy = max(0, min(100, 100 - error.round()));
   
   // Apply adjustment based on data volatility
   double volatility = _calculateVolatility(data);
   if (volatility > 0.3) {
     accuracy = max(50, accuracy - 10);
   } else if (volatility < 0.1) {
     accuracy = min(95, accuracy + 5);
   }
   
   return accuracy;
 }

 double _calculateVolatility(List<double> data) {
   if (data.length < 2) return 0.0;
   
   double mean = data.reduce((a, b) => a + b) / data.length;
   double sumSquaredDiff = 0.0;
   
   for (double value in data) {
     sumSquaredDiff += pow(value - mean, 2);
   }
   
   double variance = sumSquaredDiff / data.length;
   double stdDev = sqrt(variance);
   
   return mean > 0 ? stdDev / mean : stdDev;
 }

 String _generateRecommendation(
   double avgQuantity,
   double forecastQuantity,
   double currentStock,
   String productName,
   double trendScore,
 ) {
   // Days of inventory
   double daysOfStock = avgQuantity > 0 ? currentStock / avgQuantity : 0;
   double adjustedForecast = forecastQuantity * (1 + trendScore / 100);
   
   if (trendScore > 15) {
     // Strong upward trend
     if (currentStock < adjustedForecast * 1.5) {
       return 'Tăng mạnh: Nhu cầu về "$productName" dự kiến tăng ${trendScore.toStringAsFixed(1)}%. Cần tăng đặt hàng ${(adjustedForecast * 1.5 - currentStock).toStringAsFixed(1)} đơn vị.';
     } else {
       return 'Tăng mạnh: Nhu cầu về "$productName" dự kiến tăng ${trendScore.toStringAsFixed(1)}%. Tồn kho hiện tại đủ cho ${daysOfStock.toStringAsFixed(0)} ngày.';
     }
   } else if (trendScore > 5) {
     // Moderate upward trend
     if (currentStock < adjustedForecast * 1.2) {
       return 'Tăng nhẹ: Nhu cầu về "$productName" có xu hướng tăng. Khuyến nghị tăng đặt hàng thêm ${(adjustedForecast * 1.2 - currentStock).toStringAsFixed(1)} đơn vị.';
     } else {
       return 'Tăng nhẹ: Nhu cầu về "$productName" có xu hướng tăng. Tồn kho hiện tại phù hợp.';
     }
   } else if (trendScore < -15) {
     // Strong downward trend
     if (currentStock > adjustedForecast * 2) {
       return 'Giảm mạnh: Nhu cầu về "$productName" dự kiến giảm ${(-trendScore).toStringAsFixed(1)}%. Cần giảm đặt hàng và xem xét khuyến mãi để giảm tồn kho.';
     } else {
       return 'Giảm mạnh: Nhu cầu về "$productName" dự kiến giảm ${(-trendScore).toStringAsFixed(1)}%. Tránh đặt hàng thêm.';
     }
   } else if (trendScore < -5) {
     // Moderate downward trend
     if (currentStock > adjustedForecast * 1.5) {
       return 'Giảm nhẹ: Nhu cầu về "$productName" có xu hướng giảm. Khuyến nghị giảm đặt hàng hoặc áp dụng chương trình khuyến mãi.';
     } else {
       return 'Giảm nhẹ: Nhu cầu về "$productName" có xu hướng giảm. Duy trì tồn kho ở mức hiện tại.';
     }
   } else {
     // Stable trend
     if (currentStock < adjustedForecast) {
       return 'Ổn định: Nhu cầu về "$productName" duy trì ổn định. Tồn kho hiện tại thấp, khuyến nghị bổ sung thêm ${(adjustedForecast - currentStock).toStringAsFixed(1)} đơn vị.';
     } else if (currentStock > adjustedForecast * 3) {
       return 'Ổn định: Nhu cầu về "$productName" duy trì ổn định. Tồn kho hiện tại cao, cân nhắc giảm lượng đặt hàng.';
     } else {
       return 'Ổn định: Nhu cầu về "$productName" duy trì ổn định. Tồn kho hiện tại phù hợp với nhu cầu dự kiến.';
     }
   }
 }

 List<String> _generateDetailedRecommendations(
   double avgQuantity,
   double forecastQuantity,
   double currentStock,
   double trendScore,
   List<double> historicalData,
 ) {
   List<String> recommendations = [];
   
   // Stock recommendations
   double stockCoverage = avgQuantity > 0 ? currentStock / avgQuantity : 0;
   double adjustedForecast = forecastQuantity * (1 + trendScore / 100);
   
   if (currentStock < adjustedForecast) {
     recommendations.add('Tồn kho hiện tại thấp hơn nhu cầu dự báo. Cần đặt thêm ít nhất ${(adjustedForecast - currentStock).toStringAsFixed(1)} đơn vị.');
   } else if (currentStock > adjustedForecast * 3) {
     recommendations.add('Tồn kho hiện tại cao (${stockCoverage.toStringAsFixed(0)} ngày), cân nhắc giảm đặt hàng hoặc tạo chương trình khuyến mãi.');
   }
   
   // Trend recommendations
   if (trendScore > 15) {
     recommendations.add('Xu hướng tăng mạnh (${trendScore.toStringAsFixed(1)}%). Cân nhắc tăng giá hoặc đảm bảo nguồn cung ứng.');
   } else if (trendScore < -15) {
     recommendations.add('Xu hướng giảm mạnh (${(-trendScore).toStringAsFixed(1)}%). Xem xét điều chỉnh chiến lược giá hoặc khuyến mãi.');
   }
   
   // Volatility recommendations
   double volatility = _calculateVolatility(historicalData);
   if (volatility > 0.3) {
     recommendations.add('Nhu cầu sản phẩm có độ biến động cao. Duy trì tồn kho an toàn và theo dõi chặt chẽ.');
   }
   
   // Seasonality recommendation
   if (historicalData.length > 12) {
     int seasonLength = _detectSeasonLength(historicalData);
     if (seasonLength > 1) {
       recommendations.add('Phát hiện chu kỳ mùa vụ $seasonLength tháng. Điều chỉnh kế hoạch đặt hàng theo chu kỳ này.');
     }
   }
   
   // Add external factor recommendations if enabled
   if (_includeExternalFactors) {
     recommendations.add('Các yếu tố bên ngoài (thời tiết, sự kiện, v.v.) đang tác động đến nhu cầu. Xem phân tích chuyên sâu để biết thêm chi tiết.');
   }
   
   return recommendations;
 }

 List<Map<String, dynamic>> _generateInfluenceFactors(
   String productId,
   Map<String, dynamic> productInfo,
   List<double> historicalData,
   List<double> forecastData,
 ) {
   List<Map<String, dynamic>> factors = [];
   
   // Add price elasticity
   factors.add({
     'type': 'price',
     'name': 'Độ co giãn theo giá',
     'impact': -5.8,
   });
   
   // Seasonal factors
   int seasonLength = _detectSeasonLength(historicalData);
   if (seasonLength > 1) {
     factors.add({
       'type': 'seasonal',
       'name': 'Yếu tố mùa vụ',
       'impact': 7.2,
     });
   }
   
   // Product category growth
   String category = productInfo['PhanLoai1'] ?? 'Không phân loại';
   if (_categoryData.containsKey(category)) {
     double categoryGrowth = _categoryData[category]?['avgMonthlyGrowth'] ?? 0.0;
     factors.add({
       'type': 'category',
       'name': 'Tăng trưởng danh mục $category',
       'impact': categoryGrowth,
     });
   }
   
   // External factors if enabled
   if (_includeExternalFactors) {
     if (Random().nextBool()) {
       factors.add({
         'type': 'weather',
         'name': 'Ảnh hưởng thời tiết',
         'impact': 3.4,
       });
     }
     
     if (Random().nextBool()) {
       factors.add({
         'type': 'holiday',
         'name': 'Sự kiện/Lễ hội sắp tới',
         'impact': 8.5,
       });
     }
     
     if (Random().nextBool()) {
       factors.add({
         'type': 'market',
         'name': 'Biến động thị trường',
         'impact': -2.7,
       });
     }
   }
   
   // Add volatility as a factor
   double volatility = _calculateVolatility(historicalData);
   factors.add({
     'type': 'volatility',
     'name': 'Độ biến động nhu cầu',
     'impact': volatility > 0.3 ? -4.2 : (volatility < 0.1 ? 2.8 : 0.0),
   });
   
   return factors;
 }

 Map<String, List<double>> _analyzeSeasonalTrends(List<Map<String, dynamic>> orders) {
   Map<String, List<double>> result = {};
   
   // Initialize month lists
   for (int month = 1; month <= 12; month++) {
     result['month_$month'] = [];
   }
   
   // Group sales by month
   for (var order in orders) {
     final date = DateTime.tryParse(order['updateTime'] ?? '');
     if (date != null) {
       final month = date.month;
       final quantity = _getDoubleValue(order['soLuongYeuCau']);
       result['month_$month']!.add(quantity);
     }
   }
   
   return result;
 }

 Map<String, dynamic> _yearOverYearAnalysis(List<Map<String, dynamic>> orders) {
   Map<int, Map<int, double>> yearMonthSales = {};
   
   // Group sales by year and month
   for (var order in orders) {
     final date = DateTime.tryParse(order['updateTime'] ?? '');
     if (date != null) {
       final year = date.year;
       final month = date.month;
       
       if (!yearMonthSales.containsKey(year)) {
         yearMonthSales[year] = {};
       }
       
       if (!yearMonthSales[year]!.containsKey(month)) {
         yearMonthSales[year]![month] = 0.0;
       }
       
       final quantity = _getDoubleValue(order['soLuongYeuCau']);
       yearMonthSales[year]![month] = yearMonthSales[year]![month]! + quantity;
     }
   }
   
   // Calculate year-over-year growth for each month
   Map<int, Map<String, double>> yoyGrowth = {};
   
   // Get list of years in ascending order
   List<int> years = yearMonthSales.keys.toList()..sort();
   
   // Skip the first year as we need a previous year to compare
   for (int i = 1; i < years.length; i++) {
     final currentYear = years[i];
     final previousYear = years[i-1];
     
     yoyGrowth[currentYear] = {};
     
     // Compare each month
     for (int month = 1; month <= 12; month++) {
       final currentYearValue = yearMonthSales[currentYear]?[month] ?? 0.0;
       final previousYearValue = yearMonthSales[previousYear]?[month] ?? 0.0;
       
       // Avoid division by zero
       if (previousYearValue > 0) {
         final growth = ((currentYearValue - previousYearValue) / previousYearValue) * 100;
         yoyGrowth[currentYear]!['$month'] = growth;
       } else if (currentYearValue > 0) {
         // Previous was zero, current is positive - infinite growth, cap at 100%
         yoyGrowth[currentYear]!['$month'] = 100.0;
       } else {
         // Both zero
         yoyGrowth[currentYear]!['$month'] = 0.0;
       }
     }
   }
   
   return {
     'yearMonthSales': yearMonthSales,
     'yoyGrowth': yoyGrowth,
   };
 }

 Map<String, Map<String, dynamic>> _categoryAnalysis(
     List<Map<String, dynamic>> orders,
     List<Map<String, dynamic>> products) {
   
   // Group products by category
   Map<String, List<String>> categoryProducts = {};
   
   for (var product in products) {
     final category = product['PhanLoai1']?.toString() ?? 'Không phân loại';
     final productId = product['uid']?.toString() ?? '';
     
     if (productId.isNotEmpty) {
       if (!categoryProducts.containsKey(category)) {
         categoryProducts[category] = [];
       }
       categoryProducts[category]!.add(productId);
     }
   }
   
   // Analyze sales by category
   Map<String, Map<String, dynamic>> results = {};
   
   categoryProducts.forEach((category, productIds) {
     final categoryOrders = orders.where(
       (order) => productIds.contains(order['idHang']?.toString() ?? '')
     ).toList();
     
     // Group by month
     Map<String, double> monthlySales = {};
     
     for (var order in categoryOrders) {
       final date = DateTime.tryParse(order['updateTime'] ?? '');
       if (date != null) {
         final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
         
         if (!monthlySales.containsKey(monthKey)) {
           monthlySales[monthKey] = 0.0;
         }
         
         final quantity = _getDoubleValue(order['soLuongYeuCau']);
         monthlySales[monthKey] = monthlySales[monthKey]! + quantity;
       }
     }
     
     // Calculate growth trend
     List<double> monthlyValues = monthlySales.values.toList();
     double avgMonthlyGrowth = 0.0;
     
     if (monthlyValues.length > 1) {
       double sumGrowth = 0.0;
       int growthPoints = 0;
       
       for (int i = 1; i < monthlyValues.length; i++) {
         if (monthlyValues[i-1] > 0) {
           sumGrowth += (monthlyValues[i] - monthlyValues[i-1]) / monthlyValues[i-1];
           growthPoints++;
         }
       }
       
       avgMonthlyGrowth = growthPoints > 0 ? sumGrowth / growthPoints * 100 : 0.0;
     }
     
     // Calculate total quantity
     final totalQuantity = categoryOrders.fold(0.0, (double sum, order) => 
       sum + _getDoubleValue(order['soLuongYeuCau']));
     
     // Get top products in category
     Map<String, double> productQuantities = {};
     for (var order in categoryOrders) {
       final productId = order['idHang']?.toString() ?? '';
       final quantity = _getDoubleValue(order['soLuongYeuCau']);
       
       if (!productQuantities.containsKey(productId)) {
         productQuantities[productId] = 0.0;
       }
       
       productQuantities[productId] = productQuantities[productId]! + quantity;
     }
     
     // Convert to list and sort
     List<Map<String, dynamic>> topProducts = [];
     productQuantities.forEach((productId, quantity) {
       final product = products.firstWhere(
         (p) => p['uid'] == productId,
         orElse: () => {'TenSanPham': 'Sản phẩm không xác định'},
       );
       
       topProducts.add({
         'id': productId,
         'name': product['TenSanPham'] ?? 'Sản phẩm không xác định',
         'quantity': quantity,
       });
     });
     
     topProducts.sort((a, b) => (b['quantity'] as double).compareTo(a['quantity'] as double));
     
     results[category] = {
       'totalSales': categoryOrders.length,
       'totalQuantity': totalQuantity,
       'monthlySales': monthlySales,
       'avgMonthlyGrowth': avgMonthlyGrowth,
       'trend': avgMonthlyGrowth > 1.0 ? 'Tăng' : 
                avgMonthlyGrowth < -1.0 ? 'Giảm' : 'Ổn định',
       'topProducts': topProducts.take(5).toList(),
     };
   });
   
   return results;
 }

 Future<void> _fetchExternalFactors() async {
   try {
     // In a real implementation, this would fetch data from external APIs
     
     // Simulate API delay
     await Future.delayed(Duration(milliseconds: 500));
     
     // Dummy economic indicators
     _externalFactors['economicIndicators'] = {
       'gdpGrowth': 3.2,
       'inflation': 2.1,
       'consumerIndex': 112.5,
     };
     
     // Dummy holidays
     _externalFactors['holidays'] = [
       {'name': 'Tết Nguyên Đán', 'date': '2026-01-25', 'impact': 'high'},
       {'name': 'Quốc Khánh', 'date': '2025-09-02', 'impact': 'medium'},
       {'name': 'Lễ Quốc tế Lao động', 'date': '2025-05-01', 'impact': 'low'},
     ];
     
     // Dummy weather data
     _externalFactors['weatherData'] = {
       'currentSeason': 'Mùa hè',
       'temperatureTrend': 'Nóng hơn trung bình',
       'rainfallTrend': 'Ít mưa hơn trung bình',
     };
     
     // Dummy market trends
     _externalFactors['marketTrends'] = {
       'competitorActivity': 'Trung bình',
       'industryGrowth': 4.5,
       'consumerConfidence': 'Tăng',
     };
   } catch (e) {
     print('Error fetching external factors: $e');
   }
 }

 Future<void> _importFromCSV() async {
   try {
     FilePickerResult? result = await FilePicker.platform.pickFiles(
       type: FileType.custom,
       allowedExtensions: ['csv'],
     );
     
     if (result != null) {
       File file = File(result.files.single.path!);
       String content = await file.readAsString();
       
       // Parse CSV
       List<List<dynamic>> rows = const CsvToListConverter().convert(content);
       
       // Process the data
       // This is a placeholder - in a real implementation, you would map this to your data model
       
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Đã nhập dữ liệu từ CSV thành công (${rows.length} dòng)'),
           backgroundColor: Colors.green,
         ),
       );
       
       // Trigger analysis
       _performTrendAnalysis();
     }
   } catch (e) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Lỗi khi nhập dữ liệu: ${e.toString()}'),
         backgroundColor: Colors.red,
       ),
     );
   }
 }

 Future<void> _importFromAPI() async {
   // Show API connection dialog
   showDialog(
     context: context,
     builder: (context) => AlertDialog(
       title: Text('Kết nối API'),
       content: Column(
         mainAxisSize: MainAxisSize.min,
         children: [
           TextField(
             decoration: InputDecoration(
               labelText: 'URL API',
               hintText: 'https://api.example.com/data',
             ),
           ),
           SizedBox(height: 16),
           TextField(
             decoration: InputDecoration(
               labelText: 'API Key (nếu cần)',
             ),
             obscureText: true,
           ),
         ],
       ),
       actions: [
         TextButton(
           onPressed: () => Navigator.of(context).pop(),
           child: Text('Huỷ bỏ'),
         ),
         ElevatedButton(
           onPressed: () {
             Navigator.of(context).pop();
             _fetchDataFromAPI();
           },
           style: ElevatedButton.styleFrom(
             backgroundColor: Colors.orange,
           ),
           child: Text('Kết nối'),
         ),
       ],
     ),
   );
 }

 Future<void> _fetchDataFromAPI() async {
   setState(() {
     _isLoading = true;
   });
   
   try {
     // Simulate API call
     await Future.delayed(Duration(seconds: 2));
     
     // Dummy data
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Đã nhập dữ liệu từ API thành công'),
         backgroundColor: Colors.green,
       ),
     );
     
     // Trigger analysis
     _performTrendAnalysis();
   } catch (e) {
     setState(() {
       _isLoading = false;
     });
     
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Lỗi khi nhập dữ liệu: ${e.toString()}'),
         backgroundColor: Colors.red,
       ),
     );
   }
 }

 Future<void> _loadSampleData() async {
   setState(() {
     _isLoading = true;
   });
   
   try {
     // Simulate loading
     await Future.delayed(Duration(seconds: 2));
     
     // Notify success
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Đã tải dữ liệu mẫu thành công'),
         backgroundColor: Colors.green,
       ),
     );
     
     // Trigger analysis
     _performTrendAnalysis();
   } catch (e) {
     setState(() {
       _isLoading = false;
     });
     
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Lỗi khi tải dữ liệu mẫu: ${e.toString()}'),
         backgroundColor: Colors.red,
       ),
     );
   }
 }

 Future<void> _exportToCSV() async {
   try {
     // Create CSV data
     List<List<dynamic>> rows = [];
     
     // Add header
     rows.add([
       'Mã sản phẩm', 
       'Tên sản phẩm', 
       'Danh mục', 
       'Lượng bán TB',
       'Dự đoán',
       'Tồn kho',
       'Xu hướng',
       'Khuyến nghị'
     ]);
     
     // Add data rows
     for (var item in _trendResults) {
       rows.add([
         item['product_id'] ?? '',
         item['product_name'] ?? '',
         item['category'] ?? '',
         item['avg_quantity']?.toStringAsFixed(1) ?? '0',
         item['forecast_quantity']?.toStringAsFixed(1) ?? '0',
         item['current_stock']?.toStringAsFixed(1) ?? '0',
         item['trend'] ?? '',
         item['recommendation'] ?? '',
       ]);
     }
     
     // Convert to CSV
     String csv = const ListToCsvConverter().convert(rows);
     
     // Save file - in a real mobile app, you would use proper file saving mechanism
     // This is just a simulation
     
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Đã xuất dữ liệu CSV thành công'),
         backgroundColor: Colors.green,
       ),
     );
   } catch (e) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Lỗi khi xuất dữ liệu: ${e.toString()}'),
         backgroundColor: Colors.red,
       ),
     );
   }
 }

 Future<void> _exportToPDF() async {
   try {
     // In a real implementation, this would create a PDF file
     // This is just a simulation
     
     await Future.delayed(Duration(seconds: 1));
     
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Đã xuất báo cáo PDF thành công'),
         backgroundColor: Colors.green,
       ),
     );
   } catch (e) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Lỗi khi xuất báo cáo: ${e.toString()}'),
         backgroundColor: Colors.red,
       ),
     );
   }
 }

 Future<void> _shareResults() async {
   try {
     // In a real implementation, this would share data via platform share
     // This is just a simulation
     
     await Future.delayed(Duration(seconds: 1));
     
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Đã chia sẻ kết quả thành công'),
         backgroundColor: Colors.green,
       ),
     );
   } catch (e) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Lỗi khi chia sẻ kết quả: ${e.toString()}'),
         backgroundColor: Colors.red,
       ),
     );
   }
 }

 void _exportProduct(Map<String, dynamic> product) {
   try {
     // In a real implementation, this would export product data
     // This is just a simulation
     
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Đã chia sẻ thông tin sản phẩm thành công'),
         backgroundColor: Colors.green,
       ),
     );
   } catch (e) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Lỗi khi chia sẻ thông tin: ${e.toString()}'),
         backgroundColor: Colors.red,
       ),
     );
   }
 }

 Future<void> _updateProductForecast(Map<String, dynamic> product) async {
   setState(() {
     _isLoading = true;
   });
   
   try {
     // Re-analyze the specific product
     final orders = await _dbHelper.getCompletedOrderItems();
     final productOrders = orders.where((order) => order['idHang']?.toString() == product['product_id']).toList();
     final products = await _dbHelper.getAllProducts();
     final stockLevels = await _dbHelper.getAllStockLevels();
     
     // Analyze for the specific product
     List<Map<String, dynamic>> results = _analyzeTrends(
       productOrders, 
       products, 
       stockLevels, 
       _selectedBranch == 'Tất cả' ? 'all' : _selectedBranch
     );
     
     // Update the results
     if (results.isNotEmpty) {
       if (_selectedBranch == 'Tất cả') {
         int index = _trendResults.indexWhere((item) => item['product_id'] == product['product_id']);
         if (index >= 0) {
           setState(() {
             _trendResults[index] = results[0];
             _isLoading = false;
           });
         }
       } else {
         int index = _branchResults[_selectedBranch]!.indexWhere((item) => item['product_id'] == product['product_id']);
         if (index >= 0) {
           setState(() {
             _branchResults[_selectedBranch]![index] = results[0];
             _isLoading = false;
           });
         }
       }
       
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Đã cập nhật dự báo thành công'),
           backgroundColor: Colors.green,
         ),
       );
     } else {
       setState(() {
         _isLoading = false;
       });
       
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Không tìm thấy dữ liệu mới cho sản phẩm này'),
           backgroundColor: Colors.orange,
         ),
       );
     }
   } catch (e) {
     setState(() {
       _isLoading = false;
     });
     
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Lỗi khi cập nhật dự báo: ${e.toString()}'),
         backgroundColor: Colors.red,
       ),
     );
   }
 }

 Color _getTrendColor(double? score) {
   if (score == null) return Colors.grey;
   if (score > 15) return Colors.green;
   if (score > 5) return Colors.lightGreen;
   if (score < -15) return Colors.red;
   if (score < -5) return Colors.orange;
   return Colors.blue;
 }

 String _getTrendLabel(double? score) {
   if (score == null) return 'Chưa xác định';
   if (score > 15) return 'Tăng mạnh';
   if (score > 5) return 'Tăng nhẹ';
   if (score < -15) return 'Giảm mạnh';
   if (score < -5) return 'Giảm nhẹ';
   return 'Ổn định';
 }

 Color _getFactorColor(double impact) {
   if (impact > 5) return Colors.green;
   if (impact > 0) return Colors.lightGreen;
   if (impact < -5) return Colors.red;
   if (impact < 0) return Colors.orange;
   return Colors.blue;
 }

 IconData _getFactorIcon(String type) {
   switch (type) {
     case 'price':
       return Icons.attach_money;
     case 'seasonal':
       return Icons.calendar_today;
     case 'category':
       return Icons.category;
     case 'weather':
       return Icons.cloud;
     case 'holiday':
       return Icons.celebration;
     case 'market':
       return Icons.trending_up;
     case 'volatility':
       return Icons.swap_vert;
     default:
       return Icons.info_outline;
   }
 }

 String _getMonthlyTrend(int monthIndex) {
   final seasons = [
     'Mua sắm sau Tết', // Jan
     'Giảm sau Tết', // Feb
     'Mua sắm đầu quý', // Mar
     'Mua sắm hàng hè', // Apr
     'Tăng nhẹ', // May
     'Mua sắm hè', // Jun
     'Cao điểm du lịch', // Jul
     'Chuẩn bị khai giảng', // Aug
     'Mua sắm đầu quý', // Sep
     'Chuẩn bị mùa lễ hội', // Oct
     'Mua sắm Black Friday', // Nov
     'Mua sắm cuối năm', // Dec
   ];
   
   if (monthIndex >= 1 && monthIndex <= 12) {
     return seasons[monthIndex - 1];
   }
   return 'Không xác định';
 }

 Widget _getMonthlyInfluenceFactors(int monthIndex) {
   final List<Map<String, dynamic>> factors = [];
   
   switch (monthIndex) {
     case 1:
       factors.add({'name': 'Tết Nguyên Đán', 'impact': 15.5});
       factors.add({'name': 'Thời tiết lạnh', 'impact': -3.2});
       break;
     case 2:
       factors.add({'name': 'Sau kỳ nghỉ Tết', 'impact': -5.7});
       break;
     case 7:
       factors.add({'name': 'Cao điểm du lịch', 'impact': 8.4});
       factors.add({'name': 'Thời tiết nóng', 'impact': 4.2});
       break;
     case 11:
       factors.add({'name': 'Black Friday', 'impact': 12.8});
       factors.add({'name': 'Chuẩn bị cuối năm', 'impact': 7.5});
       break;
     case 12:
       factors.add({'name': 'Lễ hội cuối năm', 'impact': 10.2});
       factors.add({'name': 'Tặng quà', 'impact': 9.7});
       break;
     default:
       if (Random().nextBool()) {
         factors.add({'name': 'Yếu tố theo mùa', 'impact': Random().nextDouble() * 10 - 5});
       }
   }
   
   if (factors.isEmpty) {
     return Text('Không có yếu tố ảnh hưởng đặc biệt');
   }
   
   return Column(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: factors.map((factor) {
       final impact = factor['impact'] as double;
       final color = impact > 0 ? Colors.green : Colors.red;
       
       return Padding(
         padding: EdgeInsets.only(bottom: 4),
         child: Row(
           children: [
             Container(
               width: 4,
               height: 16,
               color: color,
               margin: EdgeInsets.only(right: 8),
             ),
             Expanded(
               child: Text(factor['name']),
             ),
             Text(
               '${impact > 0 ? '+' : ''}${impact.toStringAsFixed(1)}%',
               style: TextStyle(
                 color: color,
                 fontWeight: FontWeight.bold,
               ),
             ),
           ],
         ),
       );
     }).toList(),
   );
 }

 String _getCorrelationStrength(double value) {
   final absValue = value.abs();
   if (absValue > 0.7) return 'Rất mạnh';
   if (absValue > 0.5) return 'Mạnh';
   if (absValue > 0.3) return 'Trung bình';
   if (absValue > 0.1) return 'Yếu';
   return 'Không đáng kể';
 }

 String _getCorrelationExplanation(Map<String, dynamic> item) {
   final name = item['name'];
   final value = item['value'];
   
   if (name == 'Giá sản phẩm & Lượng bán') {
     return 'Khi giá tăng, lượng bán có xu hướng giảm, thể hiện mối quan hệ ngược chiều mạnh.';
   } else if (name == 'Ngày lễ & Doanh số') {
     return 'Các dịp lễ tết làm tăng doanh số bán hàng, thể hiện mối quan hệ thuận chiều rõ rệt.';
   } else if (name == 'Thời tiết & Doanh số') {
     return 'Thời tiết có ảnh hưởng đáng kể đến doanh số, tuy nhiên mức độ tác động phụ thuộc vào loại sản phẩm.';
   } else if (name == 'Ngày trong tuần & Doanh số') {
     return 'Ngày trong tuần có ảnh hưởng nhẹ đến doanh số, cuối tuần thường cao hơn.';
   } else if (name == 'Khuyến mại & Doanh số') {
     return 'Các chương trình khuyến mại có tác động mạnh đến việc tăng doanh số bán hàng.';
   }
   
   return 'Hai yếu tố này có mối quan hệ ${value >= 0 ? "thuận chiều" : "ngược chiều"} ${_getCorrelationStrength(value)}.';
 }

 String _getCategoryAnalysis(String category, Map<String, dynamic> data) {
   final trend = data['trend'];
   final growth = data['avgMonthlyGrowth'] as double?;
   
   if (trend == 'Tăng' && growth != null && growth > 5.0) {
     return 'Danh mục $category đang phát triển mạnh với tốc độ tăng trưởng ${growth.toStringAsFixed(1)}%. Cân nhắc tăng lượng đặt hàng và mở rộng danh mục sản phẩm này.';
   } else if (trend == 'Tăng') {
     return 'Danh mục $category có xu hướng tăng nhẹ. Duy trì chiến lược hiện tại và theo dõi để điều chỉnh kịp thời.';
   } else if (trend == 'Giảm' && growth != null && growth < -5.0) {
     return 'Danh mục $category đang có xu hướng giảm đáng kể. Cân nhắc giảm lượng đặt hàng hoặc tìm cách thúc đẩy tiêu thụ.';
   } else if (trend == 'Giảm') {
     return 'Danh mục $category có dấu hiệu giảm nhẹ. Theo dõi chặt chẽ trong những tháng tới.';
   } else {
     return 'Danh mục $category duy trì ổn định. Tiếp tục chiến lược hiện tại.';
   }
 }

 double _getDoubleValue(dynamic value) {
   if (value == null) return 0.0;
   if (value is int) return value.toDouble();
   if (value is double) return value;
   return double.tryParse(value.toString()) ?? 0.0;
 }
}