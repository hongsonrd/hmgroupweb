library hmgroupweb.chat_ai_case;

import 'package:http/http.dart' as http;
import 'dart:convert';

class CaseFileData {
  final String content;
  final String fileType;
  final bool isPdf;
  
  CaseFileData({
    required this.content,
    required this.fileType,
    required this.isPdf,
  });
}

class CaseFileConfig {
  final String caseType;
  final String urlPrefix;
  final String periodType;
  final String customPrompt;
  
  CaseFileConfig({
    required this.caseType,
    required this.urlPrefix,
    required this.periodType,
    required this.customPrompt,
  });
}

class CaseFileManager {
  static final Map<String, CaseFileConfig> _caseConfigs = {
    'TEST 1: Báo cáo sân bay Nội Bài theo ngày': CaseFileConfig(
      caseType: 'financial',
      urlPrefix: 'https://yourworldtravel.vn/api/document/noibaingay',
      periodType: 'daily',
      customPrompt: 'Phân tích báo cáo với vai trò quản lý chất lượng dịch vụ,làm rõ điểm tốt,chưa tốt,vấn đề,đề xuất phương án xử lý,theo dõi dựa trên bảng báo cáo & kế hoạch công việc.Đặc thù làm việc tại đây 24/24,nhân viên vệ sinh ca từ 9g sáng hôm nay tới 9g sáng hôm sau,giám sát từ 7:30 sáng hôm nay tới 7:30 sáng hôm sau,văn phòng trụ sở& kỹ thuật robot từ 8g-17g,phạm vi được chia ra bởi kiểm soát an nình gọi là khu vực Cách ly (CL) nghĩa là khu vực sau kiểm tra an ninh,Công cộng (CC) là khu vực ngoài kiểm tra an ninh.Khu vực nhà ga gồm 4 toà:A,B,C,E.A&B là 2 cánh đều có thang máy nối với nhau thông qua C khối trung tâm thang máy/thang cuốn.Toà E là cánh mới, nối với B thông qua cầu đi bộ,có thang máy riêng)',
    ),
    'TEST 2: Báo cáo sân bay Nội Bài theo ngày': CaseFileConfig(
      caseType: 'financial',
      urlPrefix: 'https://yourworldtravel.vn/drive/noibaingay',
      periodType: 'daily',
      customPrompt: 'Phân tích báo cáo với vai trò quản lý chất lượng dịch vụ,làm rõ điểm tốt,chưa tốt,vấn đề,đề xuất phương án xử lý,theo dõi.Đặc thù làm việc tại đây 24/24,nhân viên vệ sinh ca từ 9g sáng hôm nay tới 9g sáng hôm sau,giám sát từ 7:30 sáng hôm nay tới 7:30 sáng hôm sau,văn phòng trụ sở& kỹ thuật robot từ 8g-17g,phạm vi được chia ra bởi kiểm soát an nình gọi là khu vực Cách ly (CL) nghĩa là khu vực sau kiểm tra an ninh,Công cộng (CC) là khu vực ngoài kiểm tra an ninh.Khu vực nhà ga gồm 4 toà:A,B,C,E.A&B là 2 cánh đều có thang máy nối với nhau thông qua C khối trung tâm thang máy/thang cuốn.Toà E là cánh mới, nối với B thông qua cầu đi bộ,có thang máy riêng)',
    ),
  };

  static List<String> getCaseTypes() {
    return _caseConfigs.keys.toList();
  }

  static String buildFileUrl(String caseType, DateTime date) {
    final config = _caseConfigs[caseType];
    if (config == null) return '';
    
    final String dateStr = config.periodType == 'monthly'
        ? 'THANG${date.month.toString().padLeft(2, '0')}${date.year}'
        : '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    
    return '${config.urlPrefix}$dateStr';
  }

  static Future<CaseFileData?> fetchCaseFile(String caseType, DateTime date) async {
    final baseUrl = buildFileUrl(caseType, date);
    
    for (final ext in ['.pdf', '.txt']) {
      try {
        final url = '$baseUrl$ext';
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          if (ext == '.txt') {
            return CaseFileData(
              content: response.body,
              fileType: 'txt',
              isPdf: false,
            );
          } else {
            return CaseFileData(
              content: base64Encode(response.bodyBytes),
              fileType: 'pdf',
              isPdf: true,
            );
          }
        }
      } catch (e) {
        continue;
      }
    }
    return null;
  }
  
  static String getPeriodType(String caseType) {
    return _caseConfigs[caseType]?.periodType ?? 'daily';
  }
  
  static String getCustomPrompt(String caseType) {
    return _caseConfigs[caseType]?.customPrompt ?? '';
  }
}