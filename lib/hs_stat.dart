import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'hs_xuhuong.dart';

class HSStatScreen extends StatefulWidget {
  const HSStatScreen({Key? key}) : super(key: key);

  @override
  _HSStatScreenState createState() => _HSStatScreenState();
}

class _HSStatScreenState extends State<HSStatScreen> {
  String _username = '';
  bool _isLoading = false;
  String _selectedPeriod = 'Hôm nay';
  final List<String> _periods = ['Hôm nay', 'Tuần này', 'Tháng này', 'Quý này'];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? '';
      
      setState(() {
        _username = username;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user info: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    
    // Simulate data loading
    await Future.delayed(Duration(seconds: 2));
    
    setState(() {
      _isLoading = false;
    });
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã cập nhật dữ liệu thành công'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Colors with hex values (matching your existing color scheme)
    final Color appBarTop = Color(0xFF534b0d);
    final Color appBarBottom = Color(0xFFb2a41f);
    final Color buttonColor = Color(0xFF837826);
    final Color cardBgColor = Color(0xFFFAFAFA);
    
    final now = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy').format(now);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Chỉ số hoạt động', style: TextStyle(fontSize: 18)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [appBarTop, appBarBottom],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period selector
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kỳ báo cáo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _selectedPeriod,
                                  items: _periods.map((String period) {
                                    return DropdownMenuItem<String>(
                                      value: period,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                        child: Text(period),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedPeriod = newValue;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Ngày hiện tại: $formattedDate',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Main action buttons
                    Text(
                      'Báo cáo chỉ số',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Button 1
                    _buildActionButton(
                      icon: Icons.pie_chart,
                      title: 'Doanh số theo nhân viên',
                      subtitle: 'Xem báo cáo doanh số của từng nhân viên kinh doanh',
                      onTap: () {
                        _showComingSoonDialog('Doanh số theo nhân viên');
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Button 2
                    _buildActionButton(
                      icon: Icons.trending_up,
                      title: 'Doanh số theo nhóm hàng',
                      subtitle: 'Phân tích doanh số theo từng nhóm mặt hàng',
                      onTap: () {
                        _showComingSoonDialog('Doanh số theo nhóm hàng');
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Button 3
                    _buildActionButton(
  icon: Icons.timeline,  
  title: 'Dự đoán xu hướng hàng',  
  subtitle: 'Phân tích và dự báo xu hướng tiêu thụ hàng hóa', 
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HSXuHuongScreen()),
    );
  },
  textColor: Colors.orange, 
),
                    SizedBox(height: 24),
                    
                    // Summary card
                    Card(
                      elevation: 2,
                      color: cardBgColor,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tổng quan',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            _buildSummaryItem(
                              title: 'Tổng đơn hàng',
                              value: '0',
                              icon: Icons.receipt,
                              color: Colors.blue,
                            ),
                            Divider(),
                            _buildSummaryItem(
                              title: 'Doanh số',
                              value: '0 đ',
                              icon: Icons.monetization_on,
                              color: Colors.green,
                            ),
                            Divider(),
                            _buildSummaryItem(
                              title: 'Số nhóm hàng',
                              value: '0',
                              icon: Icons.category,
                              color: Colors.orange,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showComingSoonDialog('Tạo báo cáo tùy chỉnh');
        },
        backgroundColor: buttonColor,
        child: Icon(Icons.add),
      ),
    );
  }

  // Helper method to build action buttons
  Widget _buildActionButton({
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
  Color? textColor,  // Added optional textColor parameter
}) {
  return Material(
    color: Colors.white,
    elevation: 2,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (textColor ?? Color(0xFF837826)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: textColor ?? Color(0xFF837826),
                size: 28,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,  // Apply textColor if provided
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    ),
  );
}

  // Helper method to build summary items
  Widget _buildSummaryItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Show coming soon dialog
  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tính năng đang phát triển'),
        content: Text('Tính năng "$feature" đang được phát triển và sẽ sớm được ra mắt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Đóng'),
          ),
        ],
      ),
    );
  }
}