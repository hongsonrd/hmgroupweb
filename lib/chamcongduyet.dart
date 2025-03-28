import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:core';
import 'db_helper.dart';
import 'table_models.dart';
import 'dart:math';
import 'http_client.dart';

class ChamCongDuyetScreen extends StatefulWidget {
  final String username;
  final String userRole;
  final String approverUsername;

  const ChamCongDuyetScreen({
    Key? key, 
    required this.username, 
    required this.userRole,
    required this.approverUsername,
  }) : super(key: key);

  @override
  _ChamCongDuyetScreenState createState() => _ChamCongDuyetScreenState();
}

class _ChamCongDuyetScreenState extends State<ChamCongDuyetScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingRecords = [];
  List<Map<String, dynamic>> _filteredRecords = [];
  List<String> _availableUsers = [];
  List<String> _availableMonths = [];
  String? _selectedUser;
  String? _selectedMonth;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPendingRecords();
  }

  Future<void> _loadPendingRecords() async {
  setState(() {
    _isLoading = true;
    _errorMessage = '';
  });

  try {
    final dbHelper = DBHelper();
    List<ChamCongLSModel> allRecords = await dbHelper.getAllChamCongLS();
    
    if (allRecords.isEmpty) {
      print('No records in local DB, fetching from API...');
      
      final url = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongls/${widget.username}');
      final response = await AuthenticatedHttpClient.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        
        allRecords = data.map((item) => ChamCongLSModel.fromMap(item as Map<String, dynamic>)).toList();
        
        await dbHelper.batchInsertChamCongLS(allRecords);
        print('Fetched and saved ${allRecords.length} records from API');
      } else {
        throw Exception('Failed to load data from API: ${response.statusCode}');
      }
    }
    
    print('Current username (for approval filter): ${widget.username}');
    
    if (allRecords.isNotEmpty) {
      for (int i = 0; i < min(5, allRecords.length); i++) {
        print('Record $i:');
        print('  NguoiDuyetBatDau: ${allRecords[i].nguoiDuyetBatDau}');
        print('  NguoiDuyetKetThuc: ${allRecords[i].nguoiDuyetKetThuc}');
        print('  TrangThaiBatDau: ${allRecords[i].trangThaiBatDau}');
        print('  TrangThaiKetThuc: ${allRecords[i].trangThaiKetThuc}');
        print('  PhanLoaiBatDau: ${allRecords[i].phanLoaiBatDau}');
        print('  PhanLoaiKetThuc: ${allRecords[i].phanLoaiKetThuc}');
      }
    }
    
    // Filter records where user is approver AND "Chấm bất thường" classification
    List<Map<String, dynamic>> approvalRecords = allRecords
      .where((record) => 
        // User is approver (case insensitive)
        ((record.nguoiDuyetBatDau?.toLowerCase() == widget.username.toLowerCase()) || 
         (record.nguoiDuyetKetThuc?.toLowerCase() == widget.username.toLowerCase())) &&
        // Record has "Chấm bất thường" classification
        ((record.phanLoaiBatDau == 'Chấm bất thường') || 
         (record.phanLoaiKetThuc == 'Chấm bất thường'))
      )
      .map((record) => record.toMap())
      .toList();
    
    print('Found ${approvalRecords.length} records with "Chấm bất thường" classification');
    
    _pendingRecords = approvalRecords;
    
    _generateAvailableUsers();
    
    _generateAvailableMonths();
    
    _applyFilters();
    
  } catch (e) {
    setState(() {
      _errorMessage = 'Lỗi tải dữ liệu: $e';
      print('Error loading records: $e');
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  void _generateAvailableUsers() {
    final Set<String> uniqueUsers = {};
    
    for (var record in _pendingRecords) {
      final user = record['NguoiDung'] as String?;
      if (user != null && user.isNotEmpty) {
        uniqueUsers.add(user);
      }
    }
    
    _availableUsers = uniqueUsers.toList()..sort();
  }

  void _generateAvailableMonths() {
    final Set<String> uniqueMonths = {};
    
    for (var record in _pendingRecords) {
      final ngay = record['Ngay'] as String?;
      if (ngay != null && ngay.isNotEmpty) {
        try {
          final date = DateFormat('yyyy-MM-dd').parse(ngay);
          final monthYear = DateFormat('MM/yyyy').format(date);
          uniqueMonths.add(monthYear);
        } catch (e) {
          print('Invalid date format for record: $record');
        }
      }
    }
    
    _availableMonths = uniqueMonths.toList();
    _availableMonths.sort((a, b) => b.compareTo(a)); // Most recent first
  }

  void _applyFilters() {
    setState(() {
      _filteredRecords = List.from(_pendingRecords);
      
      // Apply user filter
      if (_selectedUser != null && _selectedUser!.isNotEmpty) {
        _filteredRecords = _filteredRecords.where((record) => 
          record['NguoiDung'] == _selectedUser).toList();
      }
      
      // Apply month filter
      if (_selectedMonth != null && _selectedMonth!.isNotEmpty) {
        final parts = _selectedMonth!.split('/');
        if (parts.length == 2) {
          final month = int.parse(parts[0]);
          final year = int.parse(parts[1]);
          
          _filteredRecords = _filteredRecords.where((record) {
            final ngay = record['Ngay'] as String?;
            if (ngay != null && ngay.isNotEmpty) {
              try {
                final date = DateFormat('yyyy-MM-dd').parse(ngay);
                return date.month == month && date.year == year;
              } catch (e) {
                return false;
              }
            }
            return false;
          }).toList();
        }
      }
      
      // Sort by date, most recent first
      _filteredRecords.sort((a, b) {
        final dateA = a['Ngay'] as String?;
        final dateB = b['Ngay'] as String?;
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });
    });
  }

  Future<void> _updateApprovalStatus(Map<String, dynamic> record, bool isApproved) async {
  setState(() {
    _isLoading = true;
  });

  try {
    final uid = record['UID'] as String;
    final url = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongupdate/$uid');
    
    // Determine which parts need approval
    final isBatDauApprover = record['NguoiDuyetBatDau'] == widget.username;
    final isKetThucApprover = record['NguoiDuyetKetThuc'] == widget.username;
    
    // Create update data
    final updateData = <String, dynamic>{};
    
    // Add basic information
    updateData['UID'] = uid;
    updateData['NguoiDung'] = record['NguoiDung'];
    updateData['Ngay'] = record['Ngay'];
    
    // Update status based on approval
    final newStatus = isApproved ? 'Đồng ý' : 'Từ chối';
    
    if (isBatDauApprover) {
      updateData['TrangThaiBatDau'] = newStatus;
    }
    
    if (isKetThucApprover) {
      updateData['TrangThaiKetThuc'] = newStatus;
    }
    
    // Update công if rejected
    if (!isApproved) {
      // Calculate công reduction
      double tongCongNgay = 0.0;
      if (record['TongCongNgay'] != null) {
        tongCongNgay = double.tryParse(record['TongCongNgay'].toString()) ?? 0.0;
      }
      
      // If both need approval and both rejected, công becomes 0
      if (isBatDauApprover && isKetThucApprover) {
        updateData['TongCongNgay'] = 0.0;
      } 
      // If only one is rejected, công is reduced by 50%
      else if (isBatDauApprover || isKetThucApprover) {
        updateData['TongCongNgay'] = tongCongNgay * 0.5;
      }
    }
    
    // Send the update request
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(updateData),
    );
    
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isApproved ? 'Đã phê duyệt' : 'Đã từ chối'),
          backgroundColor: isApproved ? Colors.green : Colors.red,
        ),
      );
      
      // Update the local database with the new status immediately
      final dbHelper = DBHelper();
      final chamCongLS = await dbHelper.getChamCongLSByUID(uid);
      
      if (chamCongLS != null) {
        final updates = <String, dynamic>{};
        
        if (isBatDauApprover) {
          updates['TrangThaiBatDau'] = newStatus;
        }
        
        if (isKetThucApprover) {
          updates['TrangThaiKetThuc'] = newStatus;
        }
        
        if (!isApproved && record['TongCongNgay'] != null) {
          double tongCongNgay = double.tryParse(record['TongCongNgay'].toString()) ?? 0.0;
          
          if (isBatDauApprover && isKetThucApprover) {
            updates['TongCongNgay'] = 0.0;
          } else if (isBatDauApprover || isKetThucApprover) {
            updates['TongCongNgay'] = tongCongNgay * 0.5;
          }
        }
        
        await dbHelper.updateChamCongLS(uid, updates);
      }
      
      // Completely reload data to refresh the list
      await _loadPendingRecords();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi cập nhật: ${response.statusCode}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Xét duyệt chấm công',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Người chấm công',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  isExpanded: true,
                  value: _selectedUser,
                  hint: Text('Tất cả người dùng'),
                  onChanged: (value) {
                    setState(() {
                      _selectedUser = value;
                      _applyFilters();
                    });
                  },
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('Tất cả người dùng'),
                    ),
                    ..._availableUsers.map((user) => DropdownMenuItem<String>(
                      value: user,
                      child: Text(user),
                    )).toList(),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Tháng',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  isExpanded: true,
                  value: _selectedMonth,
                  hint: Text('Tất cả các tháng'),
                  onChanged: (value) {
                    setState(() {
                      _selectedMonth = value;
                      _applyFilters();
                    });
                  },
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('Tất cả các tháng'),
                    ),
                    ..._availableMonths.map((month) => DropdownMenuItem<String>(
                      value: month,
                      child: Text(month),
                    )).toList(),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Số lượng: ${_filteredRecords.length}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                icon: Icon(Icons.refresh),
                label: Text('Làm mới'),
                onPressed: _loadPendingRecords,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final ngay = record['Ngay'] as String?;
    final nguoiDung = record['NguoiDung'] as String?;
    
    final isBatDauApprover = record['NguoiDuyetBatDau'] == widget.username;
    final isKetThucApprover = record['NguoiDuyetKetThuc'] == widget.username;
    
    final trangThaiBatDau = record['TrangThaiBatDau'] as String?;
    final trangThaiKetThuc = record['TrangThaiKetThuc'] as String?;
    
    final batDau = record['BatDau'] as String?;
    final ketThuc = record['KetThuc'] as String?;
    
    final diemChamBatDau = record['DiemChamBatDau'] as String?;
    final diemChamKetThuc = record['DiemChamKetThuc'] as String?;
    
    final hopLeBatDau = record['HopLeBatDau'] as String?;
    final hopLeKetThuc = record['HopLeKetThuc'] as String?;
    
    final phanLoaiBatDau = record['PhanLoaiBatDau'] as String?;
    final phanLoaiKetThuc = record['PhanLoaiKetThuc'] as String?;
    
    final tongCongNgay = record['TongCongNgay'];
    double congValue = 0.0;
    if (tongCongNgay != null) {
      congValue = double.tryParse(tongCongNgay.toString()) ?? 0.0;
    }
    
    // Format date
    String formattedDate = '';
    if (ngay != null && ngay.isNotEmpty) {
      try {
        final date = DateFormat('yyyy-MM-dd').parse(ngay);
        formattedDate = DateFormat('dd/MM/yyyy').format(date);
      } catch (e) {
        formattedDate = ngay;
      }
    }
    
    // Determine if this record needs approval
    bool needsBatDauApproval = isBatDauApprover && trangThaiBatDau == 'Chưa xem';
    bool needsKetThucApproval = isKetThucApprover && trangThaiKetThuc == 'Chưa xem';
    bool needsAnyApproval = needsBatDauApproval || needsKetThucApproval;
    
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedDate,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                 nguoiDung ?? 'Unknown',
                 style: TextStyle(fontSize: 16),
               ),
             ],
           ),
           Divider(),
           if (isBatDauApprover) ...[
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text('Giờ vào: ${batDau ?? 'N/A'}'),
                     Text('Điểm chấm: ${diemChamBatDau ?? 'N/A'}'),
                     Text('Loại: ${phanLoaiBatDau ?? 'N/A'}'),
                     Text(
                       'Hợp lệ: ${hopLeBatDau ?? 'N/A'}',
                       style: TextStyle(
                         color: hopLeBatDau == 'Hợp lệ' ? Colors.green : Colors.red,
                       ),
                     ),
                   ],
                 ),
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.end,
                   children: [
                     Container(
                       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                       decoration: BoxDecoration(
                         color: _getStatusColor(trangThaiBatDau),
                         borderRadius: BorderRadius.circular(12),
                       ),
                       child: Text(
                         trangThaiBatDau ?? 'N/A',
                         style: TextStyle(color: Colors.white),
                       ),
                     ),
                   ],
                 ),
               ],
             ),
             SizedBox(height: 8),
           ],
           if (isKetThucApprover) ...[
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text('Giờ ra: ${ketThuc ?? 'N/A'}'),
                     Text('Điểm chấm: ${diemChamKetThuc ?? 'N/A'}'),
                     Text('Loại: ${phanLoaiKetThuc ?? 'N/A'}'),
                     Text(
                       'Hợp lệ: ${hopLeKetThuc ?? 'N/A'}',
                       style: TextStyle(
                         color: hopLeKetThuc == 'Hợp lệ' ? Colors.green : Colors.red,
                       ),
                     ),
                   ],
                 ),
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.end,
                   children: [
                     Container(
                       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                       decoration: BoxDecoration(
                         color: _getStatusColor(trangThaiKetThuc),
                         borderRadius: BorderRadius.circular(12),
                       ),
                       child: Text(
                         trangThaiKetThuc ?? 'N/A',
                         style: TextStyle(color: Colors.white),
                       ),
                     ),
                   ],
                 ),
               ],
             ),
           ],
           if (congValue > 0) ...[
             Divider(),
             Text(
               'Công: ${congValue.toStringAsFixed(1)}',
               style: TextStyle(fontWeight: FontWeight.bold),
             ),
           ],
           if (needsAnyApproval) ...[
             Divider(),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
               children: [
                 ElevatedButton.icon(
                   icon: Icon(Icons.check),
                   label: Text('Đồng ý'),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.green,
                     foregroundColor: Colors.white,
                   ),
                   onPressed: () => _updateApprovalStatus(record, true),
                 ),
                 ElevatedButton.icon(
                   icon: Icon(Icons.close),
                   label: Text('Từ chối'),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.red,
                     foregroundColor: Colors.white,
                   ),
                   onPressed: () => _updateApprovalStatus(record, false),
                 ),
               ],
             ),
           ],
         ],
       ),
     ),
   );
 }

 Color _getStatusColor(String? status) {
   if (status == null) return Colors.grey;
   
   switch (status) {
     case 'Đồng ý':
       return Colors.green;
     case 'Từ chối':
       return Colors.red;
     case 'Chưa xem':
       return Colors.orange;
     default:
       return Colors.grey;
   }
 }

 @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(
       title: const Text('Xét duyệt chấm công'),
     ),
     body: Column(
       children: [
         _buildFilterBar(),
         Expanded(
           child: _isLoading
             ? Center(child: CircularProgressIndicator())
             : _errorMessage.isNotEmpty
               ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)))
               : _filteredRecords.isEmpty
                 ? Center(child: Text('Không có dữ liệu cần xét duyệt'))
                 : ListView.builder(
                     itemCount: _filteredRecords.length,
                     itemBuilder: (context, index) => _buildRecordCard(_filteredRecords[index]),
                   ),
         ),
       ],
     ),
   );
 }
}