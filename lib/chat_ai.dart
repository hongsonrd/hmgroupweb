import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
class ChatAIScreen extends StatefulWidget {
  const ChatAIScreen({Key? key}) : super(key: key);

  @override
  State<ChatAIScreen> createState() => _ChatAIScreenState();
}

class _ChatAIScreenState extends State<ChatAIScreen> {
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
  
  String _selectedModel = 'flash-2.5';
  String _mode = 'text';
  
  String? _hoveredMessageId;
  
  bool _sidebarVisible = true;
  String _imageRatio = '1:1';
  
  CreditBalance? _creditBalance;
  bool _isLoadingCredit = false;
  String _lastEnteredText = ''; 
  
  final Map<String, List<Map<String, dynamic>>> _models = {
    'fast': [
      {'value': 'flash-2.5-lite', 'name': 'Cá kiếm', 'cost': 16, 'rating': 3, 'systemPrompt': 'Ưu tiên trả lời bằng tiếng việt:'},
      {'value': 'deepseek-ai/DeepSeek-R1-0528', 'name': 'Cá voi xanh', 'cost': 171, 'rating': 5, 'systemPrompt': 'Ưu tiên trả lời bằng tiếng việt:'},
    ],
    'precise': [
      {'value': 'flash-2.5', 'name': 'Cá mập trắng', 'cost': 100, 'rating': 4, 'systemPrompt': 'Ưu tiên trả lời bằng tiếng việt:'},
      {'value': 'flash-2.5-pro', 'name': 'Cá voi sát thủ', 'cost': 302, 'rating': 4, 'systemPrompt': 'Ưu tiên trả lời bằng tiếng việt:'},
    ],
    'image': [
      {'value': 'imagen-4', 'name': 'Cá heo', 'cost': 1500, 'rating': 3, 'systemPrompt': 'Không chỉ tạo ảnh với chữ, phải tạo hình ảnh thiết kế:'},
      //{'value': 'veo-3.0-fast', 'name': 'Cá đuối', 'cost': 3800, 'rating': 4, 'systemPrompt': 'Tạo video dọc 9:16, 8s:'},
      //{'value': 'veo-3.0', 'name': 'Cá đuối manta', 'cost': 6000, 'rating': 5, 'systemPrompt': 'Tạo video ngang 16:9, 8s:'},
    ],
  };

  final List<Map<String, String>> _imageRatios = [
    {'value': '1:1', 'label': '1:1 Vuông'},
    {'value': '16:9', 'label': '16:9 Ngang'},
    {'value': '9:16', 'label': '9:16 Dọc'},
    {'value': '4:3', 'label': '4:3 Cổ điển'},
    {'value': '3:4', 'label': '3:4 Cao'},
  ];

  Color get _primaryColor => _mode == 'image' ? Colors.green : Colors.blue;
  Color get _lightPrimaryColor => _mode == 'image' ? Colors.green.shade50 : Colors.blue.shade50;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSessions();
    _loadCreditBalance();
    
    // Listen to text changes for double enter detection
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _chatScrollController.dispose();
    _sessionScrollController.dispose();
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
                  setState(() {
                    accumulatedResponse += data['content'];
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
                  
                case 'complete':
                  final aiMessage = ChatMessage(
                    id: const Uuid().v4(),
                    role: 'model',
                    content: data['fullResponse'],
                    generatedImageData: _currentStreamingImage, 
                    timestamp: DateTime.now(),
                  );
                  
                  setState(() {
                    _messages.add(aiMessage);
                    _currentSession!.messages.add(aiMessage);
                    _isStreaming = false;
                    _currentStreamingMessage = '';
                    _currentStreamingImage = null; 
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
      appBar: AppBar(
        backgroundColor: _primaryColor,
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
                      const SizedBox(height: 12),
                      _buildCreditBalanceWidget(),
                    ],
                  ),
                ),
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
Widget _buildTable(List<List<String>> rows) {
  if (rows.isEmpty) return const SizedBox.shrink();
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
      columnWidths: const {
        0: FlexColumnWidth(1.5),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
      },
      children: rows.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;
        final isHeader = index == 0;
        return TableRow(
          decoration: BoxDecoration(
            color: isHeader ? Colors.grey.shade100 : Colors.white,
          ),
          children: row.map((cell) {
            // Remove markdown bold syntax
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
  Widget _buildMessage(ChatMessage message) {
  final isUser = message.role == 'user';
  final isHovered = _hoveredMessageId == message.id;
  
  // Check if this is an image-only response (no meaningful text content)
  final hasGeneratedImage = message.generatedImageData != null;
  final contentIsBase64 = message.content.toLowerCase().contains('base64') || 
                          message.content.startsWith('data:image');
  final shouldHideContent = hasGeneratedImage && (contentIsBase64 || message.content.trim().isEmpty);
  
  // Parse table if content contains table syntax
  final tableData = !shouldHideContent ? _parseMarkdownTable(message.content) : null;
  
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
              backgroundColor: _primaryColor,
              child: Icon(_mode == 'text' ? Icons.smart_toy : Icons.image, color: Colors.white, size: 20),
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
                      if (!shouldHideContent && message.content.isNotEmpty) ...[
                        // Show table if detected, otherwise show regular text
                        if (tableData != null)
                          _buildTable(tableData)
                        else
                          _buildSelectableFormattedText(
                            message.content,
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
                if (isHovered && !shouldHideContent && message.content.isNotEmpty)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _copyToClipboard(message.content),
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
              backgroundColor: Colors.grey[300],
              child: Text(
                _username.isNotEmpty ? _username[0].toUpperCase() : 'U',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
Widget _buildStreamingMessage() {
  final tableData = _parseMarkdownTable(_currentStreamingMessage);
  final hasImage = _currentStreamingImage != null;
  final contentIsBase64 = _currentStreamingMessage.toLowerCase().contains('base64') || 
                          _currentStreamingMessage.startsWith('data:image');
  final shouldHideContent = hasImage && (contentIsBase64 || _currentStreamingMessage.trim().isEmpty);
  
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: _primaryColor,
          child: Icon(_mode == 'text' ? Icons.smart_toy : Icons.image, color: Colors.white, size: 20),
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
                // Display streaming image as thumbnail
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
                if (_currentStreamingMessage.isEmpty && _currentStreamingImage == null)
                  SpinKitThreeBounce(color: _primaryColor, size: 20)
                else if (!shouldHideContent && _currentStreamingMessage.isNotEmpty) ...[
                  if (tableData != null)
                    _buildTable(tableData)
                  else
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.file(
                      _selectedImage!,
                      height: 60,
                      width: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Đã chọn ảnh', style: TextStyle(fontSize: 14)),
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
                icon: const Icon(Icons.image),
                onPressed: _isStreaming ? null : _pickImage,
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
    if (_isLoadingCredit) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: SizedBox(
            height: 12,
            width: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

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
                    'Credit còn lại',
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
                  '${(_creditBalance!.currentToken / 1000).toStringAsFixed(1)}k tokens',
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
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.imagePath,
    this.generatedImageData,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'content': content,
    'imagePath': imagePath,
    'generatedImageData': generatedImageData,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    role: json['role'],
    content: json['content'],
    imagePath: json['imagePath'],
    generatedImageData: json['generatedImageData'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}