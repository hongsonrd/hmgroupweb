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
class ChatAIScreen extends StatefulWidget {
  const ChatAIScreen({Key? key}) : super(key: key);

  @override
  State<ChatAIScreen> createState() => _ChatAIScreenState();
}

class _ChatAIScreenState extends State<ChatAIScreen> with SingleTickerProviderStateMixin {
  String _username = '';
  final String _apiBaseUrl = 'https://hmbeacon-81200125587.asia-east2.run.app';
  
  List<ChatSession> _sessions = [];
  ChatSession? _currentSession;
  List<ChatMessage> _messages = [];
  
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final ScrollController _sessionScrollController = ScrollController();
  
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  
  bool _isStreaming = false;
  String _currentStreamingMessage = '';
  String? _currentStreamingImage;
  String? _currentStreamingVideo;
  
  String _selectedModel = 'flash-2.5';
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
  
  final Map<String, List<Map<String, dynamic>>> _models = {
    'fast': [
      {'value': 'flash-2.5-lite', 'name': 'Cá kiếm', 'cost': 16, 'rating': 3, 'systemPrompt': 'Ưu tiên tiếng việt,tìm kiếm nguồn từ google nếu cần,bạn là chuyên gia ngành vệ sinh công nghiệp có ứng dụng robot, AI,công nghệ trong dịch vụ,quản lý tập đoàn,chất lượng,hiệu quả,kinh nghiệm hàng đầu tại Việt Nam,đến từ Hoàn Mỹ Group chuyên làm sạch toà nhà văn phòng,chung cư,nhà máy,bệnh viện,bến xe,sân bay.Khi đánh giá,sử dụng thang điểm /10 để đảm bảo tính dễ hiểu,trực quan.Đảm bảo trả lời:Đánh giá,Lỗi,Khắc phục bằng hoá chất/máy móc/phương pháp/công cụ,Cảnh báo nếu là về vấn đề vệ sinh:'},
    ],
    'precise': [
      {'value': 'flash-2.5', 'name': 'Cá mập trắng', 'cost': 100, 'rating': 4, 'systemPrompt': 'Ưu tiên tiếng việt,dùng bảng cho so sánh chỉ khi cần thiết,tìm kiếm nguồn từ google nếu cần,bạn là chuyên gia ngành vệ sinh công nghiệp có ứng dụng robot, AI,công nghệ trong dịch vụ,quản lý tập đoàn,chất lượng,hiệu quả,kinh nghiệm hàng đầu tại Việt Nam,đến từ Hoàn Mỹ Group chuyên làm sạch toà nhà văn phòng,chung cư,nhà máy,bệnh viện,bến xe,sân bay.Khi đánh giá,sử dụng thang điểm /10 để đảm bảo tính dễ hiểu,trực quan.Đưa ra các lựa chọn,giải quyết nếu hiện trạng chưa đạt tối ưu,chú ý đến mức độ cơ sở vật chất hiện có thường sẽ cũ hơn trên ảnh.trả lời nhanh,thỉnh thoáng dùng emoji để trang trí phù hợp.Đảm bảo trả lời:Đánh giá,Lỗi,Khắc phục bằng hoá chất/máy móc/phương pháp/công cụ,Cảnh báo nếu là về vấn đề vệ sinh:'},
      {'value': 'flash-2.5-pro', 'name': 'Cá voi sát thủ', 'cost': 302, 'rating': 4, 'systemPrompt': 'Ưu tiên tiếng việt,dùng bảng cho so sánh chỉ khi cần thiết,tìm kiếm nguồn từ google nếu cần,bạn là chuyên gia ngành vệ sinh công nghiệp có ứng dụng robot, AI,công nghệ trong dịch vụ,quản lý tập đoàn,chất lượng,hiệu quả,kinh nghiệm hàng đầu tại Việt Nam,đến từ Hoàn Mỹ Group chuyên làm sạch toà nhà văn phòng,chung cư,nhà máy,bệnh viện,bến xe,sân bay.Khi đánh giá,sử dụng thang điểm /10 để đảm bảo tính dễ hiểu,trực quan.Đưa ra các lựa chọn,giải quyết nếu hiện trạng chưa đạt tối ưu,chú ý đến mức độ cơ sở vật chất hiện có thường sẽ cũ hơn trên ảnh,thỉnh thoáng dùng emoji để trang trí phù hợp.Đảm bảo trả lời:Đánh giá,Lỗi,Khắc phục bằng hoá chất/máy móc/phương pháp/công cụ,Cảnh báo nếu là về vấn đề vệ sinh:'},
    ],
    'image': [
      {'value': 'imagen-4', 'name': 'Cá heo', 'cost': 1500, 'rating': 3, 'systemPrompt': 'Không chỉ tạo ảnh với chữ, phải tạo hình ảnh thiết kế:'},
      {'value': 'veo-3.0-fast', 'name': 'Cá đuối', 'cost': 3800, 'rating': 4, 'systemPrompt': 'Tạo video dọc 9:16, 6s trừ khi user yêu cầu khác sau đây:'},
      {'value': 'veo-3.0', 'name': 'Cá voi xanh', 'cost': 6000, 'rating': 5, 'systemPrompt': 'Tạo video ngang 9:16, 6s trừ khi user yêu cầu khác sau đây:'},
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
    _loadUserData();
    _loadSessions();
    _loadCreditBalance();
    
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_gradientController);
    
    final avatarEmojis = ['🐙', '🦑', '🦐', '🦞', '🦀', '🪼', '🐡', '🐠', '🐟', '🐬', '🐳', '🐋', '🦈'];
    _userAvatarEmoji = avatarEmojis[Random().nextInt(avatarEmojis.length)];
    
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _chatScrollController.dispose();
    _sessionScrollController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

void _onTextChanged() {
  final currentText = _messageController.text;
  // Check if text ends with two consecutive newlines
  if (currentText.endsWith('\n\n')) {
    // Remove the double newlines and send
    final textToSend = currentText.substring(0, currentText.length - 2).trim();
    if (textToSend.isNotEmpty) {
      // Set the text without the newlines, then send
      _messageController.text = textToSend;
      _sendMessage();
      // Clear after sending
      _messageController.clear();
    } else {
      // If the text was just newlines, clear it
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
      ).timeout(const Duration(seconds: 10));

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
                  // Header with close and save buttons
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
                  // Image
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: isBase64
                          ? Image.memory(
                              base64Decode(imageData.split(',')[1]),
                              fit: BoxFit.contain,
                            )
                          : Image.file(
                              File(imageData),
                              fit: BoxFit.contain,
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
      final bytes = base64Decode(imageData.split(',')[1]);
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

void _showVideoPopup(String videoUrl) {
  showDialog(
    context: context,
    builder: (context) => VideoPlayerDialog(
      videoUrl: videoUrl,
      primaryColor: _primaryColor,
      onSave: () => _saveVideoToDevice(videoUrl),
    ),
  );
}

Future<void> _saveVideoToDevice(String videoUrl) async {
  try {
    // Show loading dialog
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

    // Download video
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
      
      // Close loading dialog
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
      Navigator.pop(context); // Close loading dialog if still open
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

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showError('Không thể chọn ảnh: $e');
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == 'text' ? 'image' : 'text';
      if (_mode == 'image') {
        _selectedModel = 'imagen-4'; // UPDATED: use imagen-4 instead of flash-image
      } else {
        _selectedModel = 'flash-2.5';
      }
    });
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
                          _selectedModel = 'flash-2.5';
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
                                        (index) => const Icon(Icons.star, size: 12, color: Colors.amber),
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
Future<void> _sendMessage() async {
  if (_username.isEmpty) {
    _showError('Chưa đăng nhập');
    return;
  }

  final messageText = _messageController.text.trim();
  if (messageText.isEmpty && _selectedImage == null) {
    return;
  }

  if (_creditBalance != null && !_creditBalance!.canUse) {
    _showError('Bạn đã hết credit cho tháng này. Vui lòng chờ đến tháng sau.');
    return;
  }

  if (_currentSession == null) {
    _createNewSession();
  }

  final userMessage = ChatMessage(
    id: const Uuid().v4(),
    role: 'user',
    content: messageText,
    imagePath: _selectedImage?.path,
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

  if (_currentSession!.messages.length == 1) {
    _currentSession!.title = messageText.length > 30 
        ? '${messageText.substring(0, 30)}...' 
        : messageText;
  }

  _messageController.clear();
  final imageFile = _selectedImage;
  _selectedImage = null;

  _scrollToBottom();

  try {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_apiBaseUrl/aichat'),
    );

    final systemPrompt = _getSystemPrompt(_selectedModel);
    
    // Build context from last 6 messages (excluding the current one)
    String contextString = '';
    final recentMessages = _currentSession!.messages.length > 7
        ? _currentSession!.messages.sublist(_currentSession!.messages.length - 7, _currentSession!.messages.length - 1)
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
        ? '$systemPrompt$contextString$messageText' 
        : '$contextString$messageText';

    request.fields['userid'] = _username;
    request.fields['model'] = _selectedModel;
    request.fields['mode'] = _mode;
    request.fields['query'] = fullQuery;
    request.fields['history'] = json.encode(_currentSession!.history);
    
    if (_mode == 'image') {
      request.fields['ratio'] = _imageRatio;
    }

    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
    }

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        throw TimeoutException('Hết thời gian chờ');
      },
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
                  final content = data['content'];
                  
                  // Add to accumulated response first
                  accumulatedResponse += content;
                  
                  // Check if accumulated response contains video JSON
                  if (accumulatedResponse.contains('{"videos":')) {
                    try {
                      // Find the start of the JSON
                      final startIndex = accumulatedResponse.indexOf('{"videos":');
                      // Find the end of the JSON (look for closing brace)
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
                            
                            // Convert gs:// to https:// URL
                            if (videoUrl.startsWith('gs://')) {
                              videoUrl = videoUrl.replaceFirst(
                                'gs://',
                                'https://storage.googleapis.com/',
                              );
                            }
                            
                            // Remove the video JSON from the accumulated response
                            accumulatedResponse = accumulatedResponse.substring(0, startIndex) + 
                                                 accumulatedResponse.substring(endIndex);
                            
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
                  
                  // Normal text handling
                  setState(() {
                    _currentStreamingMessage = accumulatedResponse;
                  });
                  _scrollToBottom();
                  break;
                
                case 'image':
                  setState(() {
                    _currentStreamingImage = data['content']; 
                  });
                  _scrollToBottom();
                  break;
                
                case 'video':
                  // Parse video response: {"videos": ["gs://..."], ...}
                  String? videoUrl;
                  if (data['content'] is String) {
                    videoUrl = data['content'];
                  } else if (data['content'] is Map && data['content']['videos'] != null) {
                    final videos = data['content']['videos'] as List;
                    if (videos.isNotEmpty) {
                      videoUrl = videos[0].toString();
                    }
                  }
                  
                  // Convert gs:// to https:// URL
                  if (videoUrl != null && videoUrl.startsWith('gs://')) {
                    videoUrl = videoUrl.replaceFirst(
                      'gs://',
                      'https://storage.googleapis.com/',
                    );
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
                  
                  // Check if fullResponse contains video JSON and extract it
                  if (messageContent.contains('{"videos":')) {
                    try {
                      // Find the start of the JSON
                      final startIndex = messageContent.indexOf('{"videos":');
                      // Find the end of the JSON (look for closing brace)
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
                            
                            // Convert gs:// to https:// URL
                            if (videoUrl!.startsWith('gs://')) {
                              videoUrl = videoUrl.replaceFirst(
                                'gs://',
                                'https://storage.googleapis.com/',
                              );
                            }
                            
                            // Remove the video JSON from message content
                            messageContent = messageContent.substring(0, startIndex) + 
                                           messageContent.substring(endIndex);
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
                  
                  if (data['updatedHistory'] != null) {
                    _currentSession!.history = List<Map<String, dynamic>>.from(
                      data['updatedHistory']
                    );
                  }
                  
                  _currentSession!.lastUpdated = DateTime.now();
                  _saveSessions();
                  _scrollToBottom();
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
    }
  } catch (e) {
    _showError('Không thể gửi tin: $e');
    setState(() {
      _isStreaming = false;
      _currentStreamingMessage = '';
      _currentStreamingImage = null; 
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
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
                      _mode == 'text' ? 'Trò chuyện AI' : 'Tạo hình ảnh AI',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      body: Row(
        children: [
          if (_sidebarVisible)
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
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
                      color: _lightPrimaryColor,
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
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
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showModelSelector(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _primaryColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getModelName(_selectedModel),
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _primaryColor),
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
                                color: isActive ? _lightPrimaryColor : Colors.transparent,
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
                                    color: isActive ? _primaryColor : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  _formatTimestamp(session.lastUpdated),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
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
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _mode == 'text' 
                                    ? 'Chọn hoặc tạo cuộc trò chuyện mới'
                                    : 'Tạo cuộc trò chuyện mới để tạo hình ảnh',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
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
    );
  }
List<List<String>>? _parseMarkdownTable(String text) {
  final lines = text.split('\n');
  List<List<String>> rows = [];
  for (var line in lines) {
    if (line.trim().isEmpty) continue;
    if (line.contains('|')) {
      // Skip separator lines like |---|---|
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
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Table(
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
        verticalInside: BorderSide(color: Colors.grey.shade300),
      ),
      columnWidths: columnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: normalizedRows.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;
        final isHeader = index == 0;
        return TableRow(
          decoration: BoxDecoration(
            color: isHeader ? Colors.grey.shade100 : Colors.white,
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
                  color: Colors.black87,
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
              backgroundColor: Colors.amber,
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
                    color: isUser ? _primaryColor : Colors.white,
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
                                  child: Image.memory(
                                    base64Decode(message.generatedImageData!.split(',')[1]),
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
                                            Text(
                                              'Không thể hiển thị ảnh',
                                              style: const TextStyle(fontSize: 12),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.3),
                                      ],
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
        // Find the start of the JSON
        final startIndex = content.indexOf('{"videos":');
        // Find the end of the JSON (look for closing brace)
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
              
              // Convert gs:// to https:// URL
              if (videoUrl!.startsWith('gs://')) {
                videoUrl = videoUrl.replaceFirst(
                  'gs://',
                  'https://storage.googleapis.com/',
                );
              }
              
              // Remove the video JSON from content
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
  
  // Extract video URL from content if it exists
  String? displayVideoUrl = message.generatedVideoUrl;
  String displayContent = message.content;
  
  if (displayVideoUrl == null && message.content.contains('{"videos":')) {
    final extractedData = _extractVideoFromContent(message.content);
    displayVideoUrl = extractedData['videoUrl'];
    displayContent = extractedData['cleanContent'];
  }
  
  // Check if this is an image-only or video-only response (no meaningful text content)
  final hasGeneratedImage = message.generatedImageData != null;
  final hasGeneratedVideo = displayVideoUrl != null;
  final contentIsBase64 = displayContent.toLowerCase().contains('base64') || 
                          displayContent.startsWith('data:image');
  final contentIsVideoJson = displayContent.trim().startsWith('{') && displayContent.contains('"videos"');
  final shouldHideContent = (hasGeneratedImage && (contentIsBase64 || displayContent.trim().isEmpty)) ||
                            (hasGeneratedVideo && (contentIsVideoJson || displayContent.trim().isEmpty));
  
  // Parse table if content contains table syntax
  final tableData = !shouldHideContent ? _parseMarkdownTable(displayContent) : null;
  
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
              backgroundColor: Colors.amber,
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
                    color: isUser ? _primaryColor : Colors.white,
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
                      // Display generated image as thumbnail
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
                                  child: Image.memory(
                                    base64Decode(message.generatedImageData!.split(',')[1]),
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
                                            Text(
                                              'Không thể hiển thị ảnh',
                                              style: const TextStyle(fontSize: 12),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              // Overlay to indicate clickable
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.3),
                                      ],
                                    ),
                                  ),
                                  child: const Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.zoom_in,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Nhấn để phóng to',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
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
                      // Display generated video as thumbnail
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
                                  child: VideoThumbnail(
                                    videoUrl: displayVideoUrl!,
                                  ),
                                ),
                              ),
                              // Play button overlay
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.3),
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow,
                                        color: Colors.white,
                                        size: 48,
                                      ),
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
                                      Text(
                                        'Nhấn để phát',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Display user's attached image as thumbnail
                      if (message.imagePath != null && File(message.imagePath!).existsSync()) ...[
                        GestureDetector(
                          onTap: () => _showImagePopup(message.imagePath!, isBase64: false),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 256,
                                  height: 256,
                                  child: Image.file(
                                    File(message.imagePath!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              // Overlay to indicate clickable
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.3),
                                      ],
                                    ),
                                  ),
                                  child: const Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.zoom_in,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Nhấn để phóng to',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
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
                      // Only show content if it's not base64 text for image responses
                      if (!shouldHideContent && displayContent.isNotEmpty) ...[
                        // Show table if detected, otherwise show regular text
                        if (tableData != null)
                          _buildTable(tableData)
                        else
                          _buildSelectableFormattedText(
                            displayContent,
                            isUser ? Colors.white : Colors.black87,
                          ),
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
                // Copy button on hover (only show if there's copyable content)
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
                            color: isUser 
                                ? Colors.white.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.copy,
                            size: 16,
                            color: isUser ? Colors.white : Colors.black87,
                          ),
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
              child: Text(
                _userAvatarEmoji.isNotEmpty ? _userAvatarEmoji : '🐙',
                style: const TextStyle(fontSize: 24),
              ),
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
          backgroundColor: Colors.amber,
          child: const Text('🌎', style: TextStyle(fontSize: 24)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
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
                            child: Image.memory(
                              base64Decode(_currentStreamingImage!.split(',')[1]),
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
                            ),
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
                        child: _buildFormattedText(parsedContent['beforeTable'], Colors.black87),
                      ),
                    if ((parsedContent['tableRows'] as List).length > 1)
                      _buildTable(parsedContent['tableRows']),
                    if (parsedContent['afterTable'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _buildFormattedText(parsedContent['afterTable'], Colors.black87),
                      ),
                  ] else
                    _buildFormattedText(_currentStreamingMessage, Colors.black87),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
  Widget _buildFormattedText(String text, Color color) {
    final List<TextSpan> spans = [];
    final RegExp boldPattern = RegExp(r'\*\*(.*?)\*\*');
    int lastIndex = 0;
    
    for (final match in boldPattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(color: color),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ));
      lastIndex = match.end;
    }
    
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(color: color),
      ));
    }
    
    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildSelectableFormattedText(String text, Color color) {
    final List<TextSpan> spans = [];
    final RegExp boldPattern = RegExp(r'\*\*(.*?)\*\*');
    int lastIndex = 0;
    
    for (final match in boldPattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(color: color),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ));
      lastIndex = match.end;
    }
    
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(color: color),
      ));
    }
    
    return SelectableText.rich(
      TextSpan(children: spans),
      style: TextStyle(color: color),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_selectedImage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _selectedImage!.path.toLowerCase().endsWith('.jpg') ||
                  _selectedImage!.path.toLowerCase().endsWith('.jpeg') ||
                  _selectedImage!.path.toLowerCase().endsWith('.png') ||
                  _selectedImage!.path.toLowerCase().endsWith('.bmp')
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          _selectedImage!,
                          height: 60,
                          width: 60,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(Icons.insert_drive_file, color: _primaryColor, size: 30),
                      ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedImage!.path.toLowerCase().endsWith('.jpg') ||
                      _selectedImage!.path.toLowerCase().endsWith('.jpeg') ||
                      _selectedImage!.path.toLowerCase().endsWith('.png') ||
                      _selectedImage!.path.toLowerCase().endsWith('.bmp')
                        ? 'Đã chọn ảnh'
                        : _selectedImage!.path.split('/').last,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _removeImage,
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _primaryColor,
                  shape: BoxShape.circle,
                ),
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
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(_mode == 'image' ? Icons.image : Icons.attach_file),
                onPressed: _isStreaming ? null : (_mode == 'image' ? _pickImage : () async {
                  try {
                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['jpg','jpeg','png','bmp','pdf', 'txt', 'rtf', 'mp4', 'mpeg', 'webm', 'mov', 'flac', 'aac', 'mp3', 'm4a', 'ogg', 'wav'],
                      allowMultiple: false,
                    );
                    if (result != null) {
                      File file = File(result.files.single.path!);
                      int fileSizeInBytes = await file.length();
                      double fileSizeInMB = fileSizeInBytes / (1024 * 1024);
                      if (fileSizeInMB > 20) {
                        _showError('Kích thước file vượt quá 20MB');
                        return;
                      }
                      setState(() {
                        _selectedImage = file;
                      });
                    }
                  } catch (e) {
                    _showError('Không thể chọn file: $e');
                  }
                }),
                color: _primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: !_isStreaming,
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: _mode == 'text' ? 'Nhập tin nhắn... (Enter 2 lần để gửi)' : 'Mô tả hình ảnh cần tạo...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
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
  final String? imagePath;
  final String? generatedImageData;
  final String? generatedVideoUrl;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.imagePath,
    this.generatedImageData,
    this.generatedVideoUrl,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'content': content,
    'imagePath': imagePath,
    'generatedImageData': generatedImageData,
    'generatedVideoUrl': generatedVideoUrl,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    role: json['role'],
    content: json['content'],
    imagePath: json['imagePath'],
    generatedImageData: json['generatedImageData'],
    generatedVideoUrl: json['generatedVideoUrl'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

// Video Thumbnail Widget
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
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
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
              Icon(Icons.error_outline, color: Colors.white, size: 48),
              SizedBox(height: 8),
              Text(
                'Không thể tải video',
                style: TextStyle(color: Colors.white),
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
          child: CircularProgressIndicator(color: Colors.white),
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

// Video Player Dialog
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
        // Auto play
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
            // Header
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
            // Video Player
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
                              // Play/Pause overlay
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
                              // Controls at bottom
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