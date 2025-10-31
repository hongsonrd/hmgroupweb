import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChecklistCountModel {
  final String projectName;
  final int checklistCount;

  ChecklistCountModel({required this.projectName, required this.checklistCount});

  factory ChecklistCountModel.fromJson(Map<String, dynamic> json) {
    return ChecklistCountModel(
      projectName: json['projectName'] ?? '',
      checklistCount: json['checklistCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'projectName': projectName,
    'checklistCount': checklistCount,
  };
}

class KPIDebugInfo {
  final String nguoiDung;
  final String date;
  final Map<String, dynamic> calculations;

  KPIDebugInfo({
    required this.nguoiDung,
    required this.date,
    required this.calculations,
  });

  Map<String, dynamic> toJson() => {
    'nguoiDung': nguoiDung,
    'date': date,
    'calculations': calculations,
  };

  factory KPIDebugInfo.fromJson(Map<String, dynamic> json) => KPIDebugInfo(
    nguoiDung: json['nguoiDung'],
    date: json['date'],
    calculations: json['calculations'],
  );
}

class ExtendedKPIStatsModel {
  final String nguoiDung;
  final String date;
  final String mainProject;
  final double bienDongNhanSu;
  final double robotControl;
  final double qrManagement;
  final double machineManagement;
  final double checklistManagement;
  
  double get totalPoints => bienDongNhanSu + robotControl + qrManagement + machineManagement + checklistManagement;
  double get totalPercent => (totalPoints / 25.0) * 100;

  ExtendedKPIStatsModel({
    required this.nguoiDung,
    required this.date,
    required this.mainProject,
    required this.bienDongNhanSu,
    required this.robotControl,
    required this.qrManagement,
    required this.machineManagement,
    required this.checklistManagement,
  });

  Map<String, dynamic> toJson() => {
    'nguoiDung': nguoiDung,
    'date': date,
    'mainProject': mainProject,
    'bienDongNhanSu': bienDongNhanSu,
    'robotControl': robotControl,
    'qrManagement': qrManagement,
    'machineManagement': machineManagement,
    'checklistManagement': checklistManagement,
  };

  factory ExtendedKPIStatsModel.fromJson(Map<String, dynamic> json) => ExtendedKPIStatsModel(
    nguoiDung: json['nguoiDung'],
    date: json['date'],
    mainProject: json['mainProject'],
    bienDongNhanSu: (json['bienDongNhanSu'] as num).toDouble(),
    robotControl: (json['robotControl'] as num).toDouble(),
    qrManagement: (json['qrManagement'] as num).toDouble(),
    machineManagement: (json['machineManagement'] as num).toDouble(),
    checklistManagement: (json['checklistManagement'] as num).toDouble(),
  );
}

class ExtendedKPICalculator {
  final List<dynamic> dailyReports;
  final List<dynamic> kpiPlanData;
  final Map<String, ChecklistCountModel> checklistData;

  ExtendedKPICalculator({
    required this.dailyReports,
    required this.kpiPlanData,
    required this.checklistData,
  });

  Map<String, dynamic> calculateQRManagement(String nguoiDung, String project) {
    final workerReports = dailyReports.where((r) => 
      !r.nguoiDung.toString().toLowerCase().startsWith('hm') &&
      r.boPhan == project &&
      (r.phanLoai == 'Kiểm tra chất lượng' || r.phanLoai == 'Vào vị trí')
    ).toList();

    final uniqueViTri = <String>{};
    for (final record in workerReports) {
      final viTri = record.viTri?.toString().trim() ?? '';
      if (viTri.isNotEmpty) {
        uniqueViTri.add(viTri);
      }
    }

    final actualCount = uniqueViTri.length;
    final plan = _getPlanValue(project, 'QR');
    
    if (plan == 0) {
      return {
        'points': 5.0,
        'actualCount': actualCount,
        'planValue': plan,
        'percentage': 100.0,
        'autoFull': true,
      };
    }

    final percentage = (actualCount / plan) * 100;
    double points = 0.0;
    
    if (percentage >= 100) {
      points = 5.0;
    } else if (percentage >= 50) {
      points = 2.5 + ((percentage - 50) / 50) * 2.5;
    }

    return {
      'points': points,
      'actualCount': actualCount,
      'planValue': plan,
      'percentage': percentage,
      'autoFull': false,
      'uniqueViTri': uniqueViTri.toList(),
    };
  }

  Map<String, dynamic> calculateMachineManagement(String nguoiDung, String project) {
    final workerReports = dailyReports.where((r) => 
      !r.nguoiDung.toString().toLowerCase().startsWith('hm') &&
      r.boPhan == project &&
      r.phanLoai == 'Máy móc'
    ).toList();

    final uniqueViTri = <String>{};
    for (final record in workerReports) {
      final viTri = record.viTri?.toString().trim() ?? '';
      if (viTri.isNotEmpty) {
        uniqueViTri.add(viTri);
      }
    }

    final actualCount = uniqueViTri.length;
    final plan = _getPlanValue(project, 'Máy móc');
    
    if (plan == 0) {
      return {
        'points': 5.0,
        'actualCount': actualCount,
        'planValue': plan,
        'percentage': 100.0,
        'autoFull': true,
      };
    }

    final percentage = (actualCount / plan) * 100;
    double points = 0.0;
    
    if (percentage >= 100) {
      points = 5.0;
    } else if (percentage >= 50) {
      points = 2.5 + ((percentage - 50) / 50) * 2.5;
    }

    return {
      'points': points,
      'actualCount': actualCount,
      'planValue': plan,
      'percentage': percentage,
      'autoFull': false,
      'uniqueViTri': uniqueViTri.toList(),
    };
  }

  Map<String, dynamic> calculateChecklistManagement(String nguoiDung, String project) {
    final checklistModel = checklistData[project];
    final actualCount = checklistModel?.checklistCount ?? 0;
    final plan = _getPlanValue(project, 'Checklist');
    
    if (plan == 0) {
      return {
        'points': 5.0,
        'actualCount': actualCount,
        'planValue': plan,
        'percentage': 100.0,
        'autoFull': true,
      };
    }

    final percentage = (actualCount / plan) * 100;
    double points = 0.0;
    
    if (percentage >= 100) {
      points = 5.0;
    } else if (percentage >= 50) {
      points = 2.5 + ((percentage - 50) / 50) * 2.5;
    }

    return {
      'points': points,
      'actualCount': actualCount,
      'planValue': plan,
      'percentage': percentage,
      'autoFull': false,
    };
  }

  double _getPlanValue(String project, String phanLoai) {
    try {
      final plan = kpiPlanData.firstWhere(
        (p) => p.boPhan == project && p.phanLoai == phanLoai,
        orElse: () => kpiPlanData.firstWhere(
          (p) => p.boPhan == 'Mặc định' && p.phanLoai == phanLoai,
          orElse: () => null,
        ),
      );
      return plan?.giaTri?.toDouble() ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }
}

class ExtendedKPICalculationDialog extends StatefulWidget {
  final List<dynamic> attendanceList;
  final String selectedDate;
  final List<dynamic> dailyReports;
  final List<dynamic> kpiPlanData;
  final String baseUrl;
  final Function(List<ExtendedKPIStatsModel>, Map<String, KPIDebugInfo>) onStatsCalculated;

  const ExtendedKPICalculationDialog({
    Key? key,
    required this.attendanceList,
    required this.selectedDate,
    required this.dailyReports,
    required this.kpiPlanData,
    required this.baseUrl,
    required this.onStatsCalculated,
  }) : super(key: key);

  @override
  _ExtendedKPICalculationDialogState createState() => _ExtendedKPICalculationDialogState();
}

class _ExtendedKPICalculationDialogState extends State<ExtendedKPICalculationDialog> {
  int _currentIndex = 0;
  String _currentStatus = 'Đang khởi động...';
  final List<ExtendedKPIStatsModel> _calculatedStats = [];
  final Map<String, KPIDebugInfo> _debugInfo = {};
  Map<String, ChecklistCountModel> _checklistData = {};

  @override
  void initState() {
    super.initState();
    _startCalculation();
  }

  Future<void> _startCalculation() async {
    setState(() => _currentStatus = 'Đang đồng bộ checklist...');
    await _syncChecklistData();
    await Future.delayed(Duration(milliseconds: 300));

    final calculator = ExtendedKPICalculator(
      dailyReports: widget.dailyReports,
      kpiPlanData: widget.kpiPlanData,
      checklistData: _checklistData,
    );

    for (int i = 0; i < widget.attendanceList.length; i++) {
      final item = widget.attendanceList[i];
      
      setState(() {
        _currentIndex = i;
        _currentStatus = 'Đang tính toán cho ${item.attendance.nguoiDung}...';
      });

      await Future.delayed(Duration(milliseconds: 100));

      final bienDongDebug = _calculateBienDongNhanSu(item.attendance.nguoiDung, item.mainProject);
      await Future.delayed(Duration(milliseconds: 50));

      final robotDebug = _calculateRobotControl(item.attendance.nguoiDung, item.mainProject);
      await Future.delayed(Duration(milliseconds: 50));

      final qrDebug = calculator.calculateQRManagement(item.attendance.nguoiDung, item.mainProject);
      await Future.delayed(Duration(milliseconds: 50));

      final machineDebug = calculator.calculateMachineManagement(item.attendance.nguoiDung, item.mainProject);
      await Future.delayed(Duration(milliseconds: 50));

      final checklistDebug = calculator.calculateChecklistManagement(item.attendance.nguoiDung, item.mainProject);
      await Future.delayed(Duration(milliseconds: 50));

      _calculatedStats.add(ExtendedKPIStatsModel(
        nguoiDung: item.attendance.nguoiDung,
        date: widget.selectedDate,
        mainProject: item.mainProject,
        bienDongNhanSu: bienDongDebug['points'],
        robotControl: robotDebug['points'],
        qrManagement: qrDebug['points'],
        machineManagement: machineDebug['points'],
        checklistManagement: checklistDebug['points'],
      ));

      _debugInfo['${item.attendance.nguoiDung}_${widget.selectedDate}'] = KPIDebugInfo(
        nguoiDung: item.attendance.nguoiDung,
        date: widget.selectedDate,
        calculations: {
          'mainProject': item.mainProject,
          'bienDongNhanSu': bienDongDebug,
          'robotControl': robotDebug,
          'qrManagement': qrDebug,
          'machineManagement': machineDebug,
          'checklistManagement': checklistDebug,
        },
      );
    }

    widget.onStatsCalculated(_calculatedStats, _debugInfo);
    Navigator.of(context).pop();
  }

  Future<void> _syncChecklistData() async {
    try {
      final dateFormatted = DateFormat('yyyyMMdd').format(DateTime.parse(widget.selectedDate));
      final response = await http.get(Uri.parse('${widget.baseUrl}/gschecklisttheongay/$dateFormatted'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _checklistData = {
            for (var item in data)
              item['projectName']: ChecklistCountModel.fromJson(item)
          };
        });
      }
    } catch (e) {
      print('Error syncing checklist: $e');
    }
  }

  Map<String, dynamic> _calculateBienDongNhanSu(String nguoiDung, String project) {
    String? latestTime;
    final matchedRecords = <Map<String, dynamic>>[];
    
    final supervisorReports = widget.dailyReports.where((r) => 
      r.nguoiDung.toString().toLowerCase().startsWith('hm')
    ).toList();
    
    for (final record in supervisorReports) {
      if (record.nguoiDung == nguoiDung &&
          record.boPhan == project &&
          record.phanLoai == 'Nhân sự' &&
          record.chiTiet.toString().length >= 2) {
        final time = record.gio?.toString() ?? '';
        if (time.isNotEmpty) {
          matchedRecords.add({'time': time, 'detail': record.chiTiet});
          if (latestTime == null || time.compareTo(latestTime) > 0) {
            latestTime = time;
          }
        }
      }
    }

    if (latestTime == null) {
      return {
        'points': 0.0,
        'latestTime': null,
        'matchedRecords': matchedRecords,
        'reason': 'Không có báo cáo nhân sự',
      };
    }

    final timeParts = latestTime.split(':');
    if (timeParts.isEmpty) {
      return {
        'points': 0.0,
        'latestTime': latestTime,
        'matchedRecords': matchedRecords,
        'reason': 'Định dạng giờ không hợp lệ',
      };
    }

    final hour = int.tryParse(timeParts[0]) ?? 0;
    final points = hour < 9 ? 5.0 : 3.0;

    return {
      'points': points,
      'latestTime': latestTime,
      'hour': hour,
      'matchedRecords': matchedRecords,
      'reason': hour < 9 ? 'Báo cáo trước 9h' : 'Báo cáo sau 9h',
    };
  }

  Map<String, dynamic> _calculateRobotControl(String nguoiDung, String project) {
    final plan = _getPlanValue(project, 'Robot');
    
    if (plan == 0) {
      return {
        'points': 5.0,
        'totalArea': 0.0,
        'planValue': 0.0,
        'percentage': 100.0,
        'autoFull': true,
        'matchedRecords': [],
      };
    }

    double totalArea = 0.0;
    final matchedRecords = <Map<String, dynamic>>[];
    
    final supervisorReports = widget.dailyReports.where((r) => 
      r.nguoiDung.toString().toLowerCase().startsWith('hm')
    ).toList();
    
    for (final record in supervisorReports) {
      if (record.nguoiDung == nguoiDung &&
          record.boPhan == project &&
          record.phanLoai == 'Robot' &&
          record.chiTiet.toString().isNotEmpty) {
        final regex = RegExp(r'Diện tích sử dụng \(m2\):\s*([\d.]+)');
        final match = regex.firstMatch(record.chiTiet);
        
        if (match != null) {
          final areaStr = match.group(1);
          final area = double.tryParse(areaStr ?? '0') ?? 0.0;
          final rounded = area.roundToDouble();
          totalArea += rounded;
          matchedRecords.add({
            'time': record.gio,
            'area': rounded,
            'detail': record.chiTiet,
          });
        }
      }
    }

    final percentage = (totalArea / plan) * 100;
    double points = 0.0;
    
    if (percentage >= 95) {
      points = 5.0;
    } else if (percentage >= 50) {
      points = 2.5 + ((percentage - 50) / 45) * 2.5;
    }

    return {
      'points': points,
      'totalArea': totalArea,
      'planValue': plan,
      'percentage': percentage,
      'autoFull': false,
      'matchedRecords': matchedRecords,
    };
  }

  double _getPlanValue(String project, String phanLoai) {
    try {
      final plan = widget.kpiPlanData.firstWhere(
        (p) => p.boPhan == project && p.phanLoai == phanLoai,
        orElse: () => widget.kpiPlanData.firstWhere(
          (p) => p.boPhan == 'Mặc định' && p.phanLoai == phanLoai,
          orElse: () => null,
        ),
      );
      return plan?.giaTri?.toDouble() ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.attendanceList.isEmpty ? 0.0 : (_currentIndex + 1) / widget.attendanceList.length;
    
    return Dialog(
      child: Container(
        width: 400,
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Đang tính toán KPI', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 24),
            CircularProgressIndicator(value: progress, strokeWidth: 6),
            SizedBox(height: 16),
            Text('${(_currentIndex + 1)}/${widget.attendanceList.length}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(_currentStatus, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            SizedBox(height: 16),
            LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }
}

class KPIDebugDialog extends StatelessWidget {
  final KPIDebugInfo debugInfo;

  const KPIDebugDialog({Key? key, required this.debugInfo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final calcs = debugInfo.calculations;
    
    return Dialog(
      child: Container(
        width: 800,
        height: 700,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.blue[600],
              child: Row(
                children: [
                  Icon(Icons.bug_report, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chi tiết tính điểm - ${debugInfo.nguoiDung} - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(debugInfo.date))}',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection('Dự án chính', calcs['mainProject'], null),
                    Divider(height: 32),
                    _buildStatSection('1. Biến động nhân sự', calcs['bienDongNhanSu']),
                    Divider(height: 32),
                    _buildStatSection('2. Quản lý Robot', calcs['robotControl']),
                    Divider(height: 32),
                    _buildStatSection('3. Quản lý QR', calcs['qrManagement']),
                    Divider(height: 32),
                    _buildStatSection('4. Quản lý máy móc', calcs['machineManagement']),
                    Divider(height: 32),
                    _buildStatSection('5. Quản lý Checklist', calcs['checklistManagement']),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, dynamic value, Color? color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700])),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color ?? Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(value.toString(), style: TextStyle(fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildStatSection(String title, Map<String, dynamic> data) {
    final points = data['points'] ?? 0.0;
    final color = points >= 4.5 ? Colors.green : points >= 2.5 ? Colors.orange : Colors.red;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: color[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${points.toStringAsFixed(2)} điểm',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color[800]),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        if (data['autoFull'] == true)
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tự động đủ điểm (Plan = 0)',
                    style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data['actualCount'] != null && data['planValue'] != null) ...[
                  Row(
                    children: [
                      Expanded(child: Text('Thực tế:', style: TextStyle(fontWeight: FontWeight.w500))),
                      Text('${data['actualCount']}', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: Text('Kế hoạch:', style: TextStyle(fontWeight: FontWeight.w500))),
                      Text('${data['planValue']}', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: Text('Tỷ lệ:', style: TextStyle(fontWeight: FontWeight.w500))),
                      Text('${data['percentage'].toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                    ],
                  ),
                ],
                if (data['totalArea'] != null) ...[
                  Row(
                    children: [
                      Expanded(child: Text('Tổng diện tích:', style: TextStyle(fontWeight: FontWeight.w500))),
                      Text('${data['totalArea'].toStringAsFixed(0)} m²', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
                if (data['latestTime'] != null) ...[
                  Row(
                    children: [
                      Expanded(child: Text('Giờ báo cáo:', style: TextStyle(fontWeight: FontWeight.w500))),
                      Text('${data['latestTime']}', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
                if (data['reason'] != null) ...[
                  SizedBox(height: 4),
                  Text('Lý do: ${data['reason']}', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600])),
                ],
              ],
            ),
          ),
        if (data['matchedRecords'] != null && (data['matchedRecords'] as List).isNotEmpty) ...[
          SizedBox(height: 8),
          Text('Chi tiết báo cáo:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          SizedBox(height: 4),
          ...((data['matchedRecords'] as List).map((record) => Container(
            margin: EdgeInsets.only(bottom: 4),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (record['time'] != null)
                  Text('⏰ ${record['time']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                if (record['area'] != null)
                  Text('📏 ${record['area']} m²', style: TextStyle(fontSize: 12)),
                if (record['detail'] != null)
                  Text('${record['detail']}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ))),
        ],
        if (data['uniqueViTri'] != null && (data['uniqueViTri'] as List).isNotEmpty) ...[
          SizedBox(height: 8),
          Text('Vị trí duy nhất (${(data['uniqueViTri'] as List).length}):', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: (data['uniqueViTri'] as List).map((viTri) => Chip(
              label: Text(viTri, style: TextStyle(fontSize: 11)),
              backgroundColor: Colors.blue[100],
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )).toList(),
          ),
        ],
      ],
    );
  }
}