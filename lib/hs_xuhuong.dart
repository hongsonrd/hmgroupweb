import 'package:flutter/material.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'table_models.dart';
import 'db_helper.dart';

class HSXuHuongScreen extends StatefulWidget {
  const HSXuHuongScreen({Key? key}) : super(key: key);

  @override
  _HSXuHuongScreenState createState() => _HSXuHuongScreenState();
}

class _HSXuHuongScreenState extends State<HSXuHuongScreen> with SingleTickerProviderStateMixin {
  final DBHelper _dbHelper = DBHelper();
  bool _isLoading = false;
  bool _hasData = false;
  bool _hasDeepAnalysis = false;
  List<Map<String, dynamic>> _trendResults = [];
  Map<String, List<Map<String, dynamic>>> _branchResults = {};
  String _selectedBranch = 'Tất cả';
  List<String> _branches = ['Tất cả'];
  
  // Deep analysis data
  Map<String, List<double>> _seasonalData = {};
  Map<String, dynamic> _yoyData = {};
  Map<String, Map<String, dynamic>> _categoryData = {};
  
  // Tab controller for deep analysis
  late TabController _analysisTabController;

  @override
  void initState() {
    super.initState();
    _analysisTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _analysisTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Using the same color scheme as in other screens
    final Color appBarTop = Color(0xFF534b0d);
    final Color appBarBottom = Color(0xFFb2a41f);
    
    return Scaffold(
      appBar: AppBar(
  title: Text(
    'Dự đoán xu hướng hàng',
    style: TextStyle(
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
  ],
),
      body: _isLoading 
          ? _buildLoadingView() 
          : _hasData 
              ? _buildResultsView() 
              : _buildInitialView(),
    );
  }

  // Initial view with welcome message and start button
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
              _showPerformanceWarningDialog();
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
        ],
      ),
    );
  }

  // Loading view with progress indicator
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

  // Results view showing the analysis and forecasts
  Widget _buildResultsView() {
    return Column(
      children: [
        // Branch selector
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
        
        // Results list
        Expanded(
          child: _selectedBranch == 'Tất cả'
              ? _buildOverallResults()
              : _buildBranchResults(_selectedBranch),
        ),
      ],
    );
  }

  // Overall trend results
  Widget _buildOverallResults() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _trendResults.length,
      itemBuilder: (context, index) {
        final item = _trendResults[index];
        
        return Card(
          margin: EdgeInsets.only(bottom: 16),
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
                  ],
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
        );
      },
    );
  }

  // Branch-specific results
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
                  ],
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
        );
      },
    );
  }

  // Helper method to build statistic item
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

  // Show warning dialog about performance
  void _showPerformanceWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cảnh báo hiệu suất'),
        content: Text(
          'Tính năng phân tích xu hướng sẽ sử dụng nhiều tài nguyên máy tính. '
          'Với thiết bị cũ hoặc có cấu hình thấp, quá trình này có thể mất thời gian '
          'và làm chậm thiết bị của bạn.\n\n'
          'Bạn có muốn tiếp tục không?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Huỷ bỏ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performTrendAnalysis();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: Text('Tiếp tục'),
          ),
        ],
      ),
    );
  }

  // Helper method for converting values to double safely
  double _getDoubleValue(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  // Show deep analysis dialog
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
              Expanded(
                child: _buildDeepAnalysisView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Perform trend analysis
  Future<void> _performTrendAnalysis() async {
    setState(() {
      _isLoading = true;
    });

    try {
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

  // Build the deep analysis tabs view
  Widget _buildDeepAnalysisView() {
    if (!_hasDeepAnalysis) {
      return Center(
        child: Text(
          'Không đủ dữ liệu để thực hiện phân tích chuyên sâu.\nCần ít nhất 30 đơn hàng hoàn thành.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      );
    }
    
    return Column(
      children: [
        // Tab selector for different analysis types
        TabBar(
          controller: _analysisTabController,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange,
          tabs: [
            Tab(text: 'Theo mùa'),
            Tab(text: 'So sánh năm'),
            Tab(text: 'Theo danh mục'),
          ],
        ),
        
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _analysisTabController,
            children: [
              _buildSeasonalAnalysisView(),
              _buildYearOverYearView(),
              _buildCategoryAnalysisView(),
            ],
          ),
        ),
      ],
    );
  }

  // Seasonal analysis view
  Widget _buildSeasonalAnalysisView() {
    // Generate month names
    final monthNames = [
      'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 
      'Tháng 5', 'Tháng 6', 'Tháng 7', 'Tháng 8',
      'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'
    ];
    
    // Convert month-indexed map to list for ListView
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
    
    // Sort by month index
    monthlyData.sort((a, b) => a['monthIndex'].compareTo(b['monthIndex']));
    
    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: monthlyData.length + 1, // +1 for the header
      itemBuilder: (context, index) {
        if (index == 0) {
          // Header
          return Container(
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
          );
        }
        
        // Month data
        final item = monthlyData[index - 1];
        
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
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method for getting monthly trend description
  String _getMonthlyTrend(int monthIndex) {
    // In a real implementation, you would calculate this from your data
    // This is a placeholder for demo purposes
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

  // Year-over-year comparison view
  Widget _buildYearOverYearView() {
    if (_yoyData.isEmpty || !_yoyData.containsKey('yoyGrowth')) {
      return Center(
        child: Text('Không đủ dữ liệu để phân tích so sánh năm.'),
      );
    }
    
    final yoyGrowth = _yoyData['yoyGrowth'] as Map<dynamic, dynamic>;
    
    // Convert to list for ListView
    List<Map<String, dynamic>> yearData = [];
    yoyGrowth.forEach((year, monthData) {
      yearData.add({
        'year': year,
        'monthData': monthData,
      });
    });
    
    // Sort by year
    yearData.sort((a, b) => a['year'].toString().compareTo(b['year'].toString()));
    
    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: yearData.length + 1, // +1 for the header
      itemBuilder: (context, index) {
        if (index == 0) {
          // Header
          return Container(
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
          );
        }
        
        // Year data
        final item = yearData[index - 1];
        final monthData = item['monthData'] as Map<dynamic, dynamic>;
        
        return Card(
          margin: EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Năm ${item['year']}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                
                // Monthly growth data
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
                      growthColor = growth > 5.0
                          ? Colors.green
                          : growth < -5.0
                              ? Colors.red
                              : Colors.orange;
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
    );
  }

  // Category analysis view
  Widget _buildCategoryAnalysisView() {
    if (_categoryData.isEmpty) {
      return Center(
        child: Text('Không đủ dữ liệu để phân tích theo danh mục.'),
      );
    }
    
    // Convert to list for ListView
    List<Map<String, dynamic>> categoryItems = [];
    _categoryData.forEach((category, data) {
      categoryItems.add({
        'category': category,
        'data': data,
      });
    });
    
    // Sort by total quantity (descending)
    categoryItems.sort((a, b) {
      final aTotal = a['data']['totalQuantity'] ?? 0.0;
      final bTotal = b['data']['totalQuantity'] ?? 0.0;
      return bTotal.compareTo(aTotal);
    });
    
    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: categoryItems.length + 1, // +1 for the header
      itemBuilder: (context, index) {
        if (index == 0) {
          // Header
          return Container(
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
          );
        }
        
        // Category data
        final item = categoryItems[index - 1];
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
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to generate category analysis text
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

  // Analyze trends for a given set of orders
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
            final value = stock['soLuongHienTai'];
            if (value == null) return sum;
            if (value is int) return sum + value.toDouble();
            if (value is double) return sum + value;
            return sum + (double.tryParse(value.toString()) ?? 0.0);
          });
        } else {
          // Get stock for this branch and product
          final branchStock = stockLevels.firstWhere(
            (s) => s['maHangID'] == productId && s['khoHangID'] == branch,
            orElse: () => {'soLuongHienTai': 0},
          );
          
          final stockValue = branchStock['soLuongHienTai'];
          if (stockValue == null) {
            currentStock = 0.0;
          } else if (stockValue is int) {
            currentStock = stockValue.toDouble();
          } else if (stockValue is double) {
            currentStock = stockValue;
          } else {
            currentStock = double.tryParse(stockValue.toString()) ?? 0.0;
          }
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
          final quantity = order['soLuongYeuCau'];
          if (quantity != null) {
            double doubleQuantity;
            if (quantity is int) {
              doubleQuantity = quantity.toDouble();
            } else if (quantity is double) {
              doubleQuantity = quantity;
            } else {
              doubleQuantity = double.tryParse(quantity.toString()) ?? 0.0;
            }
            quantities.add(doubleQuantity);
          } else {
            quantities.add(0.0);
          }
        }
        
        // Simple moving average forecast
        double avgQuantity = quantities.isNotEmpty 
            ? quantities.reduce((a, b) => a + b) / quantities.length 
            : 0.0;
        
        // Linear regression for forecasting (simple implementation)
        double forecastQuantity = _linearRegressionForecast(quantities);
        
        // Generate recommendation
        String recommendation = _generateRecommendation(
          avgQuantity, 
          forecastQuantity, 
          currentStock,
          productInfo['TenSanPham'] ?? 'sản phẩm này',
        );
        
        // Add to results
        results.add({
          'product_id': productId,
          'product_name': productInfo['TenSanPham'] ?? 'Sản phẩm không xác định',
          'category': productInfo['PhanLoai1'] ?? 'Không phân loại',
          'brand': productInfo['ThuongHieu'] ?? 'Không xác định',
          'avg_quantity': avgQuantity,
          'forecast_quantity': forecastQuantity,
          'current_stock': currentStock,
          'trend': forecastQuantity > avgQuantity ? 'Tăng' : 'Giảm',
          'recommendation': recommendation,
        });
      } catch (e) {
        print('Error analyzing product $productId: $e');
        // Continue with next product
      }
    });
    
    // Sort results by forecast quantity (descending)
    results.sort((a, b) => (b['forecast_quantity'] ?? 0).compareTo(a['forecast_quantity'] ?? 0));
    
    // Return top products
    return results.take(10).toList();
  }

  // Simple linear regression forecast
  double _linearRegressionForecast(List<double> data) {
    // If no data or only one point, return average or that point
    if (data.isEmpty) return 0.0;
    if (data.length == 1) return data[0];
    
    // Calculate linear regression
    int n = data.length;
    List<double> x = List.generate(n, (i) => i.toDouble());
    
    double sumX = 0.0;
    double sumY = 0.0;
    double sumXY = 0.0;
    double sumX2 = 0.0;
    
    for (int i = 0; i < n; i++) {
      sumX += x[i];
      sumY += data[i];
      sumXY += x[i] * data[i];
      sumX2 += x[i] * x[i];
    }
    
    double xMean = sumX / n;
    double yMean = sumY / n;
    
    // Calculate slope and intercept
    double numerator = sumXY - (sumX * sumY / n);
    double denominator = sumX2 - (sumX * sumX / n);
    
    // Avoid division by zero
    if (denominator == 0) return yMean;
    
    double slope = numerator / denominator;
    double intercept = yMean - (slope * xMean);
    
    // Predict next value
    double nextX = n.toDouble();
    double forecast = intercept + (slope * nextX);
    
    // Ensure forecast is not negative
    return max(0.0, forecast);
  }

  // Analyze seasonal trends
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

  // Analyze year-over-year growth
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

  // Analyze trends by product category
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
      
      results[category] = {
        'totalSales': categoryOrders.length,
        'totalQuantity': totalQuantity,
        'monthlySales': monthlySales,
        'avgMonthlyGrowth': avgMonthlyGrowth,
        'trend': avgMonthlyGrowth > 1.0 ? 'Tăng' : 
                 avgMonthlyGrowth < -1.0 ? 'Giảm' : 'Ổn định',
      };
    });
    
    return results;
  }
  
  // Generate recommendation based on analysis
  String _generateRecommendation(
    double avgQuantity,
    double forecastQuantity,
    double currentStock,
    String productName,
  ) {
    // Calculate days of inventory based on average demand
    double daysOfStock = avgQuantity > 0 ? currentStock / avgQuantity : 0;
    
    if (forecastQuantity > avgQuantity * 1.2) {
      // Increasing trend
      if (currentStock < forecastQuantity * 2) {
        return 'Nhu cầu về $productName dự kiến sẽ tăng mạnh. Khuyến nghị tăng lượng đặt hàng thêm ${(forecastQuantity - avgQuantity).toStringAsFixed(1)} đơn vị để đáp ứng nhu cầu.';
      } else {
        return 'Mặc dù nhu cầu $productName có xu hướng tăng, tồn kho hiện tại vẫn đủ đáp ứng nhu cầu trong khoảng ${daysOfStock.toStringAsFixed(0)} ngày tới.';
      }
    } else if (forecastQuantity < avgQuantity * 0.8) {
      // Decreasing trend
      if (currentStock > forecastQuantity * 3) {
        return 'Nhu cầu về $productName đang giảm và tồn kho hiện tại cao. Khuyến nghị giảm đặt hàng để tránh hàng tồn kho quá mức.';
      } else {
        return 'Nhu cầu về $productName đang có xu hướng giảm nhẹ. Tồn kho hiện tại phù hợp với nhu cầu dự kiến.';
      }
    } else {
      // Stable trend
      if (currentStock < forecastQuantity) {
        return 'Nhu cầu về $productName ổn định. Tồn kho hiện tại thấp, khuyến nghị bổ sung thêm ${(forecastQuantity - currentStock).toStringAsFixed(1)} đơn vị.';
      } else if (currentStock > forecastQuantity * 4) {
        return 'Nhu cầu về $productName ổn định nhưng tồn kho hiện tại cao. Cân nhắc giảm lượng đặt hàng trong đợt tới.';
      } else {
        return 'Nhu cầu về $productName ổn định và tồn kho hiện tại phù hợp với nhu cầu dự kiến.';
      }
    }
  }
}