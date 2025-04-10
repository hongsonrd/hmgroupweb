// coinstat.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:sqflite/sqflite.dart';

class CoinStat extends StatefulWidget {
  final String username;

  const CoinStat({Key? key, required this.username}) : super(key: key);

  @override
  _CoinStatState createState() => _CoinStatState();
}

class _CoinStatState extends State<CoinStat> {
  bool _isLoading = true;
  List<CoinModel> _coinHistory = [];
  List<CoinRateModel> _coinRates = [];
  int _totalCoins = 0;
  int _totalTasks = 0;
  int _currentRate = 0;
  DateTime _lastSyncDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadCoinData();
  }

  Future<void> _loadCoinData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DBHelper();
      
      // Load coins from local database
      final coinData = await dbHelper.getAllCoins();
      final rateData = await dbHelper.getAllCoinRates();
      
      setState(() {
        _coinHistory = coinData.where((coin) => 
          coin.nguoiDung?.toLowerCase() == widget.username.toLowerCase()).toList();
        _coinRates = rateData;
        
        // Calculate total coins and tasks
        _totalCoins = _coinHistory.fold(0, 
          (sum, coin) => sum + (coin.tongTien ?? 0));
        _totalTasks = _coinHistory.fold(0, 
          (sum, coin) => sum + (coin.soLuong ?? 0));
        
        // Find current rate based on total coins
        _currentRate = _findCurrentRate(_totalCoins);
        
        // Get last sync date
        final prefs = SharedPreferences.getInstance();
        prefs.then((prefs) {
          final lastSyncString = prefs.getString('last_coin_sync_date');
          if (lastSyncString != null) {
            try {
              _lastSyncDate = DateTime.parse(lastSyncString);
            } catch (e) {
              print('Error parsing last sync date: $e');
            }
          }
        });
        
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading coin data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  int _findCurrentRate(int totalCoins) {
    // Sort rates by startRate
    final sortedRates = List<CoinRateModel>.from(_coinRates)
      ..sort((a, b) => (a.startRate ?? 0).compareTo(b.startRate ?? 0));
    
    // Find appropriate rate tier
    for (var rate in sortedRates) {
      if ((rate.startRate ?? 0) <= totalCoins && 
          (rate.endRate ?? double.infinity) >= totalCoins) {
        return rate.startRate ?? 0;
      }
    }
    return 0; // Default rate if none found
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HM Xu Thưởng'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromARGB(255, 255, 215, 0),  // Gold
                Color.fromARGB(255, 255, 177, 114),
                Color.fromARGB(255, 255, 149, 79),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () async {
              await syncCoinData(widget.username, forceSync: true);
              _loadCoinData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCoinStatus(),
                    SizedBox(height: 24),
                    _buildRateRanges(),
                    SizedBox(height: 24),
                    _buildCoinHistory(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCoinStatus() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 255, 223, 91),
              Color.fromARGB(255, 255, 177, 114),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              'HM Xu',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            Text(
              _totalCoins.toString(),
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Số nhiệm vụ: $_totalTasks',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tỷ lệ hiện tại: $_currentRate',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Cập nhật: ${DateFormat('dd/MM/yyyy HH:mm').format(_lastSyncDate)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateRanges() {
    // Sort rates by startRate
    final sortedRates = List<CoinRateModel>.from(_coinRates)
      ..sort((a, b) => (a.startRate ?? 0).compareTo(b.startRate ?? 0));
      
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bảng Tỷ Lệ Quy Đổi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: sortedRates.length,
              itemBuilder: (context, index) {
                final rate = sortedRates[index];
                final startRate = rate.startRate ?? 0;
                final endRate = rate.endRate ?? 0;
                
                return Card(
                  color: _totalCoins >= startRate && _totalCoins <= endRate 
                    ? Color.fromARGB(50, 255, 215, 0) 
                    : null,
                  child: ListTile(
                    title: Text(
                      '${startRate} - ${endRate}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    trailing: _totalCoins >= startRate && _totalCoins <= endRate
                      ? Icon(Icons.star, color: Colors.amber)
                      : null,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinHistory() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lịch Sử Xu',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _coinHistory.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Chưa có lịch sử xu'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _coinHistory.length,
                    itemBuilder: (context, index) {
                      final coin = _coinHistory[index];
                      final date = coin.ngay != null 
                        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(coin.ngay!))
                        : '';
                      
                      return ListTile(
                        title: Text('Ngày: $date'),
                        subtitle: Text('Số nhiệm vụ: ${coin.soLuong ?? 0}'),
                        trailing: Text(
                          '${coin.tongTien ?? 0} xu',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.amber[800],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

Future<bool> syncCoinData(String username, {bool forceSync = false}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncDate = prefs.getString('last_coin_sync_date');
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (!forceSync && lastSyncDate == today) {
      print('Coin data already synced today. Skipping sync.');
      return false;
    }

    print('Starting coin data sync for user: $username');
    
    // Get database access
    final dbHelper = DBHelper();
    final db = await dbHelper.database;
    
    // ⚠️ IMPORTANT: Match the exact case of nguoiDung in existing records
    final originalCase = username.toUpperCase(); // Use uppercase to match data format
    print('Using uppercase username for operation: $originalCase');
    
    // Clear data - using the UPPERCASE username to match record format
    print('Clearing existing coin data with uppercase username');
    final coinDeleteCount = await db.delete(
      'Coin',
      where: 'nguoiDung = ?',
      whereArgs: [originalCase],
    );
    print('Deleted $coinDeleteCount coin records');
    
    final rateDeleteCount = await db.delete('CoinRate');
    print('Deleted $rateDeleteCount rate records');
    
    // Fetch data from APIs
    final coinResponse = await http.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/coin/$username'),
    );
    
    // Process coin data
    if (coinResponse.statusCode == 200) {
      final coinData = json.decode(coinResponse.body);
      
      if (coinData is List && coinData.isNotEmpty) {
        print('Received ${coinData.length} coin records from server');
        
        // Insert with specific case
        for (var item in coinData) {
          final map = {
            'uid': item['uid'] ?? '',
            'nguoiDung': originalCase, // Ensure consistent case for all records
            'ngay': item['ngay'] ?? today,
            'soLuong': item['soLuong'] ?? 0,
            'tongTien': item['tongTien'] ?? 0,
          };
          await db.insert('Coin', map);
        }
      }
    }
    
    // Process rate data
    final rateResponse = await http.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/coinrate/$username'),
    );
    
    if (rateResponse.statusCode == 200) {
      final rateData = json.decode(rateResponse.body);
      
      if (rateData is List && rateData.isNotEmpty) {
        print('Received ${rateData.length} rate records from server');
        
        for (var item in rateData) {
          final map = {
            'uid': item['uid'] ?? '',
            'caseType': item['caseType'] ?? '',
            'startRate': item['startRate'] ?? 0,
            'endRate': item['endRate'] ?? 0,
            'maxCount': item['maxCount'] ?? 0,
          };
          await db.insert('CoinRate', map);
        }
      }
    }
    
    // Verify counts after operation
    final afterCoinCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM Coin WHERE nguoiDung = ?', [originalCase])
    ) ?? 0;
    
    final afterRateCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM CoinRate')
    ) ?? 0;
    
    print('Database now has $afterCoinCount coins for user and $afterRateCount rates');
    
    // Update last sync date
    await prefs.setString('last_coin_sync_date', today);
    print('Coin data synced successfully on $today');
    return true;
    
  } catch (e) {
    print('Error syncing coin data: $e');
    return false;
  }
}

Future<void> syncCoinDataInBackground(String username) async {
  await syncCoinData(username);
}
Future<Map<String, dynamic>?> triggerCoinGain(String username, BuildContext context) async {
  print('📢 triggerCoinGain: Starting for user: $username');
  
  try {
    if (username.isEmpty) {
      print('❌ triggerCoinGain: Empty username, aborting');
      return null;
    }
    
    // Find current pay rate
    print('📢 triggerCoinGain: Getting current pay rate');
    String currentPayRate = await getCurrentPayRate(username);
    
    // Ensure we have a valid pay rate
    if (currentPayRate.isEmpty) {
      currentPayRate = 'normal'; // Use a fallback if rate is empty
    }
    print('📢 triggerCoinGain: Current pay rate: $currentPayRate');
    
    // Current date in YYYY-MM-DD format
    final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    print('📢 triggerCoinGain: Current date: $currentDate');
    
    // Prepare request data
    final requestData = {
      'currentdate': currentDate,
      'currentpayrate': currentPayRate
    };
    print('📢 triggerCoinGain: Request data: $requestData');
    
    // Send request to server
    final url = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app/coingain/$username/';
    print('📢 triggerCoinGain: Sending request to: $url');
    
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(requestData),
    );
    
    print('📢 triggerCoinGain: Response status code: ${response.statusCode}');
    print('📢 triggerCoinGain: Response body: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final soLuong = data['soLuong'] ?? 0;
      final tongTien = data['tongTien'] ?? 0;
      
      print('📢 triggerCoinGain: Success! soLuong: $soLuong, tongTien: $tongTien');
      
      // Show popup with coin gain information
      showCoinGainPopup(context, soLuong, tongTien);
      
      return {
        'soLuong': soLuong,
        'tongTien': tongTien
      };
    } else {
      print('❌ triggerCoinGain: Request failed with status: ${response.statusCode}');
      print('❌ triggerCoinGain: Error message: ${response.body}');
      return null;
    }
    
  } catch (e, stackTrace) {
    print('❌ triggerCoinGain: Error: $e');
    print('❌ triggerCoinGain: Stack trace: $stackTrace');
    return null;
  }
}

Future<String> getCurrentPayRate(String username) async {
  print('📢 getCurrentPayRate: Starting for user: $username');
  
  try {
    final dbHelper = DBHelper();
    final coinRates = await dbHelper.getAllCoinRates();
    print('📢 getCurrentPayRate: Found ${coinRates.length} coin rates');
    
    // Get user's total coins
    final coins = await dbHelper.getAllCoins();
    final userCoins = coins.where((coin) => 
      coin.nguoiDung?.toLowerCase() == username.toLowerCase()).toList();
    print('📢 getCurrentPayRate: Found ${userCoins.length} coin records for user');
    
    // Fixed type handling here
    final totalCoins = userCoins.fold<int>(0, (sum, coin) => sum + (coin.tongTien ?? 0));
    print('📢 getCurrentPayRate: Total coins: $totalCoins');
    
    // Sort rates by startRate
    final sortedRates = List<CoinRateModel>.from(coinRates)
      ..sort((a, b) => (a.startRate ?? 0).compareTo(b.startRate ?? 0));
    
    // Log the available rates for debugging
    for (var rate in sortedRates) {
      print('📢 getCurrentPayRate: Rate option - caseType: "${rate.caseType}", startRate: ${rate.startRate}, endRate: ${rate.endRate}');
    }
    
    // Find appropriate rate tier
    for (var rate in sortedRates) {
      if ((rate.startRate ?? 0) <= totalCoins && 
          (rate.endRate ?? 0) >= totalCoins) {
        // Check if caseType is not empty
        if (rate.caseType != null && rate.caseType!.isNotEmpty) {
          print('📢 getCurrentPayRate: Selected case: ${rate.caseType}');
          return rate.caseType!;
        }
      }
    }
    
    // No matching rate with valid caseType, use first rate with valid caseType as fallback
    for (var rate in sortedRates) {
      if (rate.caseType != null && rate.caseType!.isNotEmpty) {
        print('📢 getCurrentPayRate: No matching rate found, using first valid case: ${rate.caseType}');
        return rate.caseType!;
      }
    }
    
    // No valid caseType found at all, use fixed value as last resort
    print('❌ getCurrentPayRate: No valid case found, using "normal" as fallback');
    return 'normal';
  } catch (e, stackTrace) {
    print('❌ getCurrentPayRate: Error: $e');
    print('❌ getCurrentPayRate: Stack trace: $stackTrace');
    return 'normal'; // Default fallback
  }
}

// Function to show coin gain popup
void showCoinGainPopup(BuildContext context, int soLuong, int tongTien) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      // Auto-dismiss after 5 seconds
      Future.delayed(Duration(seconds: 5), () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                  Color(0xFFBFA243),
                    Color.fromARGB(255, 255, 223, 91),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star,
                color: Colors.white,
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                'Chúc mừng!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Hôm nay bạn đã hoàn thành $soLuong công việc',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Và nhận được tổng cộng',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '$tongTien điểm',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        contentPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
      );
    },
  );
}