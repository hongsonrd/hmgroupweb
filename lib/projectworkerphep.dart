import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'db_helper.dart';
import 'table_models.dart';

class ProjectWorkerPhep extends StatefulWidget {
  final String username;
  final String selectedMonth; // Format: YYYY-MM
  
  const ProjectWorkerPhep({
    Key? key,
    required this.username,
    required this.selectedMonth,
  }) : super(key: key);
  
  @override
  _ProjectWorkerPhepState createState() => _ProjectWorkerPhepState();
}

class _ProjectWorkerPhepState extends State<ProjectWorkerPhep> {
  bool _isLoading = true;
  bool _isProcessing = false;
  String _statusMessage = "Đang kiểm tra quyền hạn...";
  List<Map<String, dynamic>> _processingLogs = [];
  final ScrollController _scrollController = ScrollController();
  bool _isAllowed = false;
  
  // For sending data to server
  Map<String, Map<String, dynamic>> _modifiedRecords = {};
  Map<String, Map<String, dynamic>> _newRecords = {};
  
  // Secret code for testing
  final TextEditingController _secretCodeController = TextEditingController();
  final String _secretCode = "auto2025";
  bool _secretCodeEntered = false;
  
  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }
  
  Future<void> _checkPermissions() async {
    setState(() {
      _statusMessage = "Đang kiểm tra quyền hạn...";
      _isLoading = true;
    });
    
    try {
      // Check date constraints (only between 28th of current month and 2nd of next month)
      final now = DateTime.now();
      final currentMonth = DateFormat('yyyy-MM').format(now);
      final day = now.day;
      final userRequestedMonth = widget.selectedMonth;
      
      final bool isDateInRange = (day >= 28 || day <= 2);
      final bool isCorrectMonth = (userRequestedMonth == currentMonth) || 
        (day <= 2 && userRequestedMonth == DateFormat('yyyy-MM').format(DateTime(now.year, now.month - 1, 1)));
      
      if (!isDateInRange && !_secretCodeEntered) {
        setState(() {
          _statusMessage = "Quá trình tạo phép tự động chỉ có thể thực hiện từ ngày 28 đến ngày 2 tháng tiếp theo. Vui lòng liên hệ Admin.";
          _isLoading = false;
          _isAllowed = false;
        });
        return;
      }
      
      if (!isCorrectMonth && !_secretCodeEntered) {
        setState(() {
          _statusMessage = "Bạn chỉ có thể tạo phép tự động cho tháng hiện tại hoặc tháng vừa qua (nếu đang trong 2 ngày đầu tháng mới). Vui lòng liên hệ Admin.";
          _isLoading = false;
          _isAllowed = false;
        });
        return;
      }
      
      // All checks passed
      setState(() {
        _statusMessage = "Kiểm tra hoàn tất. Bạn có thể bắt đầu xử lý tạo phép tự động.";
        _isLoading = false;
        _isAllowed = true;
      });
      
    } catch (e) {
      setState(() {
        _statusMessage = "Lỗi kiểm tra: $e";
        _isLoading = false;
        _isAllowed = false;
      });
    }
  }

  void _checkSecretCode() {
    if (_secretCodeController.text == _secretCode) {
      setState(() {
        _secretCodeEntered = true;
        _isAllowed = true;
        _statusMessage = "Mã bí mật hợp lệ. Bạn có thể bắt đầu xử lý tạo phép tự động.";
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mã bí mật không hợp lệ.'), backgroundColor: Colors.red)
      );
    }
  }
  
  void _addLog(String message, [String type = 'info']) {
    setState(() {
      _processingLogs.add({
        'time': DateTime.now(),
        'message': message,
        'type': type,
      });
    });
    
    // Auto scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  Future<void> _startAutomaticLeaveProcess() async {
    if (!_isAllowed) return;
    
    setState(() {
      _isProcessing = true;
      _addLog("Bắt đầu quá trình tạo phép tự động cho tháng ${widget.selectedMonth}", "info");
    });
    
    try {
      final dbHelper = DBHelper();
      
      // Get staff with valid MaNV starting with HM and without HoTro values
      _addLog("Đang lấy danh sách nhân viên hợp lệ...");
      final staffResults = await dbHelper.rawQuery(
        '''
        SELECT DISTINCT c.MaNV, c.BoPhan
        FROM chamcongcn c
        WHERE c.MaNV LIKE 'HM%'
        AND c.MaNV IN (
          SELECT MaNV FROM staffbio
        )
        AND c.MaNV NOT IN (
          SELECT MaNV FROM chamcongcn
          WHERE HoTro > 0
          AND strftime('%Y-%m', Ngay) = ?
        )
        AND strftime('%Y-%m', c.Ngay) = ?
        ORDER BY c.BoPhan, c.MaNV
        ''',
        [widget.selectedMonth, widget.selectedMonth]
      );
      
      final List<Map<String, dynamic>> eligibleStaff = [];
      
      _addLog("Tìm thấy ${staffResults.length} nhân viên có mã HM để kiểm tra...");
      
      // Check each staff against the criteria
      for (var staff in staffResults) {
        final maNV = staff['MaNV'] as String;
        final boPhan = staff['BoPhan'] as String;
        
        // 1. Check if they have been with the company for more than 12 months
        final staffBioResult = await dbHelper.rawQuery(
          'SELECT So_thang FROM staffbio WHERE MaNV = ? LIMIT 1',
          [maNV]
        );
        
        if (staffBioResult.isEmpty) {
          _addLog("✕ $maNV: Không tìm thấy trong hồ sơ nhân viên");
          continue;
        }
        
        final soThang = int.tryParse(staffBioResult.first['So_thang']?.toString() ?? '0') ?? 0;
        
        if (soThang <= 12) {
          _addLog("✕ $maNV: Chưa đủ 12 tháng làm việc ($soThang tháng)");
          continue;
        }
        
        // 2. Check if they already used their automatic leave for the month
        // Parse the selected month to get year and month
        final parts = widget.selectedMonth.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        
        // Get all days with 'P' or 'P/2' in CongThuongChu for this month
        final leaveUsedResult = await dbHelper.rawQuery(
  '''
  SELECT Ngay, CongThuongChu, PhanLoai
  FROM chamcongcn
  WHERE MaNV = ? AND BoPhan = ? 
  AND strftime('%Y-%m', Ngay) = ?
  AND (
    CongThuongChu = 'P' 
    OR CongThuongChu = 'P/2'
    OR CongThuongChu LIKE '%+P%'
    OR CongThuongChu LIKE '%+P/2%'
  )
  ''',
  [maNV, boPhan, widget.selectedMonth]
);
        
        // Calculate total leave already used
        double totalLeaveUsed = 0;
        
        for (var leave in leaveUsedResult) {
  final congThuongChu = leave['CongThuongChu'] as String;
  
  // Check for manual leave
  if (congThuongChu == 'P') {
    totalLeaveUsed += 1;
  } else if (congThuongChu == 'P/2') {
    totalLeaveUsed += 0.5;
  }
  // Check for automated leave (with + suffix)
  else if (congThuongChu.contains('+P')) {
    totalLeaveUsed += 1;
  } else if (congThuongChu.contains('+P/2')) {
    totalLeaveUsed += 0.5;
  }
}

if (totalLeaveUsed >= 1) {
  _addLog("✕ $maNV: Đã sử dụng hết phép tháng này ($totalLeaveUsed ngày)");
  continue;
}
        
        // This staff is eligible
        final remainingLeave = 1 - totalLeaveUsed;
        eligibleStaff.add({
          'MaNV': maNV,
          'BoPhan': boPhan,
          'RemainingLeave': remainingLeave
        });
      }
      
      _addLog("Tìm thấy ${eligibleStaff.length} nhân viên hợp lệ để tạo phép tự động");
      
      // Now process each eligible staff
      int successCount = 0;
      
      for (var staff in eligibleStaff) {
        final maNV = staff['MaNV'] as String;
        final boPhan = staff['BoPhan'] as String;
        final remainingLeave = staff['RemainingLeave'] as double;
        
        // Get staff name if available
        String staffName = "";
        final nameResult = await dbHelper.rawQuery(
          'SELECT Ho_ten FROM staffbio WHERE MaNV = ? LIMIT 1',
          [maNV]
        );
        
        if (nameResult.isNotEmpty) {
          staffName = nameResult.first['Ho_ten'] as String? ?? "";
        }
        
        // Determine day 28 of the selected month
        final parts = widget.selectedMonth.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day28 = DateTime(year, month, 28);
        final day28Str = DateFormat('yyyy-MM-dd').format(day28);
        
        // Check if there's already a record for day 28
        final existingDay28Record = await dbHelper.rawQuery(
          '''
          SELECT * FROM chamcongcn
          WHERE MaNV = ? AND BoPhan = ? AND date(Ngay) = date(?)
          ''',
          [maNV, boPhan, day28Str]
        );
        
        try {
          if (existingDay28Record.isEmpty) {
            // Need to create a new record for day 28
            // First, find the project details (MaBP) from another record
            final projectDetailsResult = await dbHelper.rawQuery(
              '''
              SELECT MaBP FROM chamcongcn
              WHERE MaNV = ? AND BoPhan = ? AND strftime('%Y-%m', Ngay) = ?
              ORDER BY Ngay DESC
              LIMIT 1
              ''',
              [maNV, boPhan, widget.selectedMonth]
            );
            
            String maBP = boPhan;
            if (projectDetailsResult.isNotEmpty) {
              maBP = projectDetailsResult.first['MaBP'] as String? ?? boPhan;
            }
            
            // Create new record
            final now = DateTime.now();
            final timeStr = DateFormat('HH:mm:ss').format(now);
            final uuid = Uuid().v4();
            
            // Determine leave value to add
            String congThuongChuValue = remainingLeave >= 1 ? "+P" : "+P/2";
double phanLoaiValue = remainingLeave >= 1 ? 1.0 : 0.5;
String phanLoaiString = phanLoaiValue.toString(); 
if (phanLoaiString.endsWith('.0')) {
  phanLoaiString = phanLoaiValue.toInt().toString(); 
}
            
            final newRecord = {
              'UID': uuid,
              'Ngay': day28Str,
              'Gio': timeStr,
              'NguoiDung': widget.username,
              'BoPhan': boPhan,
              'MaBP': maBP,
              'MaNV': maNV,
              'CongThuongChu': congThuongChuValue,
              'PhanLoai': phanLoaiValue,
              'NgoaiGioThuong': '0',
              'NgoaiGioKhac': '0',
              'NgoaiGiox15': '0',
              'NgoaiGiox2': '0',
              'HoTro': '0',
              'PartTime': '0',
              'PartTimeSang': '0',
              'PartTimeChieu': '0',
              'CongLe': '0',
            };
            
            // Add to new records to be sent to server
            _newRecords[uuid] = newRecord;
            
            _addLog("✓ $maNV${staffName.isNotEmpty ? ' - $staffName' : ''}: Tạo mới bản ghi ngày 28 với $congThuongChuValue");
            successCount++;
            
          } else {
            // Update existing record for day 28
            final record = existingDay28Record.first;
            final uid = record['UID'] as String;
            final currentCongThuongChu = record['CongThuongChu'] as String? ?? '';
            final currentPhanLoai = record['PhanLoai'] as String? ?? '0';
            
            // Check if already has auto leave (+ suffix)
            if (currentCongThuongChu.contains('+P') || currentCongThuongChu.contains('+P/2')) {
              _addLog("✕ $maNV${staffName.isNotEmpty ? ' - $staffName' : ''}: Đã có phép tự động ở ngày 28 ($currentCongThuongChu)");
              continue;
            }
            
            // Determine leave value to add
            String newCongThuongChu = '$currentCongThuongChu${remainingLeave >= 1 ? "+P" : "+P/2"}';
            
            // Calculate new PhanLoai value
            double currentPhanLoaiValue = double.tryParse(currentPhanLoai) ?? 0;
double addedValue = remainingLeave >= 1 ? 1 : 0.5;
double newPhanLoaiValue = currentPhanLoaiValue + addedValue;
            String newPhanLoai = newPhanLoaiValue.toStringAsFixed(1);
// Remove trailing zero if it's a whole number (1.0 -> 1)
if (newPhanLoai.endsWith('.0')) {
  newPhanLoai = newPhanLoaiValue.toString();
}
            // Create update record
            final updateRecord = Map<String, dynamic>.from(record as Map);
            updateRecord['CongThuongChu'] = newCongThuongChu;
            updateRecord['PhanLoai'] = newPhanLoai;
            updateRecord['NguoiDung'] = widget.username;
            
            // Add to modified records to be sent to server
            _modifiedRecords[uid] = updateRecord;
            
            _addLog("✓ $maNV${staffName.isNotEmpty ? ' - $staffName' : ''}: Cập nhật bản ghi ngày 28 thành $newCongThuongChu");
            successCount++;
          }
        } catch (e) {
          _addLog("✕ $maNV${staffName.isNotEmpty ? ' - $staffName' : ''}: Lỗi khi xử lý: $e", "error");
        }
      }
      
      // Save all changes to database and server
      if (_modifiedRecords.isNotEmpty || _newRecords.isNotEmpty) {
        _addLog("Đang lưu ${_modifiedRecords.length} bản ghi đã sửa và ${_newRecords.length} bản ghi mới...");
        await _saveChanges();
      }
      
      _addLog("===== KẾT QUẢ XỬ LÝ =====", "success");
      _addLog("Tổng số nhân viên hợp lệ: ${eligibleStaff.length}", "success");
      _addLog("Tổng số phép tự động đã tạo: $successCount", "success");
      _addLog("Hoàn thành quá trình tạo phép tự động!", "success");
      
      setState(() {
  _isProcessing = false;
});      
    } catch (e) {
      _addLog("Lỗi xử lý: $e", "error");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  Future<void> _saveChanges() async {
    try {
      final dbHelper = DBHelper();
      
      // First process existing modified records
      for (var entry in _modifiedRecords.entries) {
        final record = entry.value;
        final uid = record['UID'] as String;
        
        final updates = Map<String, dynamic>.from(record);
        updates.remove('UID');
        
        _addLog('Đang gửi bản ghi đã sửa đến máy chủ: $uid');
        
        final response = await http.put(
          Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongsua/$uid'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(updates)
        ).timeout(const Duration(seconds: 30));
        
        if (response.statusCode != 200) {
          throw Exception('Lỗi khi cập nhật bản ghi: ${response.body}');
        }

        await dbHelper.updateChamCongCN(uid, updates);
        _addLog('Đã cập nhật cơ sở dữ liệu cho UID: $uid');
      }
      
      // Then process new records
      for (var entry in _newRecords.entries) {
        final uid = entry.key;
        final record = entry.value;
        
        _addLog('Đang gửi bản ghi mới đến máy chủ: $uid');
        
        final response = await http.post(
          Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamconggui'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(record)
        ).timeout(const Duration(seconds: 30));
        
        if (response.statusCode != 200) {
          throw Exception('Lỗi khi thêm bản ghi mới: ${response.body}');
        }
        
        // Convert to model and save to local DB
        final chamCongModel = ChamCongCNModel(
          uid: record['UID'] as String,
          maNV: record['MaNV'] as String,
          ngay: DateTime.parse(record['Ngay'] as String),
          boPhan: record['BoPhan'] as String,
          nguoiDung: record['NguoiDung'] as String,
          congThuongChu: record['CongThuongChu'] as String,
          ngoaiGioThuong: double.tryParse(record['NgoaiGioThuong'].toString()) ?? 0,
          ngoaiGioKhac: double.tryParse(record['NgoaiGioKhac'].toString()) ?? 0,
          ngoaiGiox15: double.tryParse(record['NgoaiGiox15'].toString()) ?? 0,
          ngoaiGiox2: double.tryParse(record['NgoaiGiox2'].toString()) ?? 0,
          hoTro: int.tryParse(record['HoTro'].toString()) ?? 0,
          partTime: int.tryParse(record['PartTime'].toString()) ?? 0,
          partTimeSang: int.tryParse(record['PartTimeSang'].toString()) ?? 0,
          partTimeChieu: int.tryParse(record['PartTimeChieu'].toString()) ?? 0,
          congLe: double.tryParse(record['CongLe'].toString()) ?? 0,
        );
        await dbHelper.insertChamCongCN(chamCongModel);
        _addLog('Đã cập nhật cơ sở dữ liệu cho bản ghi mới: $uid');
      }

      // Add a small delay before refreshing data
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _modifiedRecords.clear();
        _newRecords.clear();
      });

    } catch (e) {
      _addLog('Lỗi khi lưu thay đổi: $e', 'error');
      throw e;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: Text('Tạo phép tự động'),
        automaticallyImplyLeading: !_isProcessing,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: _isAllowed ? Colors.green.shade50 : Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trạng thái:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(_statusMessage),
                        if (!_isAllowed && !_isLoading)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _secretCodeController,
                                    decoration: InputDecoration(
                                      labelText: 'Mã bí mật (cho Admin)',
                                      border: OutlineInputBorder(),
                                    ),
                                    obscureText: true,
                                  ),
                                ),
                                SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _checkSecretCode,
                                  child: Text('Xác nhận'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Thông tin về quá trình:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• Quá trình này hoàn toàn tự động, không cần chọn nhân viên'),
                        SizedBox(height: 4),
                        Text('• Chỉ có thể thực hiện từ ngày 28 đến ngày 2 tháng tiếp theo'),
                        SizedBox(height: 4),
                        Text('• Sẽ tạo phép cho tất cả nhân viên ở tất cả bộ phận'),
                        SizedBox(height: 4),
                        Text('• Hãy đảm bảo bạn đã chấm công đầy đủ cho tất cả bộ phận'),
                        SizedBox(height: 4),
                        Text('• Mỗi nhân viên sẽ được thêm 1 ngày phép tự động mỗi tháng'),
                        SizedBox(height: 4),
                        Text('• Chỉ áp dụng cho nhân viên có mã HM và đã làm trên 12 tháng'),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                if (_isAllowed && !_isProcessing)
                  ElevatedButton(
                    onPressed: _startAutomaticLeaveProcess,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text(
                      'Bắt đầu tạo phép tự động',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                SizedBox(height: 16),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Nhật ký quá trình:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Divider(),
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: _processingLogs.length,
                              itemBuilder: (context, index) {
                                final log = _processingLogs[index];
                                final time = DateFormat('HH:mm:ss').format(log['time'] as DateTime);
                                final type = log['type'] as String;
                                
                                Color textColor;
                                switch (type) {
                                  case 'error':
                                    textColor = Colors.red;
                                    break;
                                  case 'success':
                                    textColor = Colors.green;
                                    break;
                                  case 'warning':
                                    textColor = Colors.orange;
                                    break;
                                  default:
                                    textColor = Colors.black;
                                }
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        time,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          log['message'] as String,
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: type == 'success' || type == 'error' ? 
                                                        FontWeight.bold : FontWeight.normal,
                                          ),
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
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}