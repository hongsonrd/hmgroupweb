import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'chat_ai_case.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'chat_ai_custom.dart';
import 'chat_ai_convert.dart';
import 'package:http_parser/http_parser.dart';

enum AvatarState { hello, thinking, speaking, congrat, listening, idle }

class ChatAIScreen extends StatefulWidget {
  const ChatAIScreen({Key? key}) : super(key: key);
  @override
  State<ChatAIScreen> createState() => _ChatAIScreenState();
}
class _ChatAIScreenState extends State<ChatAIScreen> with SingleTickerProviderStateMixin {
  static const String _ttsLanguage = 'vi-VN';
  static const double _ttsDefaultRate = 0.6;
  static const double _ttsDefaultPitch = 0.86;
  static const int _ttsMaxDurationSeconds = 30;
  List<AIProfessional> _customProfessionals = [];
String? _selectedProfessionalId;
  String _username = '';
  final String _apiBaseUrl = 'https://hmbeacon-81200125587.asia-east2.run.app';
  List<ChatSession> _sessions = [];
  ChatSession? _currentSession;
  List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final ScrollController _sessionScrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isStreaming = false;
  String _currentStreamingMessage = '';
  String? _currentStreamingImage;
  String? _currentStreamingVideo;
  String _selectedModel = '';
  String _mode = 'text';
  String? _hoveredMessageId;
  bool _sidebarVisible = true;
  String _imageRatio = '1:1';
  CreditBalance? _creditBalance;
  bool _isLoadingCredit = false;
  String _lastEnteredText = ''; 
  String _userAvatarEmoji = '';
  late AnimationController _gradientController;
  late Animation<double> _gradientAnimation;
  
  String? _selectedCaseType;
  DateTime _selectedCaseDate = DateTime.now();
  CaseFileData? _caseFileData;
  bool _isCaseFileLoading = false;
  
  AvatarState _avatarState = AvatarState.hello;
  Timer? _congratTimer;
  Timer? _speakingEndTimer;
  
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  double _ttsVolume = 0.9;
    List<File> _selectedFiles = [];
  static const int _maxFiles = 10;
  final Map<AvatarState, List<String>> _avatarVideos = {
    AvatarState.hello: ['hello.mp4','hello-smile.mp4'],
    AvatarState.thinking: ['thinking.mp4','thinking-deep.mp4','thinking-focus.mp4'],
    AvatarState.speaking: ['speaking.mp4'],
    AvatarState.congrat: ['congrat.mp4','congrat-jump.mp4','congrat-hand.mp4'],
    AvatarState.listening: ['listening.mp4','listening-smile.mp4'],
    AvatarState.idle: ['idle.mp4','idle-turn.mp4','idle-smile.mp4'],
  };
  
  final Map<String, List<Map<String, dynamic>>> _models = {
  'fast': [
      {'value': 'qwen3-80b', 'name': '🇨🇳Bạch tuộc', 'cost': 48, 'rating': 4, 'systemPrompt': 'Ưu tiên tiếng việt,gọi người dùng là quý anh/chị,Không dùng ngữ cảnh nâng cao hay nói liên quan về vệ sinh công nghiệp nếu người dùng không hỏi,không để lộ ngữ cảnh/chuyên môn cài đặt trực tiếp trong trả lời,dùng bảng cho so sánh chỉ khi cần thiết,có thể dùng emoji để trang trí phù hợp.Bạn là chuyên gia đến từ Hoàn Mỹ Group chuyên làm sạch toà nhà văn phòng,chung cư,nhà máy,bệnh viện,bến xe,sân bay.Bạn có chuyên môn đủ các ngành nghề.Nếu câu hỏi về chủ đề vệ sinh thì mới dùng thêm ngữ cảnh nâng cao. Ngữ cảnh nâng cao bạn là chuyên gia ngành vệ sinh công nghiệp có ứng dụng robot, AI,công nghệ trong dịch vụ,quản lý tập đoàn,chất lượng,hiệu quả,kinh nghiệm hàng đầu tại Việt Nam.Khi đánh giá,sử dụng thang điểm /10 để đảm bảo tính dễ hiểu,trực quan.Đưa ra các lựa chọn,giải quyết nếu hiện trạng chưa đạt tối ưu,chú ý đến mức độ cơ sở vật chất hiện có thường sẽ cũ hơn trên ảnh.Đảm bảo trả lời:Đánh giá,Lỗi,Khắc phục bằng hoá chất/máy móc/phương pháp/công cụ,Cảnh báo nếu là về vấn đề vệ sinh,sau khi trả lời gợi ý các lựa chọn chủ đề, câu hỏi người dùng có thể nghỉ tới.Sau đây là câu hỏi của người dùng:'},
      {'value': 'claude-haiku-4-5', 'name': '🇮🇱Tôm càng xanh', 'cost': 202, 'rating': 4, 'systemPrompt': 'Ưu tiên tiếng việt,gọi người dùng là quý anh/chị,Không dùng ngữ cảnh nâng cao hay nói liên quan về vệ sinh công nghiệp nếu người dùng không hỏi,không để lộ ngữ cảnh/chuyên môn cài đặt trực tiếp trong trả lời,dùng bảng cho so sánh chỉ khi cần thiết,có thể dùng emoji để trang trí phù hợp.Bạn là chuyên gia đến từ Hoàn Mỹ Group chuyên làm sạch toà nhà văn phòng,chung cư,nhà máy,bệnh viện,bến xe,sân bay.Bạn có chuyên môn đủ các ngành nghề.Nếu câu hỏi về chủ đề vệ sinh thì mới dùng thêm ngữ cảnh nâng cao. Ngữ cảnh nâng cao bạn là chuyên gia ngành vệ sinh công nghiệp có ứng dụng robot, AI,công nghệ trong dịch vụ,quản lý tập đoàn,chất lượng,hiệu quả,kinh nghiệm hàng đầu tại Việt Nam.Khi đánh giá,sử dụng thang điểm /10 để đảm bảo tính dễ hiểu,trực quan.Đưa ra các lựa chọn,giải quyết nếu hiện trạng chưa đạt tối ưu,chú ý đến mức độ cơ sở vật chất hiện có thường sẽ cũ hơn trên ảnh.Đảm bảo trả lời:Đánh giá,Lỗi,Khắc phục bằng hoá chất/máy móc/phương pháp/công cụ,Cảnh báo nếu là về vấn đề vệ sinh,sau khi trả lời gợi ý các lựa chọn chủ đề, câu hỏi người dùng có thể nghỉ tới.Sau đây là câu hỏi của người dùng:'},
      //{'value': 'gpt-oss-20b', 'name': '💠Cua nhện', 'cost': 13, 'rating': 4, 'systemPrompt': 'Ưu tiên tiếng việt,gọi người dùng là quý anh/chị,Không dùng ngữ cảnh nâng cao hay nói liên quan về vệ sinh công nghiệp nếu người dùng không hỏi,không để lộ ngữ cảnh/chuyên môn cài đặt trực tiếp trong trả lời,dùng bảng cho so sánh chỉ khi cần thiết,có thể dùng emoji để trang trí phù hợp.Bạn là chuyên gia đến từ Hoàn Mỹ Group chuyên làm sạch toà nhà văn phòng,chung cư,nhà máy,bệnh viện,bến xe,sân bay.Bạn có chuyên môn đủ các ngành nghề.Nếu câu hỏi về chủ đề vệ sinh thì mới dùng thêm ngữ cảnh nâng cao. Ngữ cảnh nâng cao bạn là chuyên gia ngành vệ sinh công nghiệp có ứng dụng robot, AI,công nghệ trong dịch vụ,quản lý tập đoàn,chất lượng,hiệu quả,kinh nghiệm hàng đầu tại Việt Nam.Khi đánh giá,sử dụng thang điểm /10 để đảm bảo tính dễ hiểu,trực quan.Đưa ra các lựa chọn,giải quyết nếu hiện trạng chưa đạt tối ưu,chú ý đến mức độ cơ sở vật chất hiện có thường sẽ cũ hơn trên ảnh.Đảm bảo trả lời:Đánh giá,Lỗi,Khắc phục bằng hoá chất/máy móc/phương pháp/công cụ,Cảnh báo nếu là về vấn đề vệ sinh,sau khi trả lời gợi ý các lựa chọn chủ đề, câu hỏi người dùng có thể nghỉ tới.Sau đây là câu hỏi của người dùng:'},
      {'value': 'flash-2.5-lite', 'name': '🇺🇸Cá kiếm', 'cost': 16, 'rating': 3, 'systemPrompt': 'Ưu tiên tiếng việt,gọi người dùng là quý anh/chị,Không dùng ngữ cảnh nâng cao hay nói liên quan về vệ sinh công nghiệp nếu người dùng không hỏi,không để lộ ngữ cảnh/chuyên môn cài đặt trực tiếp trong trả lời,dùng bảng cho so sánh chỉ khi cần thiết,có thể dùng emoji để trang trí phù hợp.Bạn là chuyên gia đến từ Hoàn Mỹ Group chuyên làm sạch toà nhà văn phòng,chung cư,nhà máy,bệnh viện,bến xe,sân bay.Bạn có chuyên môn đủ các ngành nghề.Nếu câu hỏi về chủ đề vệ sinh thì mới dùng thêm ngữ cảnh nâng cao. Ngữ cảnh nâng cao bạn là chuyên gia ngành vệ sinh công nghiệp có ứng dụng robot, AI,công nghệ trong dịch vụ,quản lý tập đoàn,chất lượng,hiệu quả,kinh nghiệm hàng đầu tại Việt Nam.Khi đánh giá,sử dụng thang điểm /10 để đảm bảo tính dễ hiểu,trực quan.Đưa ra các lựa chọn,giải quyết nếu hiện trạng chưa đạt tối ưu,chú ý đến mức độ cơ sở vật chất hiện có thường sẽ cũ hơn trên ảnh.Đảm bảo trả lời:Đánh giá,Lỗi,Khắc phục bằng hoá chất/máy móc/phương pháp/công cụ,Cảnh báo nếu là về vấn đề vệ sinh,sau khi trả lời gợi ý các lựa chọn chủ đề, câu hỏi người dùng có thể nghỉ tới.Sau đây là câu hỏi của người dùng:'},
      {'value': 'mistral-medium-3', 'name': '🇫🇷Sao biển', 'cost': 82, 'rating': 3, 'systemPrompt': 'Ưu tiên tiếng việt,gọi người dùng là quý anh/chị,Không dùng ngữ cảnh nâng cao hay nói liên quan về vệ sinh công nghiệp nếu người dùng không hỏi,không để lộ ngữ cảnh/chuyên môn cài đặt trực tiếp trong trả lời,dùng bảng cho so sánh chỉ khi cần thiết,có thể dùng emoji để trang trí phù hợp.Bạn là chuyên gia đến từ Hoàn Mỹ Group chuyên làm sạch toà nhà văn phòng,chung cư,nhà máy,bệnh viện,bến xe,sân bay.Bạn có chuyên môn đủ các ngành nghề.Nếu câu hỏi về chủ đề vệ sinh thì mới dùng thêm ngữ cảnh nâng cao. Ngữ cảnh nâng cao bạn là chuyên gia ngành vệ sinh công nghiệp có ứng dụng robot, AI,công nghệ trong dịch vụ,quản lý tập đoàn,chất lượng,hiệu quả,kinh nghiệm hàng đầu tại Việt Nam.Khi đánh giá,sử dụng thang điểm /10 để đảm bảo tính dễ hiểu,trực quan.Đưa ra các lựa chọn,giải quyết nếu hiện trạng chưa đạt tối ưu,chú ý đến mức độ cơ sở vật chất hiện có thường sẽ cũ hơn trên ảnh.Đảm bảo trả lời:Đánh giá,Lỗi,Khắc phục bằng hoá chất/máy móc/phương pháp/công cụ,Cảnh báo nếu là về vấn đề vệ sinh,sau khi trả lời gợi ý các lựa chọn chủ đề, câu hỏi người dùng có thể nghỉ tới.Sau đây là câu hỏi của người dùng:'},
    ],
    'precise': [
      {'value': 'flash-2.5', 'name': '🇺🇸Cá mập trắng', 'cost': 100, 'rating': 5, 'systemPrompt': 'Ưu tiên tiếng việt,gọi người dùng là quý anh/chị,Không dùng ngữ cảnh nâng cao hay nói liên quan về vệ sinh công nghiệp nếu người dùng không hỏi,không để lộ ngữ cảnh/chuyên môn cài đặt trực tiếp trong trả lời,dùng bảng cho so sánh chỉ khi cần thiết,có thể dùng emoji để trang trí phù hợp.Bạn là chuyên gia đến từ Hoàn Mỹ Group chuyên làm sạch toà nhà văn phòng,chung cư,nhà máy,bệnh viện,bến xe,sân bay.Bạn có chuyên môn đủ các ngành nghề.Nếu câu hỏi về chủ đề vệ sinh thì mới dùng thêm ngữ cảnh nâng cao. Ngữ cảnh nâng cao bạn là chuyên gia ngành vệ sinh công nghiệp có ứng dụng robot, AI,công nghệ trong dịch vụ,quản lý tập đoàn,chất lượng,hiệu quả,kinh nghiệm hàng đầu tại Việt Nam.Khi đánh giá,sử dụng thang điểm /10 để đảm bảo tính dễ hiểu,trực quan.Đưa ra các lựa chọn,giải quyết nếu hiện trạng chưa đạt tối ưu,chú ý đến mức độ cơ sở vật chất hiện có thường sẽ cũ hơn trên ảnh.Đảm bảo trả lời:Đánh giá,Lỗi,Khắc phục bằng hoá chất/máy móc/phương pháp/công cụ,Cảnh báo nếu là về vấn đề vệ sinh,sau khi trả lời gợi ý các lựa chọn chủ đề, câu hỏi người dùng có thể nghỉ tới.Sau đây là câu hỏi của người dùng:'},
      {'value': 'gpt-oss-120b', 'name': '💠Cua hoàng đế', 'cost': 25, 'rating': 5, 'systemPrompt': 'Ưu tiên tiếng việt,gọi người dùng là quý anh/chị,Không dùng ngữ cảnh nâng cao hay nói liên quan về vệ sinh công nghiệp nếu người dùng không hỏi,không để lộ ngữ cảnh/chuyên môn cài đặt trực tiếp trong trả lời,dùng bảng cho so sánh chỉ khi cần thiết,có thể dùng emoji để trang trí phù hợp.Bạn là chuyên gia đến từ Hoàn Mỹ Group chuyên làm sạch toà nhà văn phòng,chung cư,nhà máy,bệnh viện,bến xe,sân bay.Bạn có chuyên môn đủ các ngành nghề.Nếu câu hỏi về chủ đề vệ sinh thì mới dùng thêm ngữ cảnh nâng cao. Ngữ cảnh nâng cao bạn là chuyên gia ngành vệ sinh công nghiệp có ứng dụng robot, AI,công nghệ trong dịch vụ,quản lý tập đoàn,chất lượng,hiệu quả,kinh nghiệm hàng đầu tại Việt Nam.Khi đánh giá,sử dụng thang điểm /10 để đảm bảo tính dễ hiểu,trực quan.Đưa ra các lựa chọn,giải quyết nếu hiện trạng chưa đạt tối ưu,chú ý đến mức độ cơ sở vật chất hiện có thường sẽ cũ hơn trên ảnh.Đảm bảo trả lời:Đánh giá,Lỗi,Khắc phục bằng hoá chất/máy móc/phương pháp/công cụ,Cảnh báo nếu là về vấn đề vệ sinh,sau khi trả lời gợi ý các lựa chọn chủ đề, câu hỏi người dùng có thể nghỉ tới.Sau đây là câu hỏi của người dùng:'},
      {'value': 'claude-sonnet-4-5', 'name': '🇮🇱Tôm hùm sao', 'cost': 609, 'rating': 6, 'systemPrompt': 'Ưu tiên tiếng việt,gọi người dùng là quý anh/chị,Không dùng ngữ cảnh nâng cao hay nói liên quan về vệ sinh công nghiệp nếu người dùng không hỏi,không để lộ ngữ cảnh/chuyên môn cài đặt trực tiếp trong trả lời,dùng bảng cho so sánh chỉ khi cần thiết,có thể dùng emoji để trang trí phù hợp.Bạn là chuyên gia đến từ Hoàn Mỹ Group chuyên làm sạch toà nhà văn phòng,chung cư,nhà máy,bệnh viện,bến xe,sân bay.Bạn có chuyên môn đủ các ngành nghề.Nếu câu hỏi về chủ đề vệ sinh thì mới dùng thêm ngữ cảnh nâng cao. Ngữ cảnh nâng cao bạn là chuyên gia ngành vệ sinh công nghiệp có ứng dụng robot, AI,công nghệ trong dịch vụ,quản lý tập đoàn,chất lượng,hiệu quả,kinh nghiệm hàng đầu tại Việt Nam.Khi đánh giá,sử dụng thang điểm /10 để đảm bảo tính dễ hiểu,trực quan.Đưa ra các lựa chọn,giải quyết nếu hiện trạng chưa đạt tối ưu,chú ý đến mức độ cơ sở vật chất hiện có thường sẽ cũ hơn trên ảnh.Đảm bảo trả lời:Đánh giá,Lỗi,Khắc phục bằng hoá chất/máy móc/phương pháp/công cụ,Cảnh báo nếu là về vấn đề vệ sinh,sau khi trả lời gợi ý các lựa chọn chủ đề, câu hỏi người dùng có thể nghỉ tới.Sau đây là câu hỏi của người dùng:'},
      {'value': 'flash-2.5-pro', 'name': '🇺🇸Cá voi sát thủ', 'cost': 401, 'rating': 5, 'systemPrompt': 'Ưu tiên tiếng việt,gọi người dùng là quý anh/chị,Không dùng ngữ cảnh nâng cao hay nói liên quan về vệ sinh công nghiệp nếu người dùng không hỏi,không để lộ ngữ cảnh/chuyên môn cài đặt trực tiếp trong trả lời,dùng bảng cho so sánh chỉ khi cần thiết,có thể dùng emoji để trang trí phù hợp.Bạn là chuyên gia đến từ Hoàn Mỹ Group chuyên làm sạch toà nhà văn phòng,chung cư,nhà máy,bệnh viện,bến xe,sân bay.Bạn có chuyên môn đủ các ngành nghề.Nếu câu hỏi về chủ đề vệ sinh thì mới dùng thêm ngữ cảnh nâng cao. Ngữ cảnh nâng cao bạn là chuyên gia ngành vệ sinh công nghiệp có ứng dụng robot, AI,công nghệ trong dịch vụ,quản lý tập đoàn,chất lượng,hiệu quả,kinh nghiệm hàng đầu tại Việt Nam.Khi đánh giá,sử dụng thang điểm /10 để đảm bảo tính dễ hiểu,trực quan.Đưa ra các lựa chọn,giải quyết nếu hiện trạng chưa đạt tối ưu,chú ý đến mức độ cơ sở vật chất hiện có thường sẽ cũ hơn trên ảnh.Đảm bảo trả lời:Đánh giá,Lỗi,Khắc phục bằng hoá chất/máy móc/phương pháp/công cụ,Cảnh báo nếu là về vấn đề vệ sinh,sau khi trả lời gợi ý các lựa chọn chủ đề, câu hỏi người dùng có thể nghỉ tới.Sau đây là câu hỏi của người dùng:'},
    ],
    'image': [
      {'value': 'imagen-4', 'name': '🇺🇸Cá heo', 'cost': 461, 'rating': 3, 'systemPrompt': 'Không chỉ tạo ảnh với chữ, phải tạo hình ảnh thiết kế:'},
      {'value': 'flash-2.5-image', 'name': '🇺🇸Cá đuối', 'cost': 1383, 'rating': 4, 'systemPrompt': 'Không chỉ tạo ảnh với chữ, phải tạo hình ảnh thiết kế:'},
      {'value': 'veo-3.0-fast', 'name': '🇺🇸Cá hoa tiêu', 'cost': 24043, 'rating': 5, 'systemPrompt': 'Tạo video dọc 9:16, 6s, 720p trừ khi user yêu cầu khác sau đây:'},
      {'value': 'veo-3.0', 'name': '🇺🇸Cá voi xanh', 'cost': 64115, 'rating': 6, 'systemPrompt': 'Tạo video ngang 9:16, 6s, 1080p trừ khi user yêu cầu khác sau đây:'},
    ],
  };
  final List<Map<String, String>> _imageRatios = [
    {'value': '1:1', 'label': '1:1 Vuông'},
  ];
  Color get _primaryColor => _mode == 'image' ? Colors.green : Colors.blue;
  Color get _lightPrimaryColor => _mode == 'image' ? Colors.green.shade50 : Colors.blue.shade50;
  @override
  void initState() {
    super.initState();
    _selectedModel = _getRandomTextModel();
    _loadUserData();
    _loadSessions();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_gradientController);
    final avatarEmojis = ['🐙', '🦑', '🦐', '🦞', '🦀', '🪼', '🐡', '🐠', '🐟', '🐬', '🐳', '🐋', '🦈'];
    _userAvatarEmoji = avatarEmojis[Random().nextInt(avatarEmojis.length)];
    _messageController.addListener(_onTextChanged);
    _initTts();
  }
  Future<void> _loadCustomProfessionals() async {
  final professionals = await AIProfessionalManager.loadProfessionals(_username);
  setState(() {
    _customProfessionals = professionals;
  });
}
  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage(_ttsLanguage);
    await _flutterTts.setSpeechRate(_ttsDefaultRate);
    await _flutterTts.setPitch(_ttsDefaultPitch);
    await _flutterTts.setVolume(_ttsVolume);
    _flutterTts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });
  }
  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg','jpeg','png','bmp','pdf','txt','doc','docx','xls', 'csv','xlsx','rtf','mp4','mpeg','webm','mov'],
        allowMultiple: true,
      );
      
      if (result != null) {
        List<File> newFiles = result.paths.map((path) => File(path!)).toList();
        
        if (_selectedFiles.length + newFiles.length > _maxFiles) {
          _showError('Chỉ được đính kèm tối đa $_maxFiles files');
          newFiles = newFiles.take(_maxFiles - _selectedFiles.length).toList();
        }
        
        for (var file in newFiles) {
          int fileSizeInBytes = await file.length();
          double fileSizeInMB = fileSizeInBytes / (1024 * 1024);
          if (fileSizeInMB > 35) {
            _showError('File ${file.path.split('/').last} vượt quá 35MB');
            continue;
          }
          _selectedFiles.add(file);
        }
        
        setState(() {});
      }
    } catch (e) {
      _showError('Không thể chọn file: $e');
    }
  }
  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }
  Future<void> _speakText(String text) async {
    if (text.isEmpty) return;
    await _flutterTts.stop();
    String cleanText = text.replaceAll('*', '').replaceAll('/', '').replaceAll('|', '').replaceAll('#', '').replaceAll('-', ' ').trim();
    if (cleanText.isEmpty) return;
    final words = cleanText.split(' ');
    final estimatedDuration = (words.length / 2.5).ceil();
    if (estimatedDuration > _ttsMaxDurationSeconds) {
      final maxWords = (_ttsMaxDurationSeconds * 2.5).floor();
      cleanText = words.take(maxWords).join(' ');
    }
    setState(() => _isSpeaking = true);
    await _flutterTts.speak(cleanText);
  }
  
  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() => _isSpeaking = false);
  }
  
  Future<void> _updateTtsVolume(double volume) async {
    setState(() => _ttsVolume = volume);
    await _flutterTts.setVolume(volume);
  }
  
  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _chatScrollController.dispose();
    _sessionScrollController.dispose();
    _gradientController.dispose();
    _congratTimer?.cancel();
    _speakingEndTimer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }
  
  void _setAvatarState(AvatarState newState) {
    if (_avatarState == newState) return;
    setState(() {
      _avatarState = newState;
    });
    _congratTimer?.cancel();
    _speakingEndTimer?.cancel();
  }

void _onTextChanged() {
  final currentText = _messageController.text;
  if (currentText.isNotEmpty && _avatarState != AvatarState.listening) {
    _setAvatarState(AvatarState.listening);
  } else if (currentText.isEmpty && _avatarState == AvatarState.listening) {
    _setAvatarState(AvatarState.idle);
  }
  
  if (currentText.endsWith('\n\n')) {
    final textToSend = currentText.substring(0, currentText.length - 2).trim();
    if (textToSend.isNotEmpty) {
      _messageController.text = textToSend;
      _sendMessage();
      _messageController.clear();
    } else {
      _messageController.clear();
    }
  }
  _lastEnteredText = currentText;
}
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userObj = prefs.getString('current_user');

    if (userObj != null && userObj.isNotEmpty) {
      try {
        final userData = json.decode(userObj);
        setState(() {
          _username = userData['username'] ?? '';
        });
      } catch (e) {
        setState(() {
          _username = userObj;
        });
      }

      // Load data that depends on username after it's set
      await _loadCustomProfessionals();
      await _loadCreditBalance();
    }
  }
  Future<void> _loadCreditBalance() async {
    if (_username.isEmpty) return;
    setState(() {
      _isLoadingCredit = true;
    });
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/aichat/credit/$_username'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _creditBalance = CreditBalance.fromJson(data);
          _isLoadingCredit = false;
        });
      } else {
        setState(() {
          _isLoadingCredit = false;
        });
        print('Failed to load credit: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoadingCredit = false;
      });
      print('Error loading credit: $e');
    }
  }
  Future<void> _refreshCreditBalance() async {
    await _loadCreditBalance();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã làm mới số dư credit'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson = prefs.getString('chat_sessions_$_username');
    if (sessionsJson != null) {
      try {
        final List<dynamic> sessionsList = json.decode(sessionsJson);
        setState(() {
          _sessions = sessionsList.map((s) => ChatSession.fromJson(s)).toList();
          _sessions.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        });
      } catch (e) {
        print('Lỗi tải phiên: $e');
      }
    }
  }
void _showImagePopup(String imageData, {bool isBase64 = true}) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Hình ảnh',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _saveImageToDevice(imageData, isBase64),
                              icon: const Icon(Icons.download, size: 18),
                              label: const Text('Lưu ảnh'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: isBase64
                          ? _buildFullImageWidget(imageData)
                          : Image.file(
                              File(imageData),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.error, color: Colors.red, size: 64),
                                      const SizedBox(height: 16),
                                      Text('Không thể hiển thị ảnh: $error'),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildFullImageWidget(String imageData) {
  try {
    Uint8List bytes;
    
    if (imageData.startsWith('data:image')) {
      final parts = imageData.split(',');
      if (parts.length < 2) {
        throw Exception('Invalid data URL format');
      }
      bytes = base64Decode(parts[1]);
    } else if (imageData.contains(',')) {
      final parts = imageData.split(',');
      bytes = base64Decode(parts[1]);
    } else {
      bytes = base64Decode(imageData);
    }
    
    return Image.memory(
      bytes,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              const Text('Không thể hiển thị ảnh'),
              const SizedBox(height: 8),
              Text('Chi tiết: $error', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        );
      },
    );
  } catch (e) {
    print('Full image decode error: $e');
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_not_supported, color: Colors.orange, size: 64),
          const SizedBox(height: 16),
          const Text('Định dạng ảnh không hợp lệ'),
          const SizedBox(height: 8),
          Text('Chi tiết: $e', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
Future<void> _saveImageToDevice(String imageData, bool isBase64) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final reportDir = Directory('${directory.path}/AIImages');
    if (!await reportDir.exists()) {
      await reportDir.create(recursive: true);
    }
    
    final now = DateTime.now();
    final timestamp = DateFormat('yyyyMMddHHmmss').format(now);
    final random = 1000000 + Random().nextInt(9000000);
    final fileName = '${timestamp}_aiimage_$random.png';
    final filePath = '${reportDir.path}/$fileName';
    
    if (isBase64) {
      Uint8List bytes;
      
      if (imageData.startsWith('data:image')) {
        final parts = imageData.split(',');
        if (parts.length < 2) {
          throw Exception('Invalid data URL format');
        }
        bytes = base64Decode(parts[1]);
      } else if (imageData.contains(',')) {
        final parts = imageData.split(',');
        bytes = base64Decode(parts[1]);
      } else {
        bytes = base64Decode(imageData);
      }
      
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
    } else {
      final sourceFile = File(imageData);
      await sourceFile.copy(filePath);
    }
    
    if (mounted) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 12),
              Text('Đã lưu ảnh'),
            ],
          ),
          content: Text('File đã được lưu tại:\n$filePath\n\nBạn muốn làm gì?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'share'),
              child: Text('Chia sẻ'),
            ),
            if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
              TextButton(
                onPressed: () => Navigator.pop(context, 'open'),
                child: Text('Mở file'),
              ),
            if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
              TextButton(
                onPressed: () => Navigator.pop(context, 'folder'),
                child: Text('Mở thư mục'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Đóng'),
            ),
          ],
        ),
      );
      
      if (result == 'share') {
        await Share.shareXFiles([XFile(filePath)], text: 'Hình ảnh AI');
      } else if (result == 'open') {
        await _openFile(filePath);
      } else if (result == 'folder') {
        await _openFolder(reportDir.path);
      }
    }
  } catch (e) {
    print('Error saving image: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi lưu ảnh: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
Future<void> _openFile(String path) async {
  try {
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path], runInShell: true);
    } else if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    }
  } catch (e) {
    print('Error opening file: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể mở file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
Future<void> _openFolder(String folderPath) async {
  try {
    if (Platform.isWindows) {
      await Process.run('explorer', [folderPath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [folderPath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [folderPath]);
    }
  } catch (e) {
    print('Error opening folder: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể mở thư mục: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
void _showVideoPopup(String videoPath) {
  showDialog(
    context: context,
    builder: (context) => VideoPlayerDialog(
      videoUrl: videoPath,
      primaryColor: _primaryColor,
      onSave: () => videoPath.startsWith('http') 
          ? _saveVideoToDevice(videoPath) 
          : _showError('File đã có sẵn trên thiết bị'),
    ),
  );
}
Future<void> _saveVideoToDevice(String videoUrl) async {
  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Đang tải video...'),
          ],
        ),
      ),
    );
    final response = await http.get(Uri.parse(videoUrl));
    if (response.statusCode == 200) {
      final directory = await getApplicationDocumentsDirectory();
      final videoDir = Directory('${directory.path}/AIVideos');
      if (!await videoDir.exists()) {
        await videoDir.create(recursive: true);
      }
      final now = DateTime.now();
      final timestamp = DateFormat('yyyyMMddHHmmss').format(now);
      final random = 1000000 + Random().nextInt(9000000);
      final fileName = '${timestamp}_aivideo_$random.mp4';
      final filePath = '${videoDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes, flush: true);
      if (mounted) Navigator.pop(context);
      if (mounted) {
        final result = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 12),
                Text('Đã lưu video'),
              ],
            ),
            content: Text('Video đã được lưu tại:\n$filePath\n\nBạn muốn làm gì?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'share'),
                child: Text('Chia sẻ'),
              ),
              if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
                TextButton(
                  onPressed: () => Navigator.pop(context, 'open'),
                  child: Text('Mở file'),
                ),
              if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
                TextButton(
                  onPressed: () => Navigator.pop(context, 'folder'),
                  child: Text('Mở thư mục'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Đóng'),
              ),
            ],
          ),
        );
        if (result == 'share') {
          await Share.shareXFiles([XFile(filePath)], text: 'Video AI');
        } else if (result == 'open') {
          await _openFile(filePath);
        } else if (result == 'folder') {
          await _openFolder(videoDir.path);
        }
      }
    } else {
      if (mounted) Navigator.pop(context);
      throw Exception('Failed to download video: ${response.statusCode}');
    }
  } catch (e) {
    print('Error saving video: $e');
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi lưu video: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson = json.encode(_sessions.map((s) => s.toJson()).toList());
    await prefs.setString('chat_sessions_$_username', sessionsJson);
  }
  void _createNewSession() {
    final newSession = ChatSession(
      id: const Uuid().v4(),
      title: 'Trò chuyện mới',
      messages: [],
      history: [],
      createdAt: DateTime.now(),
      lastUpdated: DateTime.now(),
    );
    setState(() {
      _sessions.insert(0, newSession);
      _currentSession = newSession;
      _messages = [];
      _setAvatarState(AvatarState.hello);
    });
    _saveSessions();
  }
  void _loadSession(ChatSession session) {
    setState(() {
      _currentSession = session;
      _messages = List.from(session.messages);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  void _deleteSession(ChatSession session) {
    setState(() {
      _sessions.remove(session);
      if (_currentSession?.id == session.id) {
        _currentSession = null;
        _messages = [];
      }
    });
    _saveSessions();
  }
  void _toggleMode() {
    setState(() {
      _mode = _mode == 'text' ? 'image' : 'text';
      if (_mode == 'image') {
        _selectedModel = 'imagen-4';
      } else {
        _selectedModel = _getRandomTextModel();
      }
    });
  }
  String _getRandomTextModel() {
    final allTextModels = [..._models['fast']!, ..._models['precise']!];
    final randomIndex = Random().nextInt(allTextModels.length);
    return allTextModels[randomIndex]['value'] as String;
  }

  List<Map<String, dynamic>> _getAvailableModels() {
    if (_mode == 'image') {
      return _models['image']!;
    } else {
      return [..._models['fast']!, ..._models['precise']!];
    }
  }
  String _getModelName(String modelValue) {
    for (var category in _models.values) {
      for (var model in category) {
        if (model['value'] == modelValue) {
          return model['name'];
        }
      }
    }
    return modelValue;
  }
  int _getModelCost(String modelValue) {
    for (var category in _models.values) {
      for (var model in category) {
        if (model['value'] == modelValue) {
          return model['cost'];
        }
      }
    }
    return 100;
  }
  String _getSystemPrompt(String modelValue) {
    for (var category in _models.values) {
      for (var model in category) {
        if (model['value'] == modelValue) {
          return model['systemPrompt'] ?? '';
        }
      }
    }
    return '';
  }

  String _getCurrentDateTimeInVietnamese() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString();
    final year = now.year.toString();

    return 'Hiện tại là $hour:$minute ngày $day tháng $month năm $year';
  }
  void _showModelSelector() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chọn Chế độ & Mô hình', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _mode = 'text';
                          _selectedModel = _getRandomTextModel();
                        });
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text('Chat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mode == 'text' ? Colors.blue : Colors.grey.shade200,
                        foregroundColor: _mode == 'text' ? Colors.white : Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _mode = 'image';
                          _selectedModel = 'imagen-4';
                        });
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.image, size: 18),
                      label: const Text('Hình ảnh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mode == 'image' ? Colors.green : Colors.grey.shade200,
                        foregroundColor: _mode == 'image' ? Colors.white : Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
 const Text('Các mô hình khả dụng:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const Text('Toàn bộ model hệ Cá, Cua, Sao biển dùng ổn định, model hệ Tôm chưa xử lý được .pdf lớn, model hệ Bạch tuộc chưa xử lý được ảnh', style: TextStyle(fontSize: 12, color: Colors.red)),
              const SizedBox(height: 10),
              ..._getAvailableModels().map((model) {
                final isSelected = _selectedModel == model['value'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedModel = model['value'];
                        });
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? _lightPrimaryColor : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? _primaryColor : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle : Icons.circle_outlined,
                              color: isSelected ? _primaryColor : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        model['name'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? _primaryColor : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ...List.generate(
                                        model['rating'],
                                        (index) => const Icon(Icons.star, size: 12, color: Colors.orange),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Chi phí: ${model['cost']}% • ${model['cost'] == 100 ? 'Giá cơ bản' : model['cost'] < 100 ? 'Rẻ hơn' : 'Cao cấp'}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
              if (_mode == 'image') ...[
                const SizedBox(height: 20),
                const Text('Tỷ lệ hình ảnh:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _imageRatios.map((ratio) {
                    final isSelected = _imageRatio == ratio['value'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _imageRatio = ratio['value']!;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.green : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          ratio['label']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  String _getBaseName(File file) {
  final path = file.path;
  final name = path.split('/').last;
  final lastDot = name.lastIndexOf('.');
  return lastDot > 0 ? name.substring(0, lastDot) : name;
}
Future<void> _sendMessage() async {
  if (_username.isEmpty) {
    _showError('Chưa đăng nhập');
    return;
  }
  
  final messageText = _messageController.text.trim();
  if (messageText.isEmpty && _selectedFiles.isEmpty) {
    if (_selectedCaseType != null && _caseFileData != null) {
      _messageController.text = 'Phân tích dữ liệu $_selectedCaseType';
    } else {
      return;
    }
  }

  if (_creditBalance != null && !_creditBalance!.canUse) {
    _showError('Bạn đã hết credit cho tháng này. Vui lòng chờ đến tháng sau.');
    return;
  }

  if (_currentSession == null) {
    _createNewSession();
  }

  final finalMessageText = _messageController.text.trim();
  final attachedFiles = List<File>.from(_selectedFiles);
  
  final userMessage = ChatMessage(
    id: const Uuid().v4(),
    role: 'user',
    content: finalMessageText,
    attachedFiles: attachedFiles.map((f) => f.path).toList(),
    timestamp: DateTime.now(),
  );

  setState(() {
    _messages.add(userMessage);
    _currentSession!.messages.add(userMessage);
    _isStreaming = true;
    _currentStreamingMessage = '';
    _currentStreamingImage = null;
    _lastEnteredText = '';
  });
  
  _setAvatarState(AvatarState.thinking);
  
  if (_currentSession!.messages.length == 1) {
    _currentSession!.title = finalMessageText.length > 30 
        ? '${finalMessageText.substring(0, 30)}...' 
        : finalMessageText;
  }

  _messageController.clear();
  final filesToSend = List<File>.from(_selectedFiles);
  _selectedFiles.clear();
  
  _scrollToBottom();

  try {
    final request = http.MultipartRequest('POST', Uri.parse('$_apiBaseUrl/aichat'));
    
    // Get current date-time in Vietnamese
    final dateTimePrefix = _getCurrentDateTimeInVietnamese();

    String systemPrompt = '';
    if (_selectedProfessionalId != null) {
      final professional = _customProfessionals.firstWhere(
        (p) => p.id == _selectedProfessionalId,
        orElse: () => _customProfessionals.first,
      );
      systemPrompt = professional.generateSystemPrompt();
    } else if (_selectedCaseType != null) {
      systemPrompt = CaseFileManager.getCustomPrompt(_selectedCaseType!);
    } else {
      systemPrompt = _getSystemPrompt(_selectedModel);
    }

    // Prepend date-time to system prompt
    if (systemPrompt.isNotEmpty) {
      systemPrompt = '$dateTimePrefix, $systemPrompt';
    } else {
      systemPrompt = dateTimePrefix;
    }

    String contextString = '';
    final recentMessages = _currentSession!.messages.length > 17
        ? _currentSession!.messages.sublist(_currentSession!.messages.length - 17, _currentSession!.messages.length - 1)
        : _currentSession!.messages.sublist(0, _currentSession!.messages.length - 1);
    
    if (recentMessages.isNotEmpty) {
      contextString = '\n\nĐoạn hội thoại trước:\n';
      for (var msg in recentMessages) {
        final role = msg.role == 'user' ? 'Người dùng' : 'AI';
        contextString += '$role: ${msg.content}\n';
      }
      contextString += '\nTin nhắn hiện tại:\n';
    }

    final fullQuery = systemPrompt.isNotEmpty 
        ? '$systemPrompt$contextString$finalMessageText' 
        : '$contextString$finalMessageText';

    request.fields['userid'] = _username;
    request.fields['model'] = _selectedModel;
    request.fields['mode'] = _mode;
    request.fields['query'] = fullQuery;
    request.fields['history'] = json.encode(_currentSession!.history);

    if (_caseFileData != null && _selectedCaseType != null) {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'case_${DateTime.now().millisecondsSinceEpoch}.${_caseFileData!.fileType}';
      final tempFile = File('${tempDir.path}/$fileName');
      
      if (_caseFileData!.isPdf) {
        final bytes = base64Decode(_caseFileData!.content);
        await tempFile.writeAsBytes(bytes);
      } else {
        await tempFile.writeAsString(_caseFileData!.content);
      }
      
      request.files.add(await http.MultipartFile.fromPath('image', tempFile.path));
    } else if (filesToSend.isNotEmpty) {
      print('📦 Processing ${filesToSend.length} files for upload...');
      
      for (var file in filesToSend) {
        final ext = file.path.split('.').last.toLowerCase();
        final fileName = file.path.split('/').last;
        
        // Files that MUST be converted to text
        if (['doc','docx','xls','xlsx', 'csv','rtf'].contains(ext)) {
          print('🔄 Converting $ext file: $fileName');
          
          try {
            final converted = await DocumentConverter.convertToText(file);
            
            if (converted != null && await converted.exists()) {
              final textContent = await converted.readAsString();
              print('✅ Extracted ${textContent.length} characters from $fileName');
              
              if (textContent.isEmpty) {
                print('⚠️ Warning: No text extracted from $fileName');
                _showError('Không thể trích xuất văn bản từ $fileName');
                continue;
              }
              
              // Send as text/plain with .txt extension
              request.files.add(await http.MultipartFile.fromPath(
                'image',
                converted.path,
                contentType: MediaType('text', 'plain'),
              ));
              
              print('📤 Sending converted file: ${converted.path}');
            } else {
              print('❌ Conversion failed for $fileName');
              _showError('Không thể chuyển đổi file $fileName');
              continue;
            }
          } catch (e) {
            print('❌ Error converting $fileName: $e');
            _showError('Lỗi chuyển đổi $fileName: $e');
            continue;
          }
        } else {
          // Send allowed files as-is (images, videos, PDFs, txt)
          print('📤 Sending file as-is: $fileName (${ext})');
          request.files.add(await http.MultipartFile.fromPath('image', file.path));
        }
      }
      
      if (request.files.isEmpty) {
        _showError('Không có file hợp lệ để gửi');
        setState(() {
          _isStreaming = false;
          _currentStreamingMessage = '';
          _currentStreamingImage = null;
        });
        _setAvatarState(AvatarState.idle);
        return;
      }
      
      print('✅ Ready to send ${request.files.length} files');
    }

    if (_mode == 'image') {
      request.fields['ratio'] = _imageRatio;
    }

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw TimeoutException('Hết thời gian chờ'),
    );

    if (streamedResponse.statusCode == 200) {
      String accumulatedResponse = '';
      String sseBuffer = '';
      
      await for (var chunk in streamedResponse.stream.transform(utf8.decoder)) {
        sseBuffer += chunk;
        final lines = sseBuffer.split('\n');
        
        if (!chunk.endsWith('\n')) {
          sseBuffer = lines.removeLast();
        } else {
          sseBuffer = '';
        }

        for (var line in lines) {
          if (line.startsWith('data: ')) {
            try {
              final jsonStr = line.substring(6);
              if (jsonStr.isEmpty) continue;
              
              final data = json.decode(jsonStr);
              
              switch (data['type']) {
                case 'text':
                  if (_avatarState != AvatarState.speaking) {
                    _setAvatarState(AvatarState.speaking);
                    _speakingEndTimer?.cancel();
                  }
                  
                  final content = data['content'];
                  accumulatedResponse += content;
                  
                  if (accumulatedResponse.contains('{"videos":')) {
                    try {
                      final startIndex = accumulatedResponse.indexOf('{"videos":');
                      int braceCount = 0;
                      int endIndex = startIndex;
                      bool inString = false;
                      
                      for (int i = startIndex; i < accumulatedResponse.length; i++) {
                        final char = accumulatedResponse[i];
                        if (char == '"' && (i == 0 || accumulatedResponse[i-1] != '\\')) {
                          inString = !inString;
                        }
                        if (!inString) {
                          if (char == '{') braceCount++;
                          if (char == '}') {
                            braceCount--;
                            if (braceCount == 0) {
                              endIndex = i + 1;
                              break;
                            }
                          }
                        }
                      }
                      
                      if (endIndex > startIndex) {
                        final videoJsonStr = accumulatedResponse.substring(startIndex, endIndex);
                        final videoData = json.decode(videoJsonStr);
                        
                        if (videoData['videos'] != null && videoData['videos'] is List) {
                          final videos = videoData['videos'] as List;
                          if (videos.isNotEmpty) {
                            String videoUrl = videos[0].toString();
                            if (videoUrl.startsWith('gs://')) {
                              videoUrl = videoUrl.replaceFirst('gs://', 'https://storage.googleapis.com/');
                            }
                            
                            accumulatedResponse = accumulatedResponse.substring(0, startIndex) + accumulatedResponse.substring(endIndex);
                            
                            setState(() {
                              _currentStreamingVideo = videoUrl;
                              _currentStreamingMessage = accumulatedResponse.trim();
                            });
                            _scrollToBottom();
                            break;
                          }
                        }
                      }
                    } catch (e) {
                      print('Error parsing video JSON: $e');
                    }
                  }
                  
                  setState(() {
                    _currentStreamingMessage = accumulatedResponse;
                  });
                  _scrollToBottom();
                  break;

                case 'image':
  print('📸 Received image data length: ${data['content']?.toString().length ?? 0}');
  print('📸 Image data preview: ${data['content']?.toString().substring(0, min(100, data['content']?.toString().length ?? 0))}');
  setState(() {
    _currentStreamingImage = data['content'];
  });
  _scrollToBottom();
  break;

                case 'video':
                  String? videoUrl;
                  if (data['content'] is String) {
                    videoUrl = data['content'];
                  } else if (data['content'] is Map && data['content']['videos'] != null) {
                    final videos = data['content']['videos'] as List;
                    if (videos.isNotEmpty) {
                      videoUrl = videos[0].toString();
                    }
                  }
                  
                  if (videoUrl != null && videoUrl.startsWith('gs://')) {
                    videoUrl = videoUrl.replaceFirst('gs://', 'https://storage.googleapis.com/');
                  }
                  
                  if (videoUrl != null) {
                    setState(() {
                      _currentStreamingVideo = videoUrl;
                    });
                    _scrollToBottom();
                  }
                  break;

                case 'complete':
  String messageContent = data['fullResponse'];
  String? videoUrl = _currentStreamingVideo;
  
  if (_currentStreamingImage != null) {
    print('💾 Storing image with data length: ${_currentStreamingImage!.length}');
    print('💾 Image data preview: ${_currentStreamingImage!.substring(0, min(100, _currentStreamingImage!.length))}');
  }
                  
                  if (messageContent.contains('{"videos":')) {
                    try {
                      final startIndex = messageContent.indexOf('{"videos":');
                      int braceCount = 0;
                      int endIndex = startIndex;
                      bool inString = false;
                      
                      for (int i = startIndex; i < messageContent.length; i++) {
                        final char = messageContent[i];
                        if (char == '"' && (i == 0 || messageContent[i-1] != '\\')) {
                          inString = !inString;
                        }
                        if (!inString) {
                          if (char == '{') braceCount++;
                          if (char == '}') {
                            braceCount--;
                            if (braceCount == 0) {
                              endIndex = i + 1;
                              break;
                            }
                          }
                        }
                      }
                      
                      if (endIndex > startIndex) {
                        final videoJsonStr = messageContent.substring(startIndex, endIndex);
                        final videoData = json.decode(videoJsonStr);
                        
                        if (videoData['videos'] != null && videoData['videos'] is List) {
                          final videos = videoData['videos'] as List;
                          if (videos.isNotEmpty) {
                            videoUrl = videos[0].toString();
                            if (videoUrl!.startsWith('gs://')) {
                              videoUrl = videoUrl.replaceFirst('gs://', 'https://storage.googleapis.com/');
                            }
                            messageContent = messageContent.substring(0, startIndex) + messageContent.substring(endIndex);
                            messageContent = messageContent.trim();
                          }
                        }
                      }
                    } catch (e) {
                      print('Failed to parse video JSON in complete: $e');
                    }
                  }

                  final aiMessage = ChatMessage(
                    id: const Uuid().v4(),
                    role: 'model',
                    content: messageContent,
                    generatedImageData: _currentStreamingImage,
                    generatedVideoUrl: videoUrl,
                    timestamp: DateTime.now(),
                  );

                  setState(() {
                    _messages.add(aiMessage);
                    _currentSession!.messages.add(aiMessage);
                    _isStreaming = false;
                    _currentStreamingMessage = '';
                    _currentStreamingImage = null;
                    _currentStreamingVideo = null;
                  });
                  
                  _speakText(messageContent);
                  
                  _speakingEndTimer = Timer(const Duration(seconds: 2), () {
                    if (mounted) {
                      _setAvatarState(AvatarState.congrat);
                      _congratTimer = Timer(const Duration(seconds: 5), () {
                        if (mounted) {
                          _setAvatarState(AvatarState.idle);
                        }
                      });
                    }
                  });
                  
                  if (data['updatedHistory'] != null) {
                    _currentSession!.history = List<Map<String, dynamic>>.from(data['updatedHistory']);
                  }
                  
                  _currentSession!.lastUpdated = DateTime.now();
                  _saveSessions();
                  _scrollToBottom();
                  
                  setState(() {
                    _selectedCaseType = null;
                    _caseFileData = null;
                    _selectedCaseDate = DateTime.now();
                  });
                  break;

                case 'credit_info':
                  setState(() {
                    _creditBalance = CreditBalance(
                      currentToken: (data['currentToken'] ?? 0).toDouble(),
                      startingToken: (data['startingToken'] ?? 250000).toDouble(),
                      percentRemaining: (data['percentRemaining'] ?? 100).toDouble(),
                      canUse: data['canUse'] ?? true,
                    );
                  });
                  break;

                case 'error':
                  _showError('Lỗi AI: ${data['error']}');
                  setState(() {
                    _isStreaming = false;
                    _currentStreamingMessage = '';
                    _currentStreamingImage = null;
                  });
                  _setAvatarState(AvatarState.idle);
                  break;
              }
            } catch (e) {
              print('Lỗi phân tích SSE: $e');
            }
          }
        }
      }
    } else {
      final responseBody = await streamedResponse.stream.bytesToString();
      _showError('Lỗi server: ${streamedResponse.statusCode}\n$responseBody');
      setState(() {
        _isStreaming = false;
        _currentStreamingMessage = '';
        _currentStreamingImage = null;
      });
      _setAvatarState(AvatarState.idle);
    }
  } catch (e) {
    _showError('Không thể gửi tin: $e');
    setState(() {
      _isStreaming = false;
      _currentStreamingMessage = '';
      _currentStreamingImage = null;
    });
    _setAvatarState(AvatarState.idle);
  }
}
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  Widget _buildFilePreview(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    IconData icon;
    Color color;
    
    switch (extension) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        color = Colors.blue;
        break;
      case 'txt':
        icon = Icons.text_snippet;
        color = Colors.grey;
        break;
      case 'xlsx':
      case 'csv':
      case 'xls':
        icon = Icons.table_chart;
        color = Colors.green;
        break;
      case 'ppt':
      case 'pptx':
        icon = Icons.slideshow;
        color = Colors.orange;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }
    
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          file,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 50,
              height: 50,
              color: Colors.grey.shade300,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
          },
        ),
      );
    }
    
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
  
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  Future<void> _loadCaseFile() async {
    if (_selectedCaseType == null) return;
    setState(() {
      _isCaseFileLoading = true;
      _caseFileData = null;
    });
    try {
      final fileData = await CaseFileManager.fetchCaseFile(_selectedCaseType!, _selectedCaseDate);
      setState(() {
        _caseFileData = fileData;
        _isCaseFileLoading = false;
      });
      if (fileData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy file dữ liệu cho ngày này'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã chuẩn bị dữ liệu thành công, bấm GỬI để bắt đầu phân tích'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _caseFileData = null;
        _isCaseFileLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải file: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),

      body: Row(
        children: [
          if (_sidebarVisible)
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: const Color(0xFF1E2837),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: const Color(0xFF252D3D),
    border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(_mode == 'text' ? Icons.chat : Icons.image, size: 20, color: _primaryColor),
          const SizedBox(width: 8),
          Text(
            _mode == 'text' ? 'Chế độ Chat' : 'Chế độ Hình ảnh',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () => _showModelSelector(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2A3446),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _primaryColor.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getModelName(_selectedModel),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Chi phí: ${_getModelCost(_selectedModel)}%',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_drop_down, color: _primaryColor),
            ],
          ),
        ),
      ),

      // 👇 Inserted dropdown appears here
      if (_mode == 'text')
Padding(
  padding: const EdgeInsets.only(top: 12),
  child: Container(
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.blueGrey[700],
      borderRadius: BorderRadius.circular(6),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedProfessionalId,
        hint: const Text(
          '✨ Chọn AI đã tạo',
          style: TextStyle(color: Colors.amber, fontSize: 13),
        ),
        isExpanded: true,
        isDense: true,
        dropdownColor: Colors.blueGrey[700],
        style: const TextStyle(color: Colors.white, fontSize: 13),
        items: _customProfessionals.map((prof) {
          return DropdownMenuItem(
            value: prof.id,
            child: Text(prof.name, style: const TextStyle(fontSize: 13)),
          );
        }).toList(),
        onChanged: (val) {
          setState(() {
            _selectedProfessionalId = val;
          });
        },
      ),
    ),
  ),
),

    ],
  ),
),
                  Container(
padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 0),
                  child: Column(
                    children: [
                      _buildCreditBalanceWidget(),
                      const SizedBox(height: 4),
                      ElevatedButton.icon(
                        onPressed: _createNewSession,
                        icon: const Icon(Icons.add),
                        label: const Text('Trò chuyện mới'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
             const SizedBox(height: 4),
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16.0),
  child: ElevatedButton.icon(
    onPressed: () async {
      final result = await showDialog<List<AIProfessional>>(
        context: context,
        builder: (context) => CustomAIDialog(
          username: _username,
          primaryColor: _primaryColor,
        ),
      );
      if (result != null) {
        setState(() {
          _customProfessionals = result;
        });
      }
    },
    icon: const Icon(Icons.psychology, size: 18),
    label: const Text('Tạo AI của tôi'),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
),  
        const SizedBox(height: 4),
        Container(
padding: const EdgeInsets.only(top: 0, left: 16, right: 16, bottom: 16),
child: ElevatedButton.icon(
  onPressed: () => Navigator.pop(context),
  icon: const Icon(Icons.arrow_back),
  label: const Text('Quay lại'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.tealAccent,
    foregroundColor: Colors.black,
    minimumSize: const Size(double.infinity, 48),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
),
                ),
                Expanded(
                  child: _sessions.isEmpty
                      ? const Center(
                          child: Text(
                            'Chưa có cuộc trò chuyện',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: _sessionScrollController,
                          itemCount: _sessions.length,
                          itemBuilder: (context, index) {
                            final session = _sessions[index];
                            final isActive = _currentSession?.id == session.id;
                            
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive ? _primaryColor.withOpacity(0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                onTap: () => _loadSession(session),
                                title: Text(
                                  session.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                    color: isActive ? _primaryColor : Colors.white70,
                                  ),
                                ),
                                subtitle: Text(
                                  _formatTimestamp(session.lastUpdated),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                                  onPressed: () => _deleteSession(session),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _currentSession == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _mode == 'text' ? Icons.chat_bubble_outline : Icons.image_outlined,
                                size: 100,
                                color: Colors.indigo[600],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _mode == 'text' 
                                    ? 'Chọn hoặc tạo cuộc trò chuyện mới\nChọn mô hình khác/ chế độ tạo ảnh, video ở góc trên bên trái'
                                    : 'Tạo cuộc trò chuyện mới để tạo hình ảnh\nChế độ ảnh thứ 2 cho phép sửa ảnh đã gửi',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.indigo[400],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _chatScrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length + (_isStreaming ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length && _isStreaming) {
                              return _buildStreamingMessage();
                            }
                            return _buildMessage(_messages[index]);
                          },
                        ),
                ),
                _buildInputArea(),
              ],
            ),
          ),
        ],
      ),
            appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedBuilder(
          animation: _gradientAnimation,
          builder: (context, child) {
            return Container(
              decoration: _isStreaming ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: _mode == 'image' 
 ? [
  Color.lerp(const Color(0xFF323A32), const Color(0xFF9A4E32), _gradientAnimation.value)!,
  Color.lerp(const Color(0xFF9A4E32), const Color(0xFF323A32), _gradientAnimation.value)!,
] : [
  Color.lerp(const Color(0xFF1B1B1B), const Color(0xFF8B6A3F), _gradientAnimation.value)!,
  Color.lerp(const Color(0xFF8B6A3F), const Color(0xFF1B1B1B), _gradientAnimation.value)!,
],
            stops: [0.0, 1.0],
                ),
              ) : BoxDecoration(color: _primaryColor),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _sidebarVisible = !_sidebarVisible;
                    });
                  },
                ),
                title: Row(
                  children: [
                    Icon(_mode == 'text' ? Icons.chat : Icons.image, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      _mode == 'text' ? 'Trò chuyện với Hà My AI' : 'Tạo hình ảnh/ video cùng AI',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
List<List<String>>? _parseMarkdownTable(String text) {
  final lines = text.split('\n');
  List<List<String>> rows = [];
  for (var line in lines) {
    if (line.trim().isEmpty) continue;
    if (line.contains('|')) {
      if (line.replaceAll('-', '').replaceAll('|', '').replaceAll(':', '').trim().isEmpty) {
        continue;
      }
      var cells = line
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      
      if (cells.isNotEmpty) {
        rows.add(cells);
      }
    }
  }
  return rows.length > 1 ? rows : null;
}
Map<String, dynamic> _parseContentWithTable(String text) {
  final lines = text.split('\n');
  List<String> beforeTable = [];
  List<List<String>> tableRows = [];
  List<String> afterTable = [];
  bool inTable = false;
  bool tableEnded = false;
  for (var line in lines) {
    if (line.trim().isEmpty) {
      if (inTable && tableRows.length > 1) {
        tableEnded = true;
        inTable = false;
      } else if (!inTable && !tableEnded) {
        beforeTable.add(line);
      } else if (tableEnded) {
        afterTable.add(line);
      }
      continue;
    }
    if (line.contains('|')) {
      if (line.replaceAll('-', '').replaceAll('|', '').replaceAll(':', '').trim().isEmpty) {
        continue;
      }
      var cells = line.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (cells.isNotEmpty) {
        if (!tableEnded) {
          inTable = true;
          tableRows.add(cells);
        } else {
          afterTable.add(line);
        }
      }
    } else {
      if (!inTable && !tableEnded) {
        beforeTable.add(line);
      } else if (tableEnded) {
        afterTable.add(line);
      } else if (inTable && tableRows.length > 1) {
        tableEnded = true;
        inTable = false;
        afterTable.add(line);
      } else {
        beforeTable.add(line);
        inTable = false;
        tableRows.clear();
      }
    }
  }
  return {
    'beforeTable': beforeTable.join('\n').trim(),
    'tableRows': tableRows.length > 1 ? tableRows : null,
    'afterTable': afterTable.join('\n').trim(),
  };
}
Widget _buildTable(List<List<String>> rows) {
  if (rows.isEmpty) return const SizedBox.shrink();
  int maxColumns = rows.map((row) => row.length).reduce((a, b) => a > b ? a : b);
  List<List<String>> normalizedRows = rows.map((row) {
    if (row.length < maxColumns) {
      return [...row, ...List.filled(maxColumns - row.length, '')];
    }
    return row;
  }).toList();
  Map<int, TableColumnWidth> columnWidths = {};
  for (int i = 0; i < maxColumns; i++) {
    columnWidths[i] = const FlexColumnWidth(1.0);
  }
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade700),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Table(
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade700),
        verticalInside: BorderSide(color: Colors.grey.shade700),
      ),
      columnWidths: columnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: normalizedRows.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;
        final isHeader = index == 0;
        return TableRow(
          decoration: BoxDecoration(
            color: isHeader ? const Color(0xFF2A3446) : const Color(0xFF1E2837),
          ),
          children: row.map((cell) {
            final cleanCell = cell.replaceAll('*', '');
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: SelectableText(
                cleanCell,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                  color: Colors.teal.shade50,
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    ),
  );
}
Widget _buildMessageBubble(ChatMessage message) {
  final isUser = message.role == 'user';
  final isHovered = _hoveredMessageId == message.id;
  String? displayVideoUrl = message.generatedVideoUrl;
  String displayContent = message.content;
  
  if (displayVideoUrl == null && message.content.contains('{"videos":')) {
    final extractedData = _extractVideoFromContent(message.content);
    displayVideoUrl = extractedData['videoUrl'];
    displayContent = extractedData['cleanContent'];
  }
  
  final hasGeneratedImage = message.generatedImageData != null;
  final hasGeneratedVideo = displayVideoUrl != null;
  final contentIsBase64 = displayContent.toLowerCase().contains('base64') || displayContent.startsWith('data:image');
  final contentIsVideoJson = displayContent.trim().startsWith('{') && displayContent.contains('"videos"');
  final shouldHideContent = (hasGeneratedImage && (contentIsBase64 || displayContent.trim().isEmpty)) || (hasGeneratedVideo && (contentIsVideoJson || displayContent.trim().isEmpty));
  final parsedContent = !shouldHideContent ? _parseContentWithTable(displayContent) : null;
  
  return MouseRegion(
    onEnter: (_) => setState(() => _hoveredMessageId = message.id),
    onExit: (_) => setState(() => _hoveredMessageId = null),
    child: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: const Color(0xFF2A3446),
              child: const Text('🌎', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? _primaryColor : const Color(0xFF252D3D),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.generatedImageData != null) ...[
                        GestureDetector(
                          onTap: () => _showImagePopup(message.generatedImageData!, isBase64: true),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 256,
                                  height: 256,
                                  child: _buildImageWidget(message.generatedImageData!),
                                ),
                              ),
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                                    ),
                                  ),
                                  child: const Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.zoom_in, color: Colors.white, size: 20),
                                          SizedBox(width: 4),
                                          Text('Nhấn để phóng to', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (displayVideoUrl != null) ...[
                        GestureDetector(
                          onTap: () => _showVideoPopup(displayVideoUrl!),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 256,
                                  height: 256,
                                  color: Colors.black,
                                  child: VideoThumbnail(videoUrl: displayVideoUrl),
                                ),
                              ),
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.videocam, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text('Nhấn để phát', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (!shouldHideContent && parsedContent != null) ...[
                        if (parsedContent['beforeTable'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildSelectableFormattedText(parsedContent['beforeTable'], isUser ? Colors.white : Colors.black87),
                          ),
                        if (parsedContent['tableRows'] != null)
                          _buildTable(parsedContent['tableRows']),
                        if (parsedContent['afterTable'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _buildSelectableFormattedText(parsedContent['afterTable'], isUser ? Colors.white : Colors.black87),
                          ),
                      ] else if (!shouldHideContent && displayContent.isNotEmpty) ...[
                        _buildSelectableFormattedText(displayContent, isUser ? Colors.white : Colors.black87),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isUser ? Colors.white.withOpacity(0.7) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isHovered && !shouldHideContent && displayContent.isNotEmpty)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _copyToClipboard(displayContent),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(Icons.copy, size: 16, color: isUser ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.tealAccent[100],
              child: Text(_userAvatarEmoji.isNotEmpty ? _userAvatarEmoji : '🐙', style: const TextStyle(fontSize: 24)),
            ),
          ],
        ],
      ),
    ),
  );
}
  Map<String, dynamic> _extractVideoFromContent(String content) {
    String? videoUrl;
    String cleanContent = content;
    
    if (content.contains('{"videos":')) {
      try {
        final startIndex = content.indexOf('{"videos":');
        int braceCount = 0;
        int endIndex = startIndex;
        bool inString = false;
        for (int i = startIndex; i < content.length; i++) {
          final char = content[i];
          
          if (char == '"' && (i == 0 || content[i-1] != '\\')) {
            inString = !inString;
          }
          if (!inString) {
            if (char == '{') braceCount++;
            if (char == '}') {
              braceCount--;
              if (braceCount == 0) {
                endIndex = i + 1;
                break;
              }
            }
          }
        }
        if (endIndex > startIndex) {
          final videoJsonStr = content.substring(startIndex, endIndex);
          final videoData = json.decode(videoJsonStr);
          
          if (videoData['videos'] != null && videoData['videos'] is List) {
            final videos = videoData['videos'] as List;
            if (videos.isNotEmpty) {
              videoUrl = videos[0].toString();
                if (videoUrl!.startsWith('gs://')) {
                videoUrl = videoUrl.replaceFirst(
                  'gs://',
                  'https://storage.googleapis.com/',
                );
              }
             cleanContent = content.substring(0, startIndex) + 
            content.substring(endIndex);
              cleanContent = cleanContent.trim();
            }
          }
        }
      } catch (e) {
        print('Error extracting video from content: $e');
      }
    }
    return {
      'videoUrl': videoUrl,
      'cleanContent': cleanContent,
    };
  }
  Widget _buildMessage(ChatMessage message) {
  final isUser = message.role == 'user';
  final isHovered = _hoveredMessageId == message.id;
  String? displayVideoUrl = message.generatedVideoUrl;
  String displayContent = message.content;
  
  if (displayVideoUrl == null && message.content.contains('{"videos":')) {
    final extractedData = _extractVideoFromContent(message.content);
    displayVideoUrl = extractedData['videoUrl'];
    displayContent = extractedData['cleanContent'];
  }
  
  final hasGeneratedImage = message.generatedImageData != null;
  final hasGeneratedVideo = displayVideoUrl != null;
  final contentIsBase64 = displayContent.toLowerCase().contains('base64') || displayContent.startsWith('data:image');
  final contentIsVideoJson = displayContent.trim().startsWith('{') && displayContent.contains('"videos"');
  final shouldHideContent = (hasGeneratedImage && (contentIsBase64 || displayContent.trim().isEmpty)) || (hasGeneratedVideo && (contentIsVideoJson || displayContent.trim().isEmpty));
  final parsedContent = !shouldHideContent ? _parseContentWithTable(displayContent) : null;
  
  return MouseRegion(
    onEnter: (_) => setState(() => _hoveredMessageId = message.id),
    onExit: (_) => setState(() => _hoveredMessageId = null),
    child: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: const Color(0xFFFFCA28),
              child: const Text('🌎', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? _primaryColor : const Color(0xFFE1F5FE),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.generatedImageData != null) ...[
                        GestureDetector(
                          onTap: () => _showImagePopup(message.generatedImageData!, isBase64: true),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 256,
                                  height: 256,
                                  child: _buildImageWidget(message.generatedImageData!),
                                ),
                              ),
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                                    ),
                                  ),
                                  child: const Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.zoom_in, color: Colors.white, size: 20),
                                          SizedBox(width: 4),
                                          Text('Nhấn để phóng to', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (displayVideoUrl != null) ...[
                        GestureDetector(
                          onTap: () => _showVideoPopup(displayVideoUrl!),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 256,
                                  height: 256,
                                  color: Colors.black,
                                  child: VideoThumbnail(videoUrl: displayVideoUrl),
                                ),
                              ),
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.videocam, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text('Nhấn để phát', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (message.attachedFiles != null && message.attachedFiles!.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: message.attachedFiles!.map((filePath) {
                            final file = File(filePath);
                            if (!file.existsSync()) return const SizedBox.shrink();
                            
                            final ext = filePath.split('.').last.toLowerCase();
                            final fileName = file.path.split('/').last;
                            final isImage = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
                            final isVideo = ['mp4', 'mpeg', 'webm', 'mov'].contains(ext);
                            
                            return GestureDetector(
                              onTap: () {
                                if (isImage) {
                                  _showImagePopup(filePath, isBase64: false);
                                } else if (isVideo) {
                                  _showVideoPopup(filePath);
                                }
                              },
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade400),
                                ),
                                child: isImage
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(file, fit: BoxFit.cover),
                                      )
                                    : isVideo
                                        ? Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  color: Colors.black,
                                                  child: VideoThumbnail(videoUrl: filePath),
                                                ),
                                              ),
                                              Center(
                                                child: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.6),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(DocumentConverter.getFileIcon(ext), style: const TextStyle(fontSize: 32)),
                                              const SizedBox(height: 4),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                                child: Text(fileName, style: const TextStyle(fontSize: 9), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                                              ),
                                            ],
                                          ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (!shouldHideContent && parsedContent != null) ...[
                        if (parsedContent['beforeTable'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildSelectableFormattedText(parsedContent['beforeTable'], isUser ? Colors.white : Colors.black87),
                          ),
                        if (parsedContent['tableRows'] != null)
                          _buildTable(parsedContent['tableRows']),
                        if (parsedContent['afterTable'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _buildSelectableFormattedText(parsedContent['afterTable'], isUser ? Colors.white : Colors.black87),
                          ),
                      ] else if (!shouldHideContent && displayContent.isNotEmpty) ...[
                        _buildSelectableFormattedText(displayContent, isUser ? Colors.white : Colors.black87),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isUser ? Colors.white.withOpacity(0.7) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isHovered && !shouldHideContent && displayContent.isNotEmpty)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _copyToClipboard(displayContent),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(Icons.copy, size: 16, color: isUser ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.tealAccent[100],
              child: Text(_userAvatarEmoji.isNotEmpty ? _userAvatarEmoji : '🐙', style: const TextStyle(fontSize: 24)),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildStreamingMessage() {
  final shouldParseTable = _currentStreamingMessage.contains('|') && (_currentStreamingMessage.endsWith('\n') || _currentStreamingMessage.split('\n').where((l) => l.contains('|')).length > 2);
  final parsedContent = shouldParseTable ? _parseContentWithTable(_currentStreamingMessage) : null;
  final hasImage = _currentStreamingImage != null;
  final hasVideo = _currentStreamingVideo != null;
  final contentIsBase64 = _currentStreamingMessage.toLowerCase().contains('base64') || _currentStreamingMessage.startsWith('data:image');
  final contentIsVideoJson = _currentStreamingMessage.trim().startsWith('{') && _currentStreamingMessage.contains('"videos"');
  final shouldHideContent = (hasImage && (contentIsBase64 || _currentStreamingMessage.trim().isEmpty)) || (hasVideo && (contentIsVideoJson || _currentStreamingMessage.trim().isEmpty));
  
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFF2A3446),
          child: const Text('🌎', style: TextStyle(fontSize: 24)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF252D3D),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_currentStreamingImage != null) ...[
                  GestureDetector(
                    onTap: () => _showImagePopup(_currentStreamingImage!, isBase64: true),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 256,
                            height: 256,
                            child: _buildImageWidget(_currentStreamingImage!),
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                              ),
                            ),
                            child: const Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.zoom_in, color: Colors.white, size: 20),
                                    SizedBox(width: 4),
                                    Text('Nhấn để phóng to', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_currentStreamingVideo != null) ...[
                  GestureDetector(
                    onTap: () => _showVideoPopup(_currentStreamingVideo!),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 256,
                            height: 256,
                            color: Colors.black,
                            child: VideoThumbnail(videoUrl: _currentStreamingVideo!),
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                              ),
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.videocam, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text('Nhấn để phát', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_currentStreamingMessage.isEmpty && _currentStreamingImage == null && _currentStreamingVideo == null)
                  SpinKitThreeBounce(color: _primaryColor, size: 20)
                else if (!shouldHideContent && _currentStreamingMessage.isNotEmpty) ...[
                  if (parsedContent != null && parsedContent['tableRows'] != null) ...[
                    if (parsedContent['beforeTable'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildFormattedText(parsedContent['beforeTable'], Colors.teal.shade50),
                      ),
                    if ((parsedContent['tableRows'] as List).length > 1)
                      _buildTable(parsedContent['tableRows']),
                    if (parsedContent['afterTable'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _buildFormattedText(parsedContent['afterTable'], Colors.teal.shade50),
                      ),
                  ] else
                    _buildFormattedText(_currentStreamingMessage, Colors.teal.shade50),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildImageWidget(String imageData) {
  try {
    Uint8List bytes;
    
    if (imageData.startsWith('data:image')) {
      final parts = imageData.split(',');
      if (parts.length < 2) {
        throw Exception('Invalid data URL format');
      }
      bytes = base64Decode(parts[1]);
    } else if (imageData.contains(',')) {
      final parts = imageData.split(',');
      bytes = base64Decode(parts[1]);
    } else {
      bytes = base64Decode(imageData);
    }
    
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          padding: const EdgeInsets.all(8),
          color: Colors.red[100],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red),
              const SizedBox(height: 4),
              Text('Không thể hiển thị ảnh', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
            ],
          ),
        );
      },
    );
  } catch (e) {
    print('Image decode error: $e');
    print('Image data preview: ${imageData.substring(0, min(100, imageData.length))}');
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.orange[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_not_supported, color: Colors.orange),
          const SizedBox(height: 4),
          Text('Định dạng ảnh không hợp lệ', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('$e', style: const TextStyle(fontSize: 9, color: Colors.grey), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
  Widget _buildFormattedText(String text, Color color) {
    final List<TextSpan> spans = [];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Check for markdown headers (2-5 #)
      final headerMatch = RegExp(r'^(#{2,5})\s+(.*)$').firstMatch(line);
      if (headerMatch != null) {
        final hashCount = headerMatch.group(1)!.length;
        final headerText = headerMatch.group(2)!;

        // Calculate font size increase: 2# -> +2, 3# -> +4, 4# -> +6, 5# -> +8
        final sizeIncrease = (hashCount - 1) * 2.0;

        spans.add(TextSpan(
          text: headerText,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14 + sizeIncrease,
          ),
        ));
      } else {
        // Process bold patterns **text**
        final RegExp boldPattern = RegExp(r'\*\*(.*?)\*\*');
        int lastIndex = 0;
        for (final match in boldPattern.allMatches(line)) {
          if (match.start > lastIndex) {
            spans.add(TextSpan(
              text: line.substring(lastIndex, match.start),
              style: TextStyle(color: color),
            ));
          }
          spans.add(TextSpan(
            text: match.group(1),
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ));
          lastIndex = match.end;
        }
        if (lastIndex < line.length) {
          spans.add(TextSpan(
            text: line.substring(lastIndex),
            style: TextStyle(color: color),
          ));
        }
      }

      // Add newline between lines (except for the last line)
      if (i < lines.length - 1) {
        spans.add(TextSpan(
          text: '\n',
          style: TextStyle(color: color),
        ));
      }
    }

    return RichText(text: TextSpan(children: spans));
  }
  Widget _buildSelectableFormattedText(String text, Color color) {
    final List<TextSpan> spans = [];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Check for markdown headers (2-5 #)
      final headerMatch = RegExp(r'^(#{2,5})\s+(.*)$').firstMatch(line);
      if (headerMatch != null) {
        final hashCount = headerMatch.group(1)!.length;
        final headerText = headerMatch.group(2)!;

        // Calculate font size increase: 2# -> +2, 3# -> +4, 4# -> +6, 5# -> +8
        final sizeIncrease = (hashCount - 1) * 2.0;

        spans.add(TextSpan(
          text: headerText,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14 + sizeIncrease,
          ),
        ));
      } else {
        // Process bold patterns **text**
        final RegExp boldPattern = RegExp(r'\*\*(.*?)\*\*');
        int lastIndex = 0;
        for (final match in boldPattern.allMatches(line)) {
          if (match.start > lastIndex) {
            spans.add(TextSpan(
              text: line.substring(lastIndex, match.start),
              style: TextStyle(color: color),
            ));
          }
          spans.add(TextSpan(
            text: match.group(1),
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ));
          lastIndex = match.end;
        }
        if (lastIndex < line.length) {
          spans.add(TextSpan(
            text: line.substring(lastIndex),
            style: TextStyle(color: color),
          ));
        }
      }

      // Add newline between lines (except for the last line)
      if (i < lines.length - 1) {
        spans.add(TextSpan(
          text: '\n',
          style: TextStyle(color: color),
        ));
      }
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: TextStyle(color: color),
    );
  }
  Widget _buildInputArea() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.blueGrey[800],
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 4,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedFiles.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            constraints: const BoxConstraints(maxHeight: 100),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedFiles.length,
              itemBuilder: (context, index) {
                final file = _selectedFiles[index];
                final ext = file.path.split('.').last.toLowerCase();
                final fileName = file.path.split('/').last;
                
                return Container(
                  margin: const EdgeInsets.only(right: 4),
                  width: 70,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[700],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _primaryColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DocumentConverter.getFileIcon(ext),
                            style: const TextStyle(fontSize: 20),
                          ),
                          GestureDetector(
                            onTap: () => _removeFile(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.8),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          fileName,
                          style: const TextStyle(fontSize: 9, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 3,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        Row(
          children: [
            if (_selectedCaseType != null && _caseFileData != null)
              Container(
                decoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                child: IconButton(
                  icon: _isStreaming
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  onPressed: _isStreaming ? null : _sendMessage,
                  color: Colors.white,
                  tooltip: 'Gửi với dữ liệu $_selectedCaseType',
                ),
              )
            else
              Container(
                decoration: BoxDecoration(color: _primaryColor, shape: BoxShape.circle),
                child: IconButton(
                  icon: _isStreaming
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send),
                  onPressed: _isStreaming ? null : _sendMessage,
                  color: Colors.white,
                ),
              ),
            const SizedBox(width: 4),
            if (_selectedCaseType != null && _isCaseFileLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (_selectedCaseType != null && _caseFileData != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.description, color: Colors.orange, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      _selectedCaseType!,
                      style: const TextStyle(color: Colors.orange, fontSize: 10),
                    ),
                    const SizedBox(width: 3),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCaseType = null;
                          _caseFileData = null;
                          _selectedCaseDate = DateTime.now();
                        });
                      },
                      child: const Icon(Icons.close, color: Colors.orange, size: 12),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                _selectedFiles.length >= _maxFiles ? Icons.block : (_mode == 'image' ? Icons.image : Icons.attach_file),
                color: _selectedFiles.length >= _maxFiles ? Colors.red : Colors.white,
                size: 20,
              ),
              padding: const EdgeInsets.all(8),
              onPressed: _isStreaming || _selectedFiles.length >= _maxFiles ? null : _pickFiles,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  TextField(
                    controller: _messageController,
                    enabled: !_isStreaming,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(color: Colors.amber, fontSize: 14),
                    cursorColor: Colors.lightGreenAccent,
                    decoration: InputDecoration(
                      hintText: _selectedFiles.isEmpty 
                          ? (_mode == 'text' ? 'Tin nhắn...' : 'Mô tả ảnh...') 
                          : '${_selectedFiles.length}/$_maxFiles files',
                      hintStyle: TextStyle(color: Colors.blueGrey[300], fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.blueGrey[700],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                  Positioned(
                    top: -16,
                    left: 4,
                    child: Builder(
                      builder: (context) {
                        final inputText = _messageController.text;
                        final inputWords = inputText.trim().isEmpty ? 0 : inputText.trim().split(RegExp(r'\s+')).length;
                        final inputChars = inputText.length;
                        
                        String systemPrompt = _getSystemPrompt(_selectedModel);
                        if (_selectedCaseType != null) {
                          systemPrompt = CaseFileManager.getCustomPrompt(_selectedCaseType!);
                        }
                        
                        String contextString = '';
                        if (_currentSession != null && _currentSession!.messages.isNotEmpty) {
                          final recentMessages = _currentSession!.messages.length > 17
                              ? _currentSession!.messages.sublist(_currentSession!.messages.length - 17, _currentSession!.messages.length - 1)
                              : _currentSession!.messages.sublist(0, max(0, _currentSession!.messages.length - 1));
                          if (recentMessages.isNotEmpty) {
                            contextString = '\n\nĐoạn hội thoại trước:\n';
                            for (var msg in recentMessages) {
                              final role = msg.role == 'user' ? 'Người dùng' : 'AI';
                              contextString += '$role: ${msg.content}\n';
                            }
                            contextString += '\nTin nhắn hiện tại:\n';
                          }
                        }
                        
                        final systemWords = systemPrompt.trim().isEmpty ? 0 : systemPrompt.trim().split(RegExp(r'\s+')).length;
                        final systemChars = systemPrompt.length;
                        final contextWords = contextString.trim().isEmpty ? 0 : contextString.trim().split(RegExp(r'\s+')).length;
                        final contextChars = contextString.length;
                        final totalWords = inputWords + systemWords + contextWords;
                        final totalChars = inputChars + systemChars + contextChars;
                        
                        return Text(
                          'Input:${inputWords}w/${inputChars}c##System:${systemWords}w/${systemChars}c##Context:${contextWords}w/${contextChars}c##Total:${totalWords}w/${totalChars}c',
                          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _AvatarVideoPlayer(state: _avatarState, videos: _avatarVideos),
          ],
        ),
        Row(
          children: [
            if (_mode == 'text') const SizedBox(width: 6),
            Expanded(
              flex: 3,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[700],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCaseType,
                    hint: const Text('Loại dữ liệu', style: TextStyle(color: Colors.amber, fontSize: 13)),
                    isExpanded: true,
                    isDense: true,
                    dropdownColor: Colors.blueGrey[700],
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: CaseFileManager.getCaseTypes().map((type) {
                      return DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(fontSize: 13)));
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCaseType = val;
                        _caseFileData = null;
                      });
                      if (val != null) _loadCaseFile();
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedCaseDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: _primaryColor,
                            onPrimary: Colors.white,
                            surface: Colors.blueGrey[700]!,
                            onSurface: Colors.white,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (date != null) {
                    setState(() {
                      _selectedCaseDate = date;
                      _caseFileData = null;
                    });
                    if (_selectedCaseType != null) _loadCaseFile();
                  }
                },
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[700],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd/MM/yy').format(_selectedCaseDate),
                        style: const TextStyle(color: Colors.amber, fontSize: 13),
                      ),
                      const Icon(Icons.calendar_today, color: Colors.white70, size: 14),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[700],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSpeaking ? Icons.volume_up : Icons.volume_down,
                      color: Colors.white70,
                      size: 24,
                    ),
                    SizedBox(
                      width: 210,
                      child: Slider(
                        value: _ttsVolume,
                        min: 0.0,
                        max: 1.05,
                        onChanged: _updateTtsVolume,
                        activeColor: _primaryColor,
                        inactiveColor: Colors.amber,
                      ),
                    ),
                    if (_isSpeaking)
                      GestureDetector(
                        onTap: _stopSpeaking,
                        child: const Icon(Icons.stop, color: Colors.red, size: 16),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
  Widget _buildCreditBalanceWidget() {
    if (_creditBalance == null) {
      return const SizedBox.shrink();
    }
    final percent = _creditBalance!.percentRemaining / 100;
    final isLow = _creditBalance!.percentRemaining < 20;
    final isMedium = _creditBalance!.percentRemaining < 50;
    Color barColor;
    if (isLow) {
      barColor = Colors.red;
    } else if (isMedium) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.green;
    }
    return MouseRegion(
      onEnter: (_) => setState(() {}),
      onExit: (_) => setState(() {}),
      child: Tooltip(
        message: '${_creditBalance!.currentToken.toStringAsFixed(0)} / ${_creditBalance!.startingToken.toStringAsFixed(0)} tokens',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hạn mức còn lại',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _refreshCreditBalance,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 20),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 14, color: _primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        'Làm mới',
                        style: TextStyle(fontSize: 11, color: _primaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percent.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_creditBalance!.percentRemaining.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: barColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(_creditBalance!.currentToken / 1000).toStringAsFixed(1)}k điểm',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return DateFormat('d/M').format(timestamp);
    }
  }
}
class CreditBalance {
  final double currentToken;
  final double startingToken;
  final double percentRemaining;
  final bool canUse;
  CreditBalance({
    required this.currentToken,
    required this.startingToken,
    required this.percentRemaining,
    required this.canUse,
  });
  factory CreditBalance.fromJson(Map<String, dynamic> json) {
    return CreditBalance(
      currentToken: (json['currentToken'] ?? 0).toDouble(),
      startingToken: (json['startingToken'] ?? 250000).toDouble(),
      percentRemaining: (json['percentRemaining'] ?? 100).toDouble(),
      canUse: json['canUse'] ?? true,
    );
  }
}
class ChatSession {
  final String id;
  String title;
  List<ChatMessage> messages;
  List<Map<String, dynamic>> history;
  final DateTime createdAt;
  DateTime lastUpdated;
  ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.history,
    required this.createdAt,
    required this.lastUpdated,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
    'history': history,
    'createdAt': createdAt.toIso8601String(),
    'lastUpdated': lastUpdated.toIso8601String(),
  };
  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'],
    title: json['title'],
    messages: (json['messages'] as List).map((m) => ChatMessage.fromJson(m)).toList(),
    history: List<Map<String, dynamic>>.from(json['history'] ?? []),
    createdAt: DateTime.parse(json['createdAt']),
    lastUpdated: DateTime.parse(json['lastUpdated']),
  );
}
class ChatMessage {
  final String id;
  final String role;
  final String content;
  final List<String>? attachedFiles;
  final String? generatedImageData;
  final String? generatedVideoUrl;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.attachedFiles,
    this.generatedImageData,
    this.generatedVideoUrl,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'content': content,
    'attachedFiles': attachedFiles,
    'generatedImageData': generatedImageData,
    'generatedVideoUrl': generatedVideoUrl,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    role: json['role'],
    content: json['content'],
    attachedFiles: json['attachedFiles'] != null ? List<String>.from(json['attachedFiles']) : null,
    generatedImageData: json['generatedImageData'],
    generatedVideoUrl: json['generatedVideoUrl'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}
class VideoThumbnail extends StatefulWidget {
  final String videoUrl;
  const VideoThumbnail({Key? key, required this.videoUrl}) : super(key: key);
  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      if (widget.videoUrl.startsWith('http')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      } else {
        _controller = VideoPlayerController.file(File(widget.videoUrl));
      }
      
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      print('Error initializing video thumbnail: $e');
      if (mounted) {
        setState(() {
          _error = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(
        color: Colors.grey[800],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 24),
              SizedBox(height: 4),
              Text(
                'Không thể tải video',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      );
    }
    
    if (!_initialized) {
      return Container(
        color: Colors.grey[800],
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }
    
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}
class VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;
  final Color primaryColor;
  final VoidCallback onSave;
  const VideoPlayerDialog({
    Key? key,
    required this.videoUrl,
    required this.primaryColor,
    required this.onSave,
  }) : super(key: key);
  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}
class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _error = false;
  bool _isPlaying = false;
  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }
  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller.initialize();
      _controller.addListener(() {
        if (mounted) {
          setState(() {
            _isPlaying = _controller.value.isPlaying;
          });
        }
      });
      if (mounted) {
        setState(() {
          _initialized = true;
        });
        _controller.play();
      }
    } catch (e) {
      print('Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _error = true;
        });
      }
    }
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Video',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onSave();
                        },
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Lưu video'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: Container(
                color: Colors.black,
                child: _error
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: Colors.white, size: 64),
                            SizedBox(height: 16),
                            Text(
                              'Không thể phát video',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : !_initialized
                        ? const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          )
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              AspectRatio(
                                aspectRatio: _controller.value.aspectRatio,
                                child: VideoPlayer(_controller),
                              ),
                              GestureDetector(
                                onTap: _togglePlayPause,
                                child: Container(
                                  color: Colors.transparent,
                                  child: Center(
                                    child: AnimatedOpacity(
                                      opacity: _isPlaying ? 0.0 : 1.0,
                                      duration: const Duration(milliseconds: 200),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _isPlaying ? Icons.pause : Icons.play_arrow,
                                          color: Colors.white,
                                          size: 64,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.7),
                                      ],
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      VideoProgressIndicator(
                                        _controller,
                                        allowScrubbing: true,
                                        colors: VideoProgressColors(
                                          playedColor: widget.primaryColor,
                                          bufferedColor: Colors.grey,
                                          backgroundColor: Colors.grey.shade800,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              _isPlaying ? Icons.pause : Icons.play_arrow,
                                              color: Colors.white,
                                            ),
                                            onPressed: _togglePlayPause,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}',
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                          const Spacer(),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _AvatarVideoPlayer extends StatefulWidget {
  final AvatarState state;
  final Map<AvatarState, List<String>> videos;

  const _AvatarVideoPlayer({
    required this.state,
    required this.videos,
  });

  @override
  State<_AvatarVideoPlayer> createState() => _AvatarVideoPlayerState();
}

class _AvatarVideoPlayerState extends State<_AvatarVideoPlayer> with SingleTickerProviderStateMixin {
  Player? _player;
  VideoController? _videoController;
  AvatarState? _currentState;
  String? _currentVideo;
  String _currentBubbleText = '';
  late AnimationController _dotAnimationController;
  late Animation<int> _dotAnimation;

  final Map<AvatarState, List<String>> _bubbleTexts = {
    AvatarState.hello: ['Xin chào!', 'Bạn muốn hỏi gì?', 'Chào bạn!', 'Tôi có thể giúp gì?'],
    AvatarState.listening: ['Bạn có thể thêm ảnh', 'Có thể đính kèm file', 'Thêm file nếu muốn'],
    AvatarState.thinking: ['🤔...'],
    AvatarState.speaking: ['💭...', '📢...'],
    AvatarState.congrat: ['❤️', '💙', '💚', '💛'],
    AvatarState.idle: ['Bạn có thể chuyển sang chế độ tạo ảnh', 'Tôi có thể giúp bạn tạo video!', 'Bạn muốn biết gì nào?'],
  };

  @override
  void initState() {
    super.initState();
    _dotAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _dotAnimation = IntTween(begin: 0, end: 3).animate(_dotAnimationController);
    _initializeVideo();
  }

  @override
  void didUpdateWidget(_AvatarVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _initializeVideo();
      _updateBubbleText();
    }
  }

  void _updateBubbleText() {
    final texts = _bubbleTexts[widget.state] ?? [];
    setState(() {
      _currentBubbleText = texts.isNotEmpty ? texts[Random().nextInt(texts.length)] : '';
    });
  }

  Future<void> _initializeVideo() async {
    final videos = widget.videos[widget.state] ?? widget.videos[AvatarState.idle]!;
    final randomVideo = videos[Random().nextInt(videos.length)];

    if (_currentVideo == randomVideo && _currentState == widget.state) return;

    _currentState = widget.state;
    _currentVideo = randomVideo;
    _updateBubbleText();

    await _player?.dispose();

    final player = Player();
    final controller = VideoController(player);

    setState(() {
      _player = player;
      _videoController = controller;
    });

    try {
      await player.open(
        Media('asset://assets/aivideo/$randomVideo'),
        play: true,
      );
      player.setPlaylistMode(PlaylistMode.loop);
    } catch (e) {
      print('Error initializing media_kit video: $e');
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    _dotAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final size = (screenWidth * 0.09).clamp(20.0, 160.0);

    return SizedBox(
      width: size * 1.8,
      height: size,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          if (_currentBubbleText.isNotEmpty)
            Positioned(
              left: 10,
              bottom: size * 0.33,
              child: Container(
                constraints: BoxConstraints(maxWidth: size * 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3446),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
                ),
                child: widget.state == AvatarState.thinking || widget.state == AvatarState.speaking
                    ? AnimatedBuilder(
                        animation: _dotAnimation,
                        builder: (context, child) {
                          final dots = '.' * (_dotAnimation.value + 1);
                          return Text(
                            dots,
                            style: const TextStyle(
                              color: Colors.teal,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      )
                    : Text(
                        _currentBubbleText,
                        style: const TextStyle(
                          color: Colors.teal,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          Positioned(
            right: 0,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF00D9FF), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D9FF).withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: _videoController != null
                    ? Video(controller: _videoController!)
                    : Container(
                        color: Colors.grey.shade800,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}