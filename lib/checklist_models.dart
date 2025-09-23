//checklist_models.dart
class ChecklistListModel {
  final String checklistId;
  final String? userId;
  final String date;
  final String time;
  final int? versionNumber;
  final String? projectName;
  final String? areaName;
  final String? floorName;
  final String? checklistTitle;
  final String? checklistPretext;
  final String? checklistSubtext;
  final String? logoMain;
  final String? logoSecondary;
  final String? checklistTaskList;
  final String? checklistDateType;
  final String? checklistTimeType;
  final String? checklistPeriodicStart;
  final String? checklistPeriodicEnd;
  final int? checklistPeriodInterval;
  final String? checklistCompletionType;
  final String? checklistNoteEnabled;
  final String? cloudUrl;

  ChecklistListModel({
    required this.checklistId,
    this.userId,
    required this.date,
    required this.time,
    this.versionNumber,
    this.projectName,
    this.areaName,
    this.floorName,
    this.checklistTitle,
    this.checklistPretext,
    this.checklistSubtext,
    this.logoMain,
    this.logoSecondary,
    this.checklistTaskList,
    this.checklistDateType,
    this.checklistTimeType,
    this.checklistPeriodicStart,
    this.checklistPeriodicEnd,
    this.checklistPeriodInterval,
    this.checklistCompletionType,
    this.checklistNoteEnabled,
    this.cloudUrl,
  });

  Map<String, dynamic> toMap() => {
    'checklistId': checklistId,
    'userId': userId,
    'date': date,
    'time': time,
    'versionNumber': versionNumber,
    'projectName': projectName,
    'areaName': areaName,
    'floorName': floorName,
    'checklistTitle': checklistTitle,
    'checklistPretext': checklistPretext,
    'checklistSubtext': checklistSubtext,
    'logoMain': logoMain,
    'logoSecondary': logoSecondary,
    'checklistTaskList': checklistTaskList,
    'checklistDateType': checklistDateType,
    'checklistTimeType': checklistTimeType,
    'checklistPeriodicStart': checklistPeriodicStart,
    'checklistPeriodicEnd': checklistPeriodicEnd,
    'checklistPeriodInterval': checklistPeriodInterval,
    'checklistCompletionType': checklistCompletionType,
    'checklistNoteEnabled': checklistNoteEnabled,
    'cloudUrl': cloudUrl,
  };

  factory ChecklistListModel.fromMap(Map<String, dynamic> m) => ChecklistListModel(
    checklistId: m['checklistId'] ?? '',
    userId: m['userId'],
    date: m['date'] ?? '',
    time: m['time'] ?? '',
    versionNumber: m['versionNumber'],
    projectName: m['projectName'],
    areaName: m['areaName'],
    floorName: m['floorName'],
    checklistTitle: m['checklistTitle'],
    checklistPretext: m['checklistPretext'],
    checklistSubtext: m['checklistSubtext'],
    logoMain: m['logoMain'],
    logoSecondary: m['logoSecondary'],
    checklistTaskList: m['checklistTaskList'],
    checklistDateType: m['checklistDateType'],
    checklistTimeType: m['checklistTimeType'],
    checklistPeriodicStart: m['checklistPeriodicStart'],
    checklistPeriodicEnd: m['checklistPeriodicEnd'],
    checklistPeriodInterval: m['checklistPeriodInterval'],
    checklistCompletionType: m['checklistCompletionType'],
    checklistNoteEnabled: m['checklistNoteEnabled'],
    cloudUrl: m['cloudUrl'],
  );
}

class ChecklistItemModel {
  final String itemId;
  final String? itemName;
  final String? itemImage;
  final String? itemIcon;

  ChecklistItemModel({
    required this.itemId,
    this.itemName,
    this.itemImage,
    this.itemIcon,
  });

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'itemName': itemName,
    'itemImage': itemImage,
    'itemIcon': itemIcon,
  };

  factory ChecklistItemModel.fromMap(Map<String, dynamic> m) => ChecklistItemModel(
    itemId: m['itemId'] ?? '',
    itemName: m['itemName'],
    itemImage: m['itemImage'],
    itemIcon: m['itemIcon'],
  );
}

class ChecklistReportModel {
  final String reportId;
  final String? checklistId;
  final String? projectName;
  final String? reportType;
  final String reportDate;
  final String reportTime;
  final String? userId;
  final String? reportTaskList;
  final String? reportNote;
  final String? reportImage;
  final String? reportInOut;

  ChecklistReportModel({
    required this.reportId,
    this.checklistId,
    this.projectName,
    this.reportType,
    required this.reportDate,
    required this.reportTime,
    this.userId,
    this.reportTaskList,
    this.reportNote,
    this.reportImage,
    this.reportInOut,
  });

  Map<String, dynamic> toMap() => {
    'reportId': reportId,
    'checklistId': checklistId,
    'projectName': projectName,
    'reportType': reportType,
    'reportDate': reportDate,
    'reportTime': reportTime,
    'userId': userId,
    'reportTaskList': reportTaskList,
    'reportNote': reportNote,
    'reportImage': reportImage,
    'reportInOut': reportInOut,
  };

  factory ChecklistReportModel.fromMap(Map<String, dynamic> m) => ChecklistReportModel(
    reportId: m['reportId'] ?? '',
    checklistId: m['checklistId'],
    projectName: m['projectName'],
    reportType: m['reportType'],
    reportDate: m['reportDate'] ?? '',
    reportTime: m['reportTime'] ?? '',
    userId: m['userId'],
    reportTaskList: m['reportTaskList'],
    reportNote: m['reportNote'],
    reportImage: m['reportImage'],
    reportInOut: m['reportInOut'],
  );
}

extension IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}