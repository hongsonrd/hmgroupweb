// project_management.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'user_state.dart';
import 'user_credentials.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'db_helper.dart';
import 'projectupdatescreen.dart';
import 'http_client.dart';

import 'table_models.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'dart:typed_data' show Uint8List;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

class ProjectManagement extends StatefulWidget {
  @override
  _ProjectManagementState createState() => _ProjectManagementState();
}

class _ProjectManagementState extends State<ProjectManagement> {
  String? _selectedProject;
  List<String> _projectList = [];
  final UserState _userState = UserState();
  bool _isLoading = false;
  DateTime? _lastSyncTime;
  List<Map<String, dynamic>> _staffList = [];
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _checkAndLoadProjects().then((_) {
    if (_selectedProject != null) {
      _loadStaffForProject(_selectedProject!);
    }
  });
  }
Future<void> _loadStaffForProject(String project) async {
  try {
    final dbHelper = DBHelper();
    
    // Get staff list for the selected project/department
    final staffList = await dbHelper.getStaffListByDepartment(project);
    
    // Get all staffbio entries and create a map for quick lookup
    final staffbioList = await dbHelper.getAllStaffbio();
    final Map<String, Map<String, dynamic>> staffbioMap = {};
    for (var staff in staffbioList) {
      if (staff['MaNV'] != null) {
        staffbioMap[staff['MaNV'].toString()] = staff;
      }
    }
    
    // Add staffbio and vtHistory data to staff list entries
    final enrichedStaffList = await Future.wait(staffList.map((staff) async {
      final maNV = staff['MaNV']?.toString() ?? '';
      final staffbio = staffbioMap[maNV];
      
      // Get latest VTHistory for this staff member
      final vtHistories = await dbHelper.query(
        DatabaseTables.vtHistoryTable,
        where: 'NhanVien = ? AND BoPhan = ?',
        whereArgs: [maNV, project],
      );

      return {
        ...staff,
        'Ho_ten': staffbio?['Ho_ten'] ?? '❓❓❓',
        'vt_status': vtHistories.isNotEmpty ? vtHistories.first : null,
      };
    }));
    
    setState(() {
      _staffList = enrichedStaffList;
    });
  } catch (e) {
    print('Error loading staff for project: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể tải danh sách nhân viên'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  Future<void> _checkAndLoadProjects() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final lastSyncTimeStr = prefs.getString('lastProjectSync');
    
    if (lastSyncTimeStr != null) {
      _lastSyncTime = DateTime.parse(lastSyncTimeStr);
      final daysSinceLastSync = DateTime.now().difference(_lastSyncTime!).inDays;
      
      if (daysSinceLastSync >= 7) {
        await _loadProjects();
      } else {
        // Load existing data without sync
        await _loadProjectsFromPrefs();
      }
    } else {
      // First time sync
      await _loadProjects();
    }
  }

  Future<void> _loadProjectsFromPrefs() async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String response4 = prefs.getString('update_response4') ?? '';
    
    if (response4.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không có dữ liệu dự án. Vui lòng đồng bộ.')),
        );
      }
      return;
    }
    _processProjectData(response4);
  } catch (e) {
    print('Error loading projects from prefs: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải dự án từ bộ nhớ')),
      );
    }
  }
}

void _processProjectData(String response4) {
  try {
    if (response4.isEmpty) {
      print('Empty project data received');
      return;
    }
    
    // Parse JSON array string to List<dynamic>
    List<dynamic> jsonData = json.decode(response4);
    
    // Convert each item to String and remove duplicates
    List<String> projectNames = jsonData
        .map((item) => item.toString())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    
    // Sort the list
    projectNames.sort();
    
    setState(() {
      _projectList = projectNames;
      if (_selectedProject == null && _projectList.isNotEmpty) {
        _selectedProject = _projectList[0];
      }
    });
  } catch (e) {
    print('Error processing project data: $e');
  }
}
Future<int> _getTodayReportCount() async {
  if (_selectedProject == null) return 0;
  try {
    final dbHelper = DBHelper();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();
    final reports = await dbHelper.query(
      DatabaseTables.taskHistoryTable,
      where: 'BoPhan = ? AND DATE(Ngay) = DATE(?)',
      whereArgs: [_selectedProject, today],
    );
    return reports.length;
  } catch (e) {
    print('Error getting today\'s report count: $e');
    return 0;
  }
}
Future<int> _getActiveStaffCount() async {
  if (_staffList.isEmpty) return 0;
  
  int activeCount = 0;
  for (var staff in _staffList) {
    final vtStatus = staff['vt_status'] as Map<String, dynamic>?;
    if (vtStatus == null || vtStatus['TrangThai'] == 'Đang làm việc') {
      activeCount++;
    }
  }
  return activeCount;
}
Future<void> _loadProjects() async {
  if (_isLoading) return;
  setState(() {
    _isLoading = true;
  });
  
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final userCredentials = Provider.of<UserCredentials>(context, listen: false);
    String username = userCredentials.username.toLowerCase();
    
    // Show progress dialog
    void showProgress(String step, int stepNumber) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return SyncProgressDialog(
              currentStep: step,
              totalSteps: 11,
              currentStepNumber: stepNumber,
            );
          },
        );
      }
    }

    // Step 1: Update Project List
    showProgress('Cập nhật danh sách dự án', 1);

try {
  // Make actual API call to get project data
  final projectResponse = await AuthenticatedHttpClient.get(
    Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/projectgs/$username'),
  );

  if (projectResponse.statusCode == 200) {
    final response4 = projectResponse.body;
    
    // Save to SharedPreferences
    await prefs.setString('update_response4', response4);
    
    // Process the data
    _processProjectData(response4);
    
    // Update last sync time
    await prefs.setString('lastProjectSync', DateTime.now().toIso8601String());
    _lastSyncTime = DateTime.now();

    if (mounted) {
      Navigator.of(context).pop(); // Close progress dialog
    }
  } else {
    throw Exception('Failed to load project data');
  }
} catch (e) {
  // Handle error
  print('Error loading project data: $e');
  throw e; // Re-throw to be caught by the outer try-catch
}

    // Step 2: Update Staff List
    showProgress('Cập nhật danh sách công nhân', 2);
    
    try {
      final staffListResponse = await AuthenticatedHttpClient.get(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/stafflist/$username'),
      );

      if (staffListResponse.statusCode == 200) {
        final List<dynamic> responseData = json.decode(staffListResponse.body);
        final dbHelper = DBHelper();
        
        // Clear existing staff list data
        await dbHelper.clearTable(DatabaseTables.staffListTable);
        
        // Convert each item to a StaffListModel
        final staffListModels = responseData.map((data) => 
          StaffListModel.fromMap(data as Map<String, dynamic>)
        ).toList();

        await dbHelper.batchInsertStaffList(staffListModels);
        
        // Close Step 2 dialog
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        throw Exception('Failed to load staff list data');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể cập nhật danh sách công nhân: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Step 3: Update Position List
    showProgress('Cập nhật danh sách vị trí làm việc', 3);
    
    try {
      final positionResponse = await AuthenticatedHttpClient.get(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/position'),
      );

      if (positionResponse.statusCode == 200) {
        final List<dynamic> positionData = json.decode(positionResponse.body);
        final dbHelper = DBHelper();
        
        // Clear existing position list data
        await dbHelper.clearTable(DatabaseTables.positionListTable);
        
        // Convert each item to a PositionListModel
        final positionListModels = positionData.map((data) => 
          PositionListModel.fromMap(data as Map<String, dynamic>)
        ).toList();

        await dbHelper.batchInsertPositionList(positionListModels);
        
        // Close Step 3 dialog
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        throw Exception('Failed to load position list data');
      }
    } catch (e) {
      print('Error updating position list: $e');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể cập nhật danh sách vị trí: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Step 4: Update Task History
    showProgress('Cập nhật lịch sử công việc', 4);
    
    try {
      final historyResponse = await AuthenticatedHttpClient.get(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/history/$username'),
      );

      if (historyResponse.statusCode == 200) {
        final List<dynamic> historyData = json.decode(historyResponse.body);
        final dbHelper = DBHelper();
        
        // Clear existing task history data
        await dbHelper.clearTable(DatabaseTables.taskHistoryTable);
        
        // Convert each item to a TaskHistoryModel
        final taskHistoryModels = historyData.map((data) => 
          TaskHistoryModel.fromMap(data as Map<String, dynamic>)
        ).toList();

        await dbHelper.batchInsertTaskHistory(taskHistoryModels);
        
        // Close Step 4 dialog
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        throw Exception('Failed to load task history data');
      }
    } catch (e) {
      print('Error updating task history: $e');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể cập nhật lịch sử công việc: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Step 5: Update Staff Bio (only if never synced before)
final hasStaffbioSynced = prefs.getBool('hasStaffbioSynced') ?? false;
          await prefs.setBool('hasStaffbioSynced', false);

if (!hasStaffbioSynced) {
  final shouldSync = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Cập nhật hồ sơ nhân sự'),
        content: Text('Bạn có muốn cập nhật hồ sơ nhân sự không? Quá trình này có thể mất một chút thời gian.\n CHỈ CẦN CẬP NHẬT LẦN ĐẦU HOẶC KHI NÀO CẦN THAY ĐỔI'),
        actions: <Widget>[
          TextButton(
            child: Text('Không'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text('Có'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      );
    },
  ) ?? false;

  if (shouldSync) {
    try {
      showProgress('Cập nhật hồ sơ nhân sự', 5);

      final response = await AuthenticatedHttpClient.get(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/staffbio'),
      );

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        
        final List<dynamic> staffbioData = decoded is Map ? decoded['data'] : decoded;
        final dbHelper = DBHelper();
        
        await dbHelper.clearTable(DatabaseTables.staffbioTable);
        
        final staffbioModels = staffbioData
          .map((data) {
            try {
              print('Mapping staffbio data: $data');
              return StaffbioModel.fromMap(data as Map<String, dynamic>);
            } catch (e) {
              // Log the fields that caused the issue
              print('Error mapping staffbio data: $e');
              print('Problematic data: $data');
              rethrow;
            }
          })
          .toList();

        try {
          await dbHelper.batchInsertStaffbio(staffbioModels);
          await prefs.setBool('hasStaffbioSynced', true);

          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cập nhật hồ sơ nhân sự thành công'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          // Log any issues with database insertion
          print('Error inserting staffbio data: $e');
          rethrow;
        }
      } else {
        throw Exception('Failed to load staffbio data');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể cập nhật hồ sơ nhân sự: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
  // Step 6: Update DongPhuc and ChiTietDP
showProgress('Đồng bộ dữ liệu đồng phục', 6);

try {
  // First, sync DongPhuc data
  final dongPhucResponse = await AuthenticatedHttpClient.get(
    Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/dongphuc/$username'),
  );

  if (dongPhucResponse.statusCode == 200) {
    final List<dynamic> dongPhucData = json.decode(dongPhucResponse.body);
    final dbHelper = DBHelper();
    
    // Clear existing dongphuc data
    await dbHelper.clearTable(DatabaseTables.dongPhucTable);
    
    // Convert and insert dongphuc data
    final dongPhucModels = dongPhucData.map((data) => 
      DongPhucModel.fromMap(data as Map<String, dynamic>)
    ).toList();

    await dbHelper.batchInsertDongPhuc(dongPhucModels);

    // Next, sync ChiTietDP data
    final chiTietDPResponse = await AuthenticatedHttpClient.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/dongphuclist'),
    );

    if (chiTietDPResponse.statusCode == 200) {
      final List<dynamic> chiTietDPData = json.decode(chiTietDPResponse.body);
      
      // Clear existing chitietdp data
      await dbHelper.clearTable(DatabaseTables.chiTietDPTable);
      
      // Convert and insert chitietdp data
      final chiTietDPModels = chiTietDPData.map((data) => 
        ChiTietDPModel.fromMap(data as Map<String, dynamic>)
      ).toList();

      await dbHelper.batchInsertChiTietDP(chiTietDPModels);
      
      // Close Step 6 dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      throw Exception('Failed to load ChiTietDP data');
    }
  } else {
    throw Exception('Failed to load DongPhuc data');
  }
} catch (e) {
  print('Error updating uniform data: $e');
  if (mounted) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Không thể cập nhật dữ liệu đồng phục: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
// Step 7: Update OrderMatHang
showProgress('Cập nhật danh sách mặt hàng', 7);

try {
  final orderMatHangResponse = await AuthenticatedHttpClient.get(
    Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/ordermathang'),
  );

  if (orderMatHangResponse.statusCode == 200) {
    final List<dynamic> orderMatHangData = json.decode(orderMatHangResponse.body);
    final dbHelper = DBHelper();
    
    await dbHelper.clearTable(DatabaseTables.orderMatHangTable);
    
    final orderMatHangModels = orderMatHangData.map((data) => 
      OrderMatHangModel.fromMap(data as Map<String, dynamic>)
    ).toList();

    await dbHelper.batchInsertOrderMatHang(orderMatHangModels);
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  } else {
    throw Exception('Failed to load OrderMatHang data');
  }
} catch (e) {
  print('Error updating OrderMatHang data: $e');
  if (mounted) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Không thể cập nhật danh sách mặt hàng: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
  return;
}

// Step 8: Update OrderDinhMuc
showProgress('Cập nhật định mức đơn hàng', 8);

try {
  final orderDinhMucResponse = await AuthenticatedHttpClient.get(
    Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/orderdinhmuc/$username'),
  );

  print('OrderDinhMuc API Response Status: ${orderDinhMucResponse.statusCode}');
  print('OrderDinhMuc Raw Response: ${orderDinhMucResponse.body}');

  if (orderDinhMucResponse.statusCode == 200) {
    final List<dynamic> orderDinhMucData = json.decode(orderDinhMucResponse.body);
    print('Decoded OrderDinhMuc Data: $orderDinhMucData');
    
    final dbHelper = DBHelper();
    
    // Log before clearing table
    final existingData = await dbHelper.query(DatabaseTables.orderDinhMucTable);
    print('Existing OrderDinhMuc records before clear: ${existingData.length}');
    
    await dbHelper.clearTable(DatabaseTables.orderDinhMucTable);
    print('OrderDinhMuc table cleared');

    // Log each data conversion
    final orderDinhMucModels = orderDinhMucData.map((data) {
      print('Processing OrderDinhMuc record: $data');
      try {
        final model = OrderDinhMucModel.fromMap(data as Map<String, dynamic>);
        print('Successfully converted to model: ${model.toMap()}');
        return model;
      } catch (e) {
        print('Error converting record: $e');
        print('Problematic data: $data');
        rethrow;
      }
    }).toList();
    
    print('Total OrderDinhMuc models created: ${orderDinhMucModels.length}');

    // Log batch insert
    try {
      await dbHelper.batchInsertOrderDinhMuc(orderDinhMucModels);
      print('Batch insert completed');

      // Verify inserted data
      final insertedData = await dbHelper.query(DatabaseTables.orderDinhMucTable);
      print('Records in OrderDinhMuc table after insert: ${insertedData.length}');
      print('Sample of inserted data: ${insertedData.take(2)}');
    } catch (e) {
      print('Error during batch insert: $e');
      rethrow;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  } else {
    print('API request failed with status: ${orderDinhMucResponse.statusCode}');
    throw Exception('Failed to load OrderDinhMuc data');
  }
} catch (e, stackTrace) {
  print('Error updating OrderDinhMuc data: $e');
  print('Stack trace: $stackTrace');
  if (mounted) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Không thể cập nhật định mức đơn hàng: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
  return;
}

// Step 9: Update Orders
showProgress('Cập nhật đơn hàng', 9);

try {
  final orderResponse = await AuthenticatedHttpClient.get(
    Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/orderdon/$username'),
  );

  if (orderResponse.statusCode == 200) {
    final List<dynamic> orderData = json.decode(orderResponse.body);
    final dbHelper = DBHelper();
    
    await dbHelper.clearTable(DatabaseTables.orderTable);
    
    final orderModels = orderData.map((data) => 
      OrderModel.fromMap(data as Map<String, dynamic>)
    ).toList();

    await dbHelper.batchInsertOrders(orderModels);
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  } else {
    throw Exception('Failed to load Orders data');
  }
} catch (e) {
  print('Error updating Orders data: $e');
  if (mounted) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Không thể cập nhật đơn hàng: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
  return;
}

// Step 10: Update OrderChiTiet
showProgress('Cập nhật chi tiết đơn hàng', 10);

try {
  final orderChiTietResponse = await AuthenticatedHttpClient.get(
    Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/orderchitiet/$username'),
  );

  if (orderChiTietResponse.statusCode == 200) {
    final List<dynamic> orderChiTietData = json.decode(orderChiTietResponse.body);
    final dbHelper = DBHelper();
    
    await dbHelper.clearTable(DatabaseTables.orderChiTietTable);
    
    final orderChiTietModels = orderChiTietData.map((data) => 
      OrderChiTietModel.fromMap(data as Map<String, dynamic>)
    ).toList();

    await dbHelper.batchInsertOrderChiTiet(orderChiTietModels);
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  } else {
    throw Exception('Failed to load OrderChiTiet data');
  }
} catch (e) {
  print('Error updating OrderChiTiet data: $e');
  if (mounted) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Không thể cập nhật chi tiết đơn hàng: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
  return;
}
// Step 11: Update ChamCongCN
showProgress('Cập nhật chấm công công nhân', 11);

try {
  print('Starting ChamCongCN update...');
  print('Fetching data from URL: https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongcn/$username');
  
  final chamCongCNResponse = await AuthenticatedHttpClient.get(
    Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongcn/$username'),
  );
  
  print('Response status code: ${chamCongCNResponse.statusCode}');
  print('LICH SU CHAM CONG: ${chamCongCNResponse.body}');

  if (chamCongCNResponse.statusCode == 200) {
    final List<dynamic> chamCongCNData = json.decode(chamCongCNResponse.body);
    print('Successfully decoded JSON data. Number of records: ${chamCongCNData.length}');
    
    final dbHelper = DBHelper();
    
    print('Clearing existing ChamCongCN table...');
    await dbHelper.clearTable(DatabaseTables.chamCongCNTable);
    
    print('Converting data to ChamCongCN models...');
    final chamCongCNModels = chamCongCNData.map((data) {
      try {
        return ChamCongCNModel.fromMap(data as Map<String, dynamic>);
      } catch (e) {
        print('Error converting record to model: $e');
        print('Problematic data: $data');
        rethrow;
      }
    }).toList();
    
    print('Inserting ${chamCongCNModels.length} records into database...');
    await dbHelper.batchInsertChamCongCN(chamCongCNModels);
    print('Database insertion completed successfully');

    if (mounted) {
      print('Closing progress dialog...');
      Navigator.of(context).pop();
    }
  } else {
    throw Exception('Failed to load ChamCongCN data');
  }
} catch (e) {
  print('ERROR: Detailed error in ChamCongCN update:');
  print('Error type: ${e.runtimeType}');
  print('Error message: $e');
  print('Stack trace: ${StackTrace.current}');
  
  if (mounted) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Không thể cập nhật chấm công công nhân: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
  return;
}
  } catch (e) {
    print('Error loading projects: $e');
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể tải dự án. Vui lòng thử lại sau.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
  @override
Widget build(BuildContext context) {
  final userCredentials = Provider.of<UserCredentials>(context);
  String username = userCredentials.username.toUpperCase();

  return Scaffold(
    appBar: AppBar(
      toolbarHeight: 45,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 114, 255, 175),
              Color.fromARGB(255, 201, 255, 225),
              Color.fromARGB(255, 79, 255, 249),
              Color.fromARGB(255, 188, 255, 248),
            ],
          ),
        ),
      ),
      title: Text(
        'Dự án của $username',
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loadProjects,
          style: TextButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          ),
          child: Text(
            'Đồng bộ',
            style: TextStyle(
              fontSize: 12,
              color: const Color.fromARGB(255, 0, 204, 34),
            ),
          ),
        ),
        SizedBox(width: 16)
      ],
    ),
    body: Container(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
    Row(
  children: [
    Text(
      '✳️ Chọn lại hoặc  ',
      style: TextStyle(fontSize: 16),
    ),
        SizedBox(height: 8),
    TextButton(
      style: ButtonStyle(
        padding: MaterialStateProperty.all(EdgeInsets.zero),
        minimumSize: MaterialStateProperty.all(Size(0, 0)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () {
        setState(() {
          _isGridView = !_isGridView;
        });
      },
      child: Text(
        _isGridView ? 'Xếp dạng thường' : 'Xếp dạng ô 𖣯',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    ),
  ],
),
    SizedBox(height: 8),
    Wrap(
      spacing: 16,
      children: [
        TextButton(
          style: ButtonStyle(
            padding: MaterialStateProperty.all(EdgeInsets.zero),
            minimumSize: MaterialStateProperty.all(Size(0, 0)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: _selectedProject == null ? null : () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProjectUpdateScreen(
                  boPhan: _selectedProject!,
                ),
              ),
            ).then((_) {
              // Reload staff list when returning from ProjectUpdateScreen
              if (_selectedProject != null) {
                _loadStaffForProject(_selectedProject!);
              }
            });
          },
          child: Text(
            'Cập nhật dự án',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _selectedProject != null 
                  ? const Color.fromARGB(255, 0, 204, 34)
                  : Colors.grey,
            ),
          ),
        ),
        TextButton(
          style: ButtonStyle(
            padding: MaterialStateProperty.all(EdgeInsets.zero),
            minimumSize: MaterialStateProperty.all(Size(0, 0)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return TopicReportDialog(
                  boPhan: _selectedProject ?? '',
                  username: userCredentials.username,
                );
              },
            );
          },
          child: Text(
            'Báo cáo theo chủ đề',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 0, 204, 34),
            ),
          ),
        ),
      ],
    ),
  ],
),
            SizedBox(height: 8),
          if (_isLoading)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color.fromARGB(255, 0, 204, 34),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Đang tải dự án...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              child: _projectList.isEmpty
                ? Column(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 48,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Không có dữ liệu dự án',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '⚠️Vui lòng đăng xuất, đăng nhập lại và nhấn nút "Đồng bộ" để lấy dữ liệu.\n⚠️Nếu đã đăng nhập mà khi đồng bộ hiện dòng màu đỏ ở dưới thì phải:\n⚠️quay lại trang cá nhân (nút đỏ) bấm Cập nhật ở trên rồi quay lại⚠️',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProjects,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 0, 204, 34),
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Thử đồng bộ ngay'),
                      ),
                    ],
                  )
                : DropdownButtonFormField<String>(
                    value: _selectedProject,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    hint: Text('Chọn dự án'),
                    items: _projectList.map((String project) {
                      return DropdownMenuItem<String>(
                        value: project,
                        child: Text(project),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedProject = newValue;
                      });
                      if (newValue != null) {
                        _loadStaffForProject(newValue);
                      }
                    },
                  ),
            ),
            if (_selectedProject != null && !_isLoading) ...[
              SizedBox(height: 6),
              Align(
              alignment: Alignment.centerRight,
              child: FutureBuilder<List<int>>(
                future: Future.wait([
                  _getActiveStaffCount(),
                  _getTodayReportCount(),
                ]),
                builder: (context, snapshot) {
                  final activeCount = snapshot.data?[0] ?? 0;
                  final reportCount = snapshot.data?[1] ?? 0;
                  return Text(
                    'Số CN đang làm: $activeCount / Số báo cáo hôm nay: $reportCount',
                    style: TextStyle(
                      fontSize: 10,
                      color: const Color.fromARGB(255, 25, 138, 0),
                      fontStyle: FontStyle.italic,
                    ),
                  );
                },
              ),
            ),
              SizedBox(height: 16),
             Expanded(
  child: _staffList.isEmpty
    ? Center(
        child: Text(
          'Không có nhân viên trong dự án này',
          style: TextStyle(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      )
    : _isGridView ? _buildGridView(userCredentials) : _buildListView(userCredentials),
),
            ],
          ],
        ),
      ),
    );
  }
  Widget _buildListView(UserCredentials userCredentials) {

  return ListView.builder(
    itemCount: _staffList.length,
    itemBuilder: (context, index) {
      final staff = _staffList[index];
      final vtStatus = staff['vt_status'] as Map<String, dynamic>?;
      
      // Format the date if it exists
      String formattedDate = '';
      if (vtStatus != null && vtStatus['Ngay'] != null) {
        final date = DateTime.parse(vtStatus['Ngay']);
        formattedDate = DateFormat('dd/MM/yy').format(date);
      }
      
      return InkWell(
        onTap: () async {
          final result = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return StaffDetailDialog(
                staff: staff,
                boPhan: _selectedProject ?? '',
                username: userCredentials.username,
              );
            },
          );
          if (result == true) {
            // Reload staff list if position was updated
            _loadStaffForProject(_selectedProject!);
          }
        },
        child: Card(
          margin: EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color.fromARGB(255, 25, 138, 0),
                  child: Text(
                    (staff['VT'] ?? 'NA').toString().toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                title: Text(
                  staff['Ho_ten'] ?? '❓❓❓',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mã NV: ${staff['MaNV']}'),
                    if (vtStatus != null) Text(
                      '${vtStatus['TrangThai'] ?? ''} từ $formattedDate bởi ${vtStatus['HoTro'] ?? ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Color.fromARGB(255, 0, 204, 34),
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.person_outline),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) => StaffStatusDialog(
                            manv: staff['MaNV'],
                            vt: staff['VT'] ?? '',
                            boPhan: _selectedProject ?? '',
                            username: userCredentials.username,
                          ),
                        );
                      },
                      color: Color.fromARGB(255, 0, 204, 34),
                    ),
                    IconButton(
                      icon: Icon(Icons.check_circle_outline),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) => TaskReportDialog(
                            vt: staff['VT'] ?? '',
                            boPhan: _selectedProject ?? '',
                            username: userCredentials.username,
                          ),
                        );
                      },
                      color: Color.fromARGB(255, 0, 204, 34),
                    ),
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

Widget _buildGridView(UserCredentials userCredentials) {
    final screenSize = MediaQuery.of(context).size;
  final isLandscape = screenSize.width > screenSize.height;
  final crossAxisCount = isLandscape ? 6 : 3;
  final childAspectRatio = isLandscape ? 1.2 : 1.0;

  return GridView.builder(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: crossAxisCount,
      childAspectRatio: childAspectRatio,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    ),
    itemCount: _staffList.length,
    itemBuilder: (context, index) {
      final staff = _staffList[index];
      final vtStatus = staff['vt_status'] as Map<String, dynamic>?;
      final currentStatus = vtStatus?['TrangThai'] ?? 'Đang làm việc';
      
      // Get status color
      Color statusColor = Colors.grey;
      if (vtStatus != null) {
        switch (vtStatus['TrangThai']) {
          case 'Đang làm việc':
            statusColor = Colors.green;
            break;
          case 'Nghỉ':
            statusColor = Colors.indigo;
            break;
          case 'Đi hỗ trợ':
            statusColor = Colors.lightBlue;
            break;
          case 'Thiếu':
            statusColor = Colors.deepOrange;
            break;
        }
      }
      
      return InkWell(
        onTap: () {
          // Quick status change
          showDialog(
            context: context,
            builder: (context) {
              return SimpleDialog(
                title: Text('Chọn trạng thái cho ${staff['Ho_ten']}'),
                children: [
                  'Đang làm việc',
                  'Nghỉ',
                  'Đi hỗ trợ',
                  'Thiếu'
                ].map((status) => SimpleDialogOption(
                  onPressed: () async {
                    Navigator.pop(context);
                    
                    final now = DateTime.now();
                    final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                    
                    final vtHistory = VTHistoryModel(
                      uid: const Uuid().v4(),
                      ngay: now,
                      gio: timeString,
                      nguoiDung: userCredentials.username.toLowerCase(),
                      boPhan: _selectedProject ?? '',
                      viTri: staff['VT'] ?? '',
                      nhanVien: staff['MaNV'],
                      trangThai: status,
                      hoTro: '',
                      phuongAn: 'Cập nhật nhanh từ chế độ lưới',
                    );

                    try {
                      // Send to server
                      final response = await http.post(
                        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/vthistory'),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode(vtHistory.toMap()),
                      );

                      if (response.statusCode == 200) {
                        // Add to local database
                        final dbHelper = DBHelper();
                        await dbHelper.insertVTHistory(vtHistory);
                        
                        // Reload staff list
                        if (_selectedProject != null) {
                          _loadStaffForProject(_selectedProject!);
                        }
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã cập nhật trạng thái thành công'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        throw Exception('Server returned ${response.statusCode}');
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lỗi khi cập nhật: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: status == 'Đang làm việc' ? Colors.green :
                                  status == 'Nghỉ' ? Colors.red :
                                  status == 'Đi hỗ trợ' ? Colors.orange : 
                                  Colors.purple,
                            shape: BoxShape.circle,
                          ),
                          margin: EdgeInsets.only(right: 10),
                        ),
                        Text(
                          status,
                          style: TextStyle(
                            fontWeight: status == currentStatus ? 
                              FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (status == currentStatus)
                          Padding(
                            padding: EdgeInsets.only(left: 5),
                            child: Icon(Icons.check, size: 16, color: Colors.green),
                          )
                      ],
                    ),
                  ),
                )).toList(),
              );
            },
          );
        },
        child: Card(
          color: Colors.white,
          elevation: 2, // Add subtle shadow
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0),
            side: BorderSide(color: statusColor, width: 2),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor, // Match the status color
                    radius: 24,
                    child: Text(
                      (staff['VT'] ?? 'NA').toString().toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      staff['Ho_ten'] ?? '❓❓❓',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      currentStatus,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
}
class SyncProgressDialog extends StatelessWidget {
  final String currentStep;
  final int totalSteps;
  final int currentStepNumber;

  const SyncProgressDialog({
    required this.currentStep,
    required this.totalSteps,
    required this.currentStepNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color.fromARGB(255, 0, 204, 34),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Bước $currentStepNumber/$totalSteps',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              currentStep,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
class StaffStatusDialog extends StatefulWidget {
  final String manv;
  final String vt;
  final String boPhan;
  final String username;

  const StaffStatusDialog({
    required this.manv,
    required this.vt,
    required this.boPhan,
    required this.username,
  });

  @override
  _StaffStatusDialogState createState() => _StaffStatusDialogState();
}

class _StaffStatusDialogState extends State<StaffStatusDialog> {
  String? _currentStatus;
  List<String> _selectedHoTro = [];
  final TextEditingController _phuongAnController = TextEditingController();
  List<String> _staffVTList = [];
  VTHistoryModel? _latestVTHistory;
  bool _isLoading = true;
  final List<String> _statusOptions = [
    'Đang làm việc',
    'Nghỉ',
    'Đi hỗ trợ',
    'Thiếu'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _phuongAnController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DBHelper();
      
      // Load staff list VT values for current department
      final staffList = await dbHelper.query(
        DatabaseTables.staffListTable,
        where: 'BoPhan = ?',
        whereArgs: [widget.boPhan],
      );
      
      // Extract unique VT values
      _staffVTList = staffList
          .map((staff) => staff['VT'] as String?)
          .where((vt) => vt != null)
          .toSet()
          .toList()
          .cast<String>();

      // Get latest VTHistory record
      final vtHistories = await dbHelper.query(
        DatabaseTables.vtHistoryTable,
        where: 'NhanVien = ? AND NguoiDung = ? AND BoPhan = ?',
        whereArgs: [widget.manv, widget.username.toLowerCase(), widget.boPhan],
      );

      if (vtHistories.isNotEmpty) {
        // Sort by date and time to get the latest record
        vtHistories.sort((a, b) {
          int dateCompare = DateTime.parse(b['Ngay'] as String)
              .compareTo(DateTime.parse(a['Ngay'] as String));
          if (dateCompare == 0) {
            return (b['Gio'] as String).compareTo(a['Gio'] as String);
          }
          return dateCompare;
        });

        _latestVTHistory = VTHistoryModel.fromMap(vtHistories.first);
        _currentStatus = _latestVTHistory?.trangThai;
        _selectedHoTro = _latestVTHistory?.hoTro?.split(',').map((e) => e.trim()).toList() ?? [];
        _phuongAnController.text = _latestVTHistory?.phuongAn ?? '';
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải dữ liệu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    try {
      // Prepare the data
      final now = DateTime.now();
      final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      final vtHistory = VTHistoryModel(
        uid: const Uuid().v4(),
        ngay: now,
        gio: timeString,
        nguoiDung: widget.username.toLowerCase(),
        boPhan: widget.boPhan,
        viTri: widget.vt,
        nhanVien: widget.manv,
        trangThai: _currentStatus,
        hoTro: _selectedHoTro.join(', '),
        phuongAn: _phuongAnController.text,
      );

      final Map<String, dynamic> requestData = vtHistory.toMap();
      print('Sending data to server: ${json.encode(requestData)}');

      // Send to server
      final response = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/vthistory'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );

      print('Server response status: ${response.statusCode}');
      print('Server response body: ${response.body}');

      if (response.statusCode == 200) {
        // Add to local database
        final dbHelper = DBHelper();
        await dbHelper.insertVTHistory(vtHistory);

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã lưu thành công'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('Error saving changes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu thay đổi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: EdgeInsets.all(16),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color.fromARGB(255, 0, 204, 34),
                  ),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tình trạng hiện tại',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _currentStatus,
                      decoration: InputDecoration(
                        labelText: 'Trạng thái',
                        border: OutlineInputBorder(),
                      ),
                      items: _statusOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _currentStatus = newValue;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    Text('Bộ phận: ${widget.boPhan}'),
                    SizedBox(height: 8),
                    Text('Vị trí: ${widget.vt}'),
                    SizedBox(height: 16),
                    Text('Hỗ trợ:'),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      height: 150,
                      child: ListView.builder(
                        itemCount: _staffVTList.length,
                        itemBuilder: (context, index) {
                          final vt = _staffVTList[index];
                          return CheckboxListTile(
                            title: Text(vt),
                            value: _selectedHoTro.contains(vt),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedHoTro.add(vt);
                                } else {
                                  _selectedHoTro.remove(vt);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _phuongAnController,
                      decoration: InputDecoration(
                        labelText: 'Phương án',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 0, 204, 34),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _saveChanges,
                        child: Text('Lưu'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
class TaskReportDialog extends StatefulWidget {
  final String vt;
  final String boPhan;
  final String username;

  const TaskReportDialog({
    required this.vt,
    required this.boPhan,
    required this.username,
  });

  @override
  _TaskReportDialogState createState() => _TaskReportDialogState();
}
class _TaskReportDialogState extends State<TaskReportDialog> {
  List<ChecklistModel> _tasks = [];
  bool _isLoading = true;
  final TextEditingController _customTaskController = TextEditingController();
  final TextEditingController _customTimeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _customTaskController.dispose();
    _customTimeController.dispose();
    super.dispose();
  }
Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DBHelper();
      final checklistItems = await dbHelper.query(
        DatabaseTables.checklistTable,
        where: 'DUAN = ? AND VITRI = ?',
        whereArgs: [widget.boPhan, widget.vt],
      );

      _tasks = checklistItems.map((map) => ChecklistModel.fromMap(map)).toList();

      // Sort tasks by time proximity to now
      final now = DateTime.now();
      final currentTimeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      _tasks.sort((a, b) {
        final aTime = a.start ?? '00:00';
        final bTime = b.start ?? '00:00';
        
        // Calculate time difference from now
        final aDiff = _getTimeDifference(currentTimeString, aTime);
        final bDiff = _getTimeDifference(currentTimeString, bTime);
        
        return aDiff.compareTo(bDiff);
      });

    } catch (e) {
      print('Error loading tasks: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể tải danh sách công việc'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  int _getTimeDifference(String currentTime, String taskTime) {
    final current = _parseTimeToMinutes(currentTime);
    final task = _parseTimeToMinutes(taskTime);
    final diff = task - current;
    // Handle cases where task is for next day
    return diff < -720 ? diff + 1440 : diff;
  }

  int _parseTimeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
Future<void> _quickSubmitTask(ChecklistModel task) async {
  final now = DateTime.now();
  final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  
  try {
    // Create task history object
    final taskHistory = TaskHistoryModel(
      uid: const Uuid().v4(),
      taskId: task.taskid,
      ngay: now,
      gio: timeString,
      nguoiDung: widget.username.toLowerCase(),
      ketQua: '✔️',
      chiTiet: 'Hoàn thành',
      viTri: widget.vt,
      boPhan: widget.boPhan,
      phanLoai: 'Kiểm tra chất lượng',
      chiTiet2: '${task.start}-${task.end}-${task.task}',
      giaiPhap: '',
    );

    // Send to server
    final response = await http.post(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/taskhistory'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(taskHistory.toMap()),
    );

    if (response.statusCode == 200) {
      // Add to local database only after successful server submission
      final dbHelper = DBHelper();
      await dbHelper.insertTaskHistory(taskHistory);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã lưu báo cáo thành công'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      throw Exception('Server returned ${response.statusCode}');
    }
  } catch (e) {
    print('Error quick submitting task: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể gửi báo cáo: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
  void _showTaskReportSheet(ChecklistModel? task) {
    // If task is null, create a custom task from the input fields
    final reportTask = task ?? ChecklistModel(
      taskid: const Uuid().v4(),
      duan: widget.boPhan,
      vitri: widget.vt,
      task: _customTaskController.text,
      // Only include time if provided
      start: _customTimeController.text.isNotEmpty ? _customTimeController.text.split('-').first.trim() : null,
      end: _customTimeController.text.isNotEmpty ? _customTimeController.text.split('-').last.trim() : null,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return TaskReportSheet(
          task: reportTask,
          vt: widget.vt,
          boPhan: widget.boPhan,
          username: widget.username,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Báo cáo công việc',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            // Custom task input card always shown at the top
            Card(
              margin: EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tạo báo cáo mới',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color.fromARGB(255, 0, 204, 34),
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _customTaskController,
                      decoration: InputDecoration(
                        labelText: 'Nội dung công việc',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _customTimeController,
                      decoration: InputDecoration(
                        labelText: 'Thời gian (tùy chọn, vd: 8:00 - 17:00)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 0, 204, 34),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          if (_customTaskController.text.isNotEmpty) {
                            _showTaskReportSheet(null);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Vui lòng nhập nội dung công việc'),
                              ),
                            );
                          }
                        },
                        child: Text('Tạo báo cáo'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color.fromARGB(255, 0, 204, 34),
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_tasks.isNotEmpty) ...[
                      Text(
                        'Danh sách công việc:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                    ],
                    Expanded(
                      child: ListView.builder(
                        itemCount: _tasks.length,
                        itemBuilder: (context, index) {
                          final task = _tasks[index];
                          return Dismissible(
                            key: Key(task.taskid),
                            background: Container(
                              color: Colors.green,
                              alignment: Alignment.centerRight,
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: Icon(Icons.check, color: Colors.white),
                            ),
                            confirmDismiss: (direction) async {
                              await _quickSubmitTask(task);
                              return false;
                            },
                            child: Card(
                              margin: EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () => _showTaskReportSheet(task),
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.task ?? '',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      if (task.start != null && task.end != null)
                                        Text(
                                          '${task.start} - ${task.end}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
class TaskReportSheet extends StatefulWidget {
  final ChecklistModel task;
  final String vt;
  final String boPhan;
  final String username;
  final String? phanLoai;
  final bool isTopicReport; 
  final String prefilledDetails; 
  const TaskReportSheet({
    required this.task,
    required this.vt,
    required this.boPhan,
    required this.username,
    this.phanLoai,
    this.isTopicReport = false,
    this.prefilledDetails = '',
  });

  @override
  _TaskReportSheetState createState() => _TaskReportSheetState();
}
class _TaskReportSheetState extends State<TaskReportSheet> {
  XFile? _secondImageFile;
bool _showCombinedImage = false;
Uint8List? _combinedImageBytes;
  @override
  void initState() {
    super.initState();
    if (widget.prefilledDetails.isNotEmpty) {
      _detailController.text = widget.prefilledDetails;
    }
  }
  String? _selectedResult;
  final TextEditingController _detailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _giaiPhapController = TextEditingController();
  XFile? _imageFile;
  bool _isSubmitting = false;
  MobileScannerController _scannerController = MobileScannerController();
  bool _isScanning = false;

  final List<Map<String, String>> _resultOptions = [
    {'value': '✔️', 'label': 'Hoàn thành'},
    {'value': '⚠️', 'label': 'Cảnh báo'},
    {'value': '❌', 'label': 'Không đạt'},
  ];

  @override
  void dispose() {
    _detailController.dispose();
    _codeController.dispose();
    _giaiPhapController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          height: 400,
          child: Column(
            children: [
              AppBar(
                title: Text('Quét mã QR'),
                leading: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _isScanning = false;
                    });
                  },
                ),
              ),
              Expanded(
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      _codeController.text = barcode.rawValue ?? '';
                      Navigator.pop(context);
                      setState(() {
                        _isScanning = false;
                      });
                      break;
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _captureImage() async {
  final ImagePicker picker = ImagePicker();
  try {
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 70,
    );

    if (image != null) {
      setState(() {
        if (_imageFile == null) {
          _imageFile = image;
          // Show camera again for second image
          _captureSecondImage();
        } else {
          _secondImageFile = image;
          // Combine images
          _combineImages();
        }
      });
    }
  } catch (e) {
    print('Error capturing image: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể chụp ảnh'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
Future<void> _captureSecondImage() async {
  final ImagePicker picker = ImagePicker();
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Thêm ảnh góc nhìn khác?'),
        content: Text('Đối với WC bắt buộc phải chụp ảnh từ ngoài nhìn vào trong và từ trong nhìn ra ngoài Hai ảnh sẽ được ghép cạnh nhau.'),
        actions: [
          TextButton(
            child: Text('Bỏ qua'),
            onPressed: () {
              Navigator.of(context).pop();
              // Skip second image, continue with just the first one
              setState(() {
                _showCombinedImage = false;
              });
            },
          ),
          TextButton(
            child: Text('Chụp thêm'),
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 1800,
                  maxHeight: 1800,
                  imageQuality: 70,
                );

                if (image != null) {
                  setState(() {
                    _secondImageFile = image;
                    // Combine images
                    _combineImages();
                  });
                }
              } catch (e) {
                print('Error capturing second image: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Không thể chụp ảnh thứ hai'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      );
    },
  );
}

Future<void> _combineImages() async {
  if (_imageFile == null || _secondImageFile == null) return;
  
  try {
    // Read both images
    final Uint8List firstImageBytes = await _imageFile!.readAsBytes();
    final Uint8List secondImageBytes = await _secondImageFile!.readAsBytes();
    
    // Decode images
    final img.Image? firstImage = img.decodeImage(firstImageBytes);
    final img.Image? secondImage = img.decodeImage(secondImageBytes);
    
    if (firstImage == null || secondImage == null) {
      throw Exception('Failed to decode images');
    }
    
    // Determine the output size (width will be sum of widths, height will be max of heights)
    final int outputWidth = firstImage.width + secondImage.width + 3; // +3 for the separator line
    final int outputHeight = max(firstImage.height, secondImage.height);
    
    // Create a new image with the combined dimensions
    final img.Image combinedImage = img.Image(width: outputWidth, height: outputHeight);
    
    // Fill with white background
    img.fill(combinedImage, color: img.ColorRgb8(255, 255, 255));
    
    // Copy the first image to the left side
    for (int y = 0; y < firstImage.height; y++) {
      for (int x = 0; x < firstImage.width; x++) {
        int destY = (outputHeight - firstImage.height) ~/ 2 + y;
        if (destY >= 0 && destY < outputHeight && x < outputWidth) {
          combinedImage.setPixel(x, destY, firstImage.getPixel(x, y));
        }
      }
    }
    
    // Draw a black vertical line separator (3 pixels wide)
    for (int y = 0; y < outputHeight; y++) {
      for (int x = 0; x < 3; x++) {
        combinedImage.setPixel(firstImage.width + x, y, img.ColorRgb8(0, 0, 0));
      }
    }
    
    // Copy the second image to the right side
    for (int y = 0; y < secondImage.height; y++) {
      for (int x = 0; x < secondImage.width; x++) {
        int destX = firstImage.width + 3 + x; // +3 for the separator line
        int destY = (outputHeight - secondImage.height) ~/ 2 + y;
        if (destY >= 0 && destY < outputHeight && destX < outputWidth) {
          combinedImage.setPixel(destX, destY, secondImage.getPixel(x, y));
        }
      }
    }
    
    // Encode the combined image to PNG
    final Uint8List combinedBytes = Uint8List.fromList(img.encodePng(combinedImage));
    
    setState(() {
      _combinedImageBytes = combinedBytes;
      _showCombinedImage = true;
    });
  } catch (e) {
    print('Error combining images: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Không thể kết hợp ảnh: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
  Future<String?> _uploadImage(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      
      // Create multipart request
      var uri = Uri.parse('YOUR_IMAGE_UPLOAD_ENDPOINT');
      var request = http.MultipartRequest('POST', uri);
      
      // Add file
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: path.basename(imageFile.path),
        ),
      );

      // Send request
      var response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final parsedResponse = json.decode(responseData);
        return parsedResponse['url'];  // Adjust based on actual response format
      }
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
    return null;
  }
final bool _shouldRequirePhoto = Random().nextDouble() < 0.85;
bool _validateSubmission() {
    // Create a list to collect all validation errors
    List<String> errors = [];

    if (widget.username.trim().isEmpty) {
      errors.add('Không thể xác định người dùng');
    }

    if (widget.boPhan.trim().isEmpty) {
      errors.add('Không thể xác định dự án');
    }
    
    // Check if ViTri is empty
    if (widget.vt.trim().isEmpty) {
      errors.add('Vui lòng cập nhật thông tin vị trí (VT) của nhân viên trước khi báo cáo');
    }

    if (_selectedResult == null) {
      errors.add('Vui lòng chọn kết quả');
    }

    // Special check for Máy móc and Xe/Giỏ đồ topics - always require image and QR code
    if (widget.isTopicReport && 
        (widget.task.task == 'Máy móc' || widget.task.task == 'Xe/Giỏ đồ')) {
      
      if (_imageFile == null) {
        errors.add('Vui lòng chụp ảnh cho báo cáo này');
      }
      
      if (_codeController.text.isEmpty) {
        errors.add('Vui lòng quét mã QR cho báo cáo này');
      }
    }
    // Modified photo requirement logic to include success result for 70% of users
    else if ((_selectedResult == '⚠️' || _selectedResult == '❌' || 
              (_selectedResult == '✔️' && _shouldRequirePhoto)) && 
             _imageFile == null) {
      errors.add('Vui lòng chụp ảnh');
    }

    if ((_selectedResult == '⚠️' || _selectedResult == '❌') && _giaiPhapController.text.isEmpty) {
      errors.add('Vui lòng nhập giải pháp');
    }

    // Show all errors if any exist
    if (errors.isNotEmpty) {
      // Use a Dialog instead of a SnackBar to ensure it's visible
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Lỗi kiểm tra'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: errors.map((error) => Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(child: Text(error)),
                  ],
                ),
              )).toList(),
            ),
            actions: [
              TextButton(
                child: Text('Đóng'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return false;
    }

    return true;
  }
Future<void> _submitReport() async {
  if (!_validateSubmission()) return;

  setState(() {
    _isSubmitting = true;
  });

  try {
    final now = DateTime.now();
    final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final uuid = const Uuid().v4();

    String? imageUrl;
    String taskChiTiet2;
    if (widget.isTopicReport) {
      taskChiTiet2 = _codeController.text;
    } else {
      taskChiTiet2 = '${widget.task.start}-${widget.task.end}-${widget.task.task}';
    }

    // Use the combined image if available, otherwise use the single image
    final imageToUpload = _combinedImageBytes != null ? _combinedImageBytes : 
                     (_imageFile != null ? await _imageFile!.readAsBytes() : null);
    // Always use MultipartRequest when an image is available
    if (imageToUpload != null) {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/taskhistory'),
      );

      // Create a temporary file with the combined image bytes if using combined image
      if (_combinedImageBytes != null) {
        final tempDir = await Directory.systemTemp.createTemp();
        final tempFile = File('${tempDir.path}/combined_image.png');
        await tempFile.writeAsBytes(_combinedImageBytes!);
        
        request.files.add(
          await http.MultipartFile.fromPath(
            'HinhAnh',
            tempFile.path,
            filename: 'combined_image.png',
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromBytes(
            'HinhAnh',
            imageToUpload!,
            filename: path.basename(_imageFile!.path),
          ),
        );
      }

      final taskData = {
        'UID': uuid,
        'NguoiDung': widget.username.toLowerCase(),
        'TaskID': widget.task.taskid,
        'KetQua': _selectedResult,
        'Ngay': now.toIso8601String(),
        'Gio': timeString,
        'ChiTiet': _detailController.text,
        'ChiTiet2': taskChiTiet2,
        'ViTri': widget.vt,
        'BoPhan': widget.boPhan,
        'PhanLoai': widget.phanLoai ?? 'Kiểm tra chất lượng',
        'GiaiPhap': _giaiPhapController.text.trim(),
      };

      request.fields.addAll(
        taskData.map((key, value) => MapEntry(key, value?.toString() ?? '')),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      print('Server response for image upload: $responseData');
      
      final result = json.decode(responseData);

      if (response.statusCode == 200) {
        imageUrl = result['imageUrl'];
        print('Image uploaded successfully, URL: $imageUrl');
      } else {
        throw Exception('Server returned ${response.statusCode}: ${responseData}');
      }
    } else {
      // Only use JSON request when there's no image
      final taskHistory = TaskHistoryModel(
        uid: uuid,
        taskId: widget.task.taskid,
        ngay: now,
        gio: timeString,
        nguoiDung: widget.username.toLowerCase(),
        ketQua: _selectedResult,
        chiTiet: _detailController.text,
        chiTiet2: taskChiTiet2,
        viTri: widget.vt,
        boPhan: widget.boPhan,
        phanLoai: widget.phanLoai ?? 'Kiểm tra chất lượng',
        hinhAnh: imageUrl,
        giaiPhap: _giaiPhapController.text.trim(),
      );

      final response = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/taskhistory'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(taskHistory.toMap()),
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }
    }

    // Create the model with the received image URL
    final taskHistory = TaskHistoryModel(
      uid: uuid,
      taskId: widget.task.taskid,
      ngay: now,
      gio: timeString,
      nguoiDung: widget.username.toLowerCase(),
      ketQua: _selectedResult,
      chiTiet: _detailController.text,
      chiTiet2: taskChiTiet2,
      viTri: widget.vt,
      boPhan: widget.boPhan,
      phanLoai: widget.phanLoai ?? 'Kiểm tra chất lượng',
      hinhAnh: imageUrl,
      giaiPhap: _giaiPhapController.text.trim(),
    );
    
    // Save to local DB
    final dbHelper = DBHelper();
    await dbHelper.insertTaskHistory(taskHistory);
    
    if (mounted) {
      Navigator.of(context).pop();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu báo cáo thành công'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    print('Error submitting report: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể gửi báo cáo: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}
@override
Widget build(BuildContext context) {
  final screenSize = MediaQuery.of(context).size;
  final isTablet = screenSize.width > 600;
  
  return Container(
    width: isTablet ? screenSize.width * 0.7 : screenSize.width,
    constraints: BoxConstraints(
      maxHeight: screenSize.height * 0.8,
      maxWidth: 800,
    ),
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Báo cáo kết quả',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  isTablet 
                    ? GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: 3,
                        childAspectRatio: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: _resultOptions.map((option) {
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedResult == option['value']
                                  ? const Color.fromARGB(255, 0, 204, 34)
                                  : Colors.grey[200],
                              foregroundColor: _selectedResult == option['value']
                                  ? Colors.white
                                  : Colors.black,
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedResult = option['value'];
                              });
                            },
                            child: Text(
                              '${option['value']} ${option['label']}',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }).toList(),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _resultOptions.map((option) {
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedResult == option['value']
                                      ? const Color.fromARGB(255, 0, 204, 34)
                                      : Colors.grey[200],
                                  foregroundColor: _selectedResult == option['value']
                                      ? Colors.white
                                      : Colors.black,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedResult = option['value'];
                                  });
                                },
                                child: Text(
                                  '${option['value']}\n${option['label']}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _detailController,
                    decoration: InputDecoration(
                      labelText: 'Chi tiết hiện trạng / vấn đề',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: null,
                    minLines: 3,
                  ),
                  if (_selectedResult != null && _selectedResult != '✔️') ...[
                    SizedBox(height: 16),
                    TextField(
                      controller: _giaiPhapController,
                      decoration: InputDecoration(
                        labelText: 'Giải pháp',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: null,
                      minLines: 3,
                    ),
                  ],
                  if (widget.isTopicReport) ...[
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            decoration: InputDecoration(
                              labelText: 'Mã QR',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.qr_code_scanner),
                          onPressed: _startScanning,
                          color: const Color.fromARGB(255, 0, 204, 34),
                        ),
                      ],
                    ),
                  ],
                  if (!widget.isTopicReport && (_selectedResult == '⚠️' || _selectedResult == '❌' || 
                      (_selectedResult == '✔️' && _shouldRequirePhoto))) ...[
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.camera_alt),
                            label: Text(_imageFile == null ? 'Chụp ảnh' : 'Chụp lại'),
                            onPressed: _captureImage,
                          ),
                        ),
                      ],
                    ),
                    if (_imageFile != null) ...[
                      SizedBox(height: 8),
                      if (_showCombinedImage && _combinedImageBytes != null) ...[
                        Text(
                          'Ảnh ghép:',
                          style: TextStyle(
                            fontSize: 14, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        SizedBox(height: 4),
                        Image.memory(
                          _combinedImageBytes!,
                          height: 150,
                          fit: BoxFit.contain,
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (_imageFile != null) ...[
                                    Text('Ảnh 1', style: TextStyle(fontSize: 12)),
                                    SizedBox(height: 4),
                                    FutureBuilder<Uint8List>(
                                      future: _imageFile!.readAsBytes(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return Image.memory(
                                            snapshot.data!,
                                            height: 100,
                                            fit: BoxFit.cover,
                                          );
                                        }
                                        return SizedBox(height: 100);
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (_secondImageFile != null) ...[
                                    Text('Ảnh 2', style: TextStyle(fontSize: 12)),
                                    SizedBox(height: 4),
                                    FutureBuilder<Uint8List>(
                                      future: _secondImageFile!.readAsBytes(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return Image.memory(
                                            snapshot.data!,
                                            height: 100,
                                            fit: BoxFit.cover,
                                          );
                                        }
                                        return SizedBox(height: 100);
                                      },
                                    ),
                                  ] else if (_imageFile != null) ...[
                                    Text('Ảnh 2', style: TextStyle(fontSize: 12)),
                                    SizedBox(height: 4),
                                    Container(
                                      height: 100,
                                      color: Colors.grey[200],
                                      child: Center(
                                        child: Icon(Icons.camera_alt, color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                  if (widget.isTopicReport) ...[
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.camera_alt),
                            label: Text(_imageFile == null ? 'Chụp ảnh' : 'Chụp lại'),
                            onPressed: _captureImage,
                          ),
                        ),
                      ],
                    ),
                    if (_imageFile != null) ...[
                      SizedBox(height: 8),
                      FutureBuilder<Uint8List>(
                        future: _imageFile!.readAsBytes(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Image.memory(
                              snapshot.data!,
                              height: 100,
                              fit: BoxFit.cover,
                            );
                          }
                          return SizedBox(height: 100);
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 0, 204, 34),
                foregroundColor: Colors.white,
              ),
              onPressed: _isSubmitting ? null : _submitReport,
              child: _isSubmitting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text('Gửi'),
            ),
          ),
        ],
      ),
    ),
  );
}
}
class TopicReportDialog extends StatefulWidget {
  final String boPhan;
  final String username;

  const TopicReportDialog({
    required this.boPhan,
    required this.username,
  });

  @override
  _TopicReportDialogState createState() => _TopicReportDialogState();
}

class _TopicReportDialogState extends State<TopicReportDialog> {
  final TextEditingController _customTaskController = TextEditingController();
  
  final List<Map<String, String>> _predefinedTasks = [
    {'name': 'Vật tư', 'id': 'VatTu'},
    {'name': 'Máy móc', 'id': 'MayMoc'},
    {'name': 'Xe/Giỏ đồ', 'id': 'XeGioDo'},
    {'name': 'Ý kiến khách hàng', 'id': 'YKienKH'},
    {'name': 'Phát sinh', 'id': 'PhatSinh'},
    {'name': 'Nhân sự', 'id': 'NhanSu'},
  //  {'name': 'Chất lượng', 'id': 'ChatLuong'},
    {'name': 'Khác', 'id': 'Khac'},
  ];

  @override
  void dispose() {
    _customTaskController.dispose();
    super.dispose();
  }

  void _showTaskReportSheet(String? taskName, String? taskId, String? phanLoai) {
  String details = '';
  switch (taskName) {
    case 'Máy móc':
    details = '* Số CN sử dụng: \n* Diện tích sử dụng (m2): \n* Đã vệ sinh: \n* Thời gian sử dụng (phút): \n* Mô tả tình trạng: ';
    break;
    case 'Xe/Giỏ đồ':
    details = '* VT sử dụng:';
    break;
  }

  showDialog(
   context: context,
   builder: (BuildContext context) {
     return Dialog(
       insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
       child: TaskReportSheet(
         task: ChecklistModel(
           taskid: taskId ?? const Uuid().v4(),
           duan: widget.boPhan,
           vitri: 'GS',
           task: taskName ?? _customTaskController.text,
           start: '00:00',
           end: '23:59',
         ),
         vt: 'GS',
         boPhan: widget.boPhan,
         username: widget.username,
         phanLoai: phanLoai,
         isTopicReport: true,
         prefilledDetails: details,
       ),
     );
   },
 );
}

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Báo cáo theo chủ đề',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            // Custom task input card
            Card(
              margin: EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tạo báo cáo mới',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color.fromARGB(255, 0, 204, 34),
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _customTaskController,
                      decoration: InputDecoration(
                        labelText: 'Nội dung công việc',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 0, 204, 34),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          if (_customTaskController.text.isNotEmpty) {
                            _showTaskReportSheet(null, null, 'Khác');
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Vui lòng nhập nội dung'),
                              ),
                            );
                          }
                        },
                        child: Text('Tạo báo cáo'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              'Danh sách chủ đề:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _predefinedTasks.length,
                itemBuilder: (context, index) {
                  final task = _predefinedTasks[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(task['name']!),
                      onTap: () => _showTaskReportSheet(
                        task['name'],
                        task['id'],
                        task['name'],
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class StaffDetailDialog extends StatefulWidget {
  final Map<String, dynamic> staff;
  final String boPhan;
  final String username;

  const StaffDetailDialog({
    required this.staff,
    required this.boPhan,
    required this.username,
  });

  @override
  _StaffDetailDialogState createState() => _StaffDetailDialogState();
}

class _StaffDetailDialogState extends State<StaffDetailDialog> {
  String? _selectedVT;
  List<String> _availableVTs = [];
  Map<String, dynamic>? _staffbioData;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSavingBio = false;
  String? _positionListUid;
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  DateTime? _selectedDate;
  @override
  void initState() {
    super.initState();
    _selectedVT = widget.staff['VT'];
    _loadData();
  }
  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }
  Future<void> _refreshPositionList() async {
    try {
      // First, sync with server to get latest positions
      final response = await AuthenticatedHttpClient.get(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/position'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> positionData = json.decode(response.body);
        final dbHelper = DBHelper();
        
        // Clear existing position list data
        await dbHelper.clearTable(DatabaseTables.positionListTable);
        
        // Convert each item to a PositionListModel and insert
        final positionListModels = positionData.map((data) => 
          PositionListModel.fromMap(data as Map<String, dynamic>)
        ).toList();

        await dbHelper.batchInsertPositionList(positionListModels);
      }
    } catch (e) {
      print('Error refreshing position list: $e');
    }
  }
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DBHelper();
      
      final positionList = await dbHelper.query(
        DatabaseTables.positionListTable,
        where: 'BoPhan = ? AND NguoiDung = ?',
        whereArgs: [widget.boPhan, widget.username.toLowerCase()],
      );

      setState(() {
        _availableVTs = positionList
          .map((pos) => pos['VT'] as String?)
          .where((vt) => vt != null)
          .toSet()
          .toList()
          .cast<String>();
      });

      // Load Staffbio data
      final staffbioRecords = await dbHelper.query(
        DatabaseTables.staffbioTable,
        where: 'MaNV = ?',
        whereArgs: [widget.staff['MaNV']],
      );

      if (staffbioRecords.isNotEmpty) {
        setState(() {
          _staffbioData = staffbioRecords.first;
          // Initialize controllers with existing values
          _heightController.text = _staffbioData!['ChieuCao']?.toString() ?? '';
          _weightController.text = _staffbioData!['CanNang']?.toString() ?? '';
          _selectedDate = _staffbioData!['NgayCapDP'] != null ? 
            DateTime.parse(_staffbioData!['NgayCapDP']) : null;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải dữ liệu'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveBioChanges() async {
    if (_staffbioData == null) return;
    
    setState(() {
      _isSavingBio = true;
    });

    try {
      final height = double.tryParse(_heightController.text);
      final weight = double.tryParse(_weightController.text);
      
      final updateData = {
        'UID': _staffbioData!['UID'],
        if (height != null) 'ChieuCao': height,
        if (weight != null) 'CanNang': weight,
        if (_selectedDate != null) 'NgayCapDP': _selectedDate!.toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/updatebio'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updateData),
      );

      if (response.statusCode == 200) {
        // Update local database
        final dbHelper = DBHelper();
        await dbHelper.updateStaffbioEditableFields(
          _staffbioData!['UID'],
          chieuCao: height,
          canNang: weight,
          ngayCapDP: _selectedDate,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cập nhật thông tin thành công'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('Error saving bio changes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi cập nhật thông tin'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingBio = false;
        });
      }
    }
  }
Widget _buildEditableBioFields() {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cập nhật thông tin',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Chiều cao (cm)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Cân nặng (kg)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() {
                    _selectedDate = picked;
                  });
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Ngày cấp DP',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _selectedDate != null 
                    ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                    : 'Chọn ngày',
                ),
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 0, 204, 34),
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSavingBio ? null : _saveBioChanges,
                child: _isSavingBio
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text('Lưu thông tin'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _saveChanges() async {
    if (_selectedVT == widget.staff['VT']) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final dbHelper = DBHelper();
      
      // Update the staff list record
      await dbHelper.update(
        DatabaseTables.staffListTable,
        {'VT': _selectedVT},
        where: 'MaNV = ? AND BoPhan = ?',
        whereArgs: [widget.staff['MaNV'], widget.boPhan],
      );

      // Send update to server
      final updatedStaff = {
        'MaNV': widget.staff['MaNV'],
        'BoPhan': widget.boPhan,
        'VT': _selectedVT,
      };

      final response = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/stafflist/update'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updatedStaff),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.of(context).pop(true); // Return true to indicate update success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cập nhật vị trí thành công'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('Error saving changes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cập nhật vị trí: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildStaffbioInfo() {
    if (_staffbioData == null) return SizedBox.shrink();

    final dateFormat = DateFormat('dd/MM/yyyy');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 32),
        Text(
          'Thông tin nhân viên',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        // Main info
        _infoRow('Họ tên:', _staffbioData!['Ho_ten']),
        _infoRow('Mã NV:', _staffbioData!['MaNV']),
        _infoRow('Vùng miền:', _staffbioData!['VungMien']),
        _infoRow('Loại NV:', _staffbioData!['LoaiNV']),
        
        // Work info
        _infoRow('Chức vụ:', _staffbioData!['Chuc_vu']),
        if (_staffbioData!['Ngay_vao'] != null)
          _infoRow('Ngày vào:', dateFormat.format(DateTime.parse(_staffbioData!['Ngay_vao']))),
        if (_staffbioData!['Thang_vao'] != null)
          _infoRow('Tháng vào:', dateFormat.format(DateTime.parse(_staffbioData!['Thang_vao']))),
        _infoRow('Số tháng:', _staffbioData!['So_thang']?.toString()),
        _infoRow('Loại hình:', _staffbioData!['Loai_hinh_lao_dong']),
        
        // Personal info
        _infoRow('Giới tính:', _staffbioData!['Gioi_tinh']),
        if (_staffbioData!['Ngay_sinh'] != null)
          _infoRow('Ngày sinh:', dateFormat.format(DateTime.parse(_staffbioData!['Ngay_sinh']))),
        _infoRow('Tuổi:', _staffbioData!['Tuoi']?.toString()),
        
        // ID info
        _infoRow('CCCD:', _staffbioData!['Can_cuoc_cong_dan']),
        if (_staffbioData!['Ngay_cap'] != null)
          _infoRow('Ngày cấp:', dateFormat.format(DateTime.parse(_staffbioData!['Ngay_cap']))),
        _infoRow('Nơi cấp:', _staffbioData!['Noi_cap']),
        _infoRow('CMND cũ:', _staffbioData!['CMND_cu']),
        _infoRow('Ngày cấp cũ:', _staffbioData!['ngay_cap_cu']),
        _infoRow('Nơi cấp cũ:', _staffbioData!['Noi_cap_cu']),
        
        // Address info
        _infoRow('Nguyên quán:', _staffbioData!['Nguyen_quan']),
        _infoRow('Thường trú:', _staffbioData!['Thuong_tru']),
        _infoRow('Địa chỉ liên lạc:', _staffbioData!['Dia_chi_lien_lac']),
        _infoRow('Nguyên quán cũ:', _staffbioData!['Nguyen_quan_cu']),
        _infoRow('Địa chỉ thường trú cũ:', _staffbioData!['Dia_chi_thuong_tru_cu']),
        
        // Financial info
        _infoRow('Mã số thuế:', _staffbioData!['Ma_so_thue']),
        _infoRow('Ghi chú MST:', _staffbioData!['MST_ghi_chu']),
        _infoRow('Số tài khoản:', _staffbioData!['So_tai_khoan']),
        _infoRow('Ngân hàng:', _staffbioData!['Ngan_hang']),
        _infoRow('MST thu nhập cá nhân:', _staffbioData!['MST_thu_nhap_ca_nhan']),
        
        // Contact info
        _infoRow('Dân tộc:', _staffbioData!['Dan_toc']),
        _infoRow('SĐT:', _staffbioData!['SDT']),
        _infoRow('SĐT2:', _staffbioData!['SDT2']),
        _infoRow('Email:', _staffbioData!['Email']),
        
        // Administrative info
        _infoRow('Địa chính cấp 4:', _staffbioData!['Dia_chinh_cap4']),
        _infoRow('Địa chính cấp 3:', _staffbioData!['Dia_chinh_cap3']),
        _infoRow('Địa chính cấp 2:', _staffbioData!['Dia_chinh_cap2']),
        _infoRow('Địa chính cấp 1:', _staffbioData!['Dia_chinh_cap1']),
        _infoRow('Đơn vị:', _staffbioData!['Don_vi']),
        _infoRow('Giám sát:', _staffbioData!['Giam_sat']),
        
        // Insurance info
        _infoRow('Số BHXH:', _staffbioData!['So_BHXH']),
        _infoRow('Bắt đầu BHXH:', _staffbioData!['Bat_dau_tham_gia_BHXH']),
        _infoRow('Kết thúc BHXH:', _staffbioData!['Ket_thuc_BHXH']),
        _infoRow('Số thẻ BH hưu trí:', _staffbioData!['So_the_BH_huu_tri']),
        _infoRow('Số thẻ BHYT:', _staffbioData!['So_the_BHYT']),
        
        // Status info
        _infoRow('Ghi chú:', _staffbioData!['Ghi_chu']),
        _infoRow('Tình trạng:', _staffbioData!['Tinh_trang']),
        if (_staffbioData!['Ngay_nghi'] != null)
          _infoRow('Ngày nghỉ:', dateFormat.format(DateTime.parse(_staffbioData!['Ngay_nghi']))),
        _infoRow('Tình trạng hồ sơ:', _staffbioData!['Tinh_trang_ho_so']),
        _infoRow('Hồ sơ còn thiếu:', _staffbioData!['Ho_so_con_thieu']),
        _infoRow('Quá trình:', _staffbioData!['Qua_trinh']),
        
        // Additional info
        _infoRow('Partime:', _staffbioData!['Partime']),
        _infoRow('Người giới thiệu:', _staffbioData!['Nguoi_gioi_thieu']),
        _infoRow('Nguồn tuyển dụng:', _staffbioData!['Nguon_tuyen_dung']),
        _infoRow('CTV 30k:', _staffbioData!['CTV_30k']),
        _infoRow('Doanh số tuyển dụng:', _staffbioData!['Doanh_so_tuyen_dung']),
        _infoRow('Trình độ:', _staffbioData!['Trinh_do']),
        _infoRow('Chuyên ngành:', _staffbioData!['Chuyen_nganh']),
        _infoRow('PL đặc biệt:', _staffbioData!['PL_dac_biet']),
        _infoRow('Làm 2 nơi:', _staffbioData!['Lam_2noi']),
        _infoRow('Loại đt:', _staffbioData!['Loai_dt']),
        
        // Health info
        _infoRow('Tình trạng tiêm chủng:', _staffbioData!['Tinh_trang_tiem_chung']),
        if (_staffbioData!['Ngay_cap_giay_khamSK'] != null)
          _infoRow('Ngày cấp giấy khám SK:', dateFormat.format(DateTime.parse(_staffbioData!['Ngay_cap_giay_khamSK']))),
        
        // Family info
        _infoRow('SĐT nhân thân:', _staffbioData!['SDT_nhan_than']),
        _infoRow('Họ tên bố:', _staffbioData!['Ho_ten_bo']),
        _infoRow('Năm sinh bố:', _staffbioData!['Nam_sinh_bo']),
        _infoRow('Họ tên mẹ:', _staffbioData!['Ho_ten_me']),
        _infoRow('Năm sinh mẹ:', _staffbioData!['Nam_sinh_me']),
        _infoRow('Họ tên vợ/chồng:', _staffbioData!['Ho_ten_vochong']),
        _infoRow('Năm sinh vợ/chồng:', _staffbioData!['Nam_sinh_vochong']),
        _infoRow('Con:', _staffbioData!['Con']),
        _infoRow('Năm sinh con:', _staffbioData!['Nam_sinh_con']),
        _infoRow('Chủ hộ khẩu:', _staffbioData!['Chu_ho_khau']),
        _infoRow('Năm sinh chủ hộ:', _staffbioData!['Nam_sinh_chu_ho']),
        _infoRow('Quan hệ với chủ hộ:', _staffbioData!['Quan_he_voi_chu_ho']),
        _infoRow('Hồ sơ thẩu:', _staffbioData!['Ho_so_thau']),
      ],
    );
  }

  Widget _infoRow(String label, dynamic value) {
  if (value == null || value.toString().isEmpty) return SizedBox.shrink();
  return Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: EdgeInsets.all(16),
        child: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color.fromARGB(255, 0, 204, 34),
                ),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thay đổi vị trí',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedVT,
                    decoration: InputDecoration(
                      labelText: 'Vị trí',
                      border: OutlineInputBorder(),
                    ),
                    items: _availableVTs.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedVT = newValue;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 0, 204, 34),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _selectedVT != widget.staff['VT'] && !_isSaving
                        ? _saveChanges
                        : null,
                      child: _isSaving
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text('Lưu vị trí'),
                    ),
                  ),
                  _buildEditableBioFields(),
                  _buildStaffbioInfo(),
                ],
              ),
            ),
      ),
    );
  }
}