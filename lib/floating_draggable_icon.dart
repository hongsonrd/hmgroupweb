import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';
import 'package:http_parser/http_parser.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:clipboard/clipboard.dart';

class FloatingDraggableIcon extends StatefulWidget {
  // Add static key for external access
  static final GlobalKey<FloatingDraggableIconState> globalKey = GlobalKey<FloatingDraggableIconState>();
  static final GlobalKey<ChatWindowState> chatWindowKey = GlobalKey<ChatWindowState>();
  
  const FloatingDraggableIcon({super.key});

  @override
  State<FloatingDraggableIcon> createState() => FloatingDraggableIconState();
}
class FloatingDraggableIconState extends State<FloatingDraggableIcon> with TickerProviderStateMixin {
  Offset? _offset;
  late AnimationController _textAnimationController;
  late List<AnimationController> _waveControllers;
  late List<Animation<double>> _waveAnimations;
  late Animation<Color?> _textColorAnimation;
  bool _isChatOpen = false;
  String _lastClearDate = '';
  void analyzeImageWithAI(File imageFile) {
    setState(() {
      _isChatOpen = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatState = FloatingDraggableIcon.chatWindowKey.currentState;
      if (mounted && chatState != null) {
        chatState.image = imageFile;
        chatState.messageText = 'Trả lời ngắn gọn: đánh giá việc chụp hình, chất lượng vệ sinh trong ảnh (nếu chưa tốt thì mô tả vị trí nào trong ảnh) và gợi ý ngắn gọn về việc làm tiếp theo nếu tôi là người quản lý dịch vụ vệ sinh (không phải quản lý toà nhà hay nhân viên kỹ thuật) ở đây. Đánh giá tổng quan trên hệ 10 điểm (nếu có thể thì gợi ý nhanh tôi cách chụp ảnh tốt hơn) Nếu dưới 7 điểm thì gợi ý cách làm sạch chuyên sâu bằng loại máy hoặc hoá chất phù hợp)';
        chatState.sendMessage();
      }
    });
  }
  void openChat() {
  setState(() {
    _isChatOpen = true;
  });
  
  // Also scroll to bottom when opening
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FloatingDraggableIcon.chatWindowKey.currentState?.scrollToBottom();
  });
}
@override
  void initState() {
    super.initState();
    
    // Text color animation setup
    _textAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _textColorAnimation = ColorTween(
      begin: const Color.fromARGB(255, 0, 21, 179),
      end: const Color.fromARGB(255, 141, 0, 148),
    ).animate(_textAnimationController);

    // Initialize multiple wave animations
    _waveControllers = List.generate(3, (index) {
      return AnimationController(
        duration: Duration(milliseconds: 2000 + (index * 500)), // Varying speeds
        vsync: this,
      );
    });

    _waveAnimations = _waveControllers.map((controller) {
      return Tween<double>(
        begin: 1.0,
        end: 1.15,  // Slightly different max scale for each wave
      ).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    // Start the wave animations with different delays
    for (int i = 0; i < _waveControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 400), () {
        _waveControllers[i].repeat(reverse: true);
      });
    }

    _checkAndClearHistory();
  }
  
// In FloatingDraggableIconState class
Future<void> updateLoginStatus() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String username = prefs.getString('username') ?? '';
  
  final chatState = FloatingDraggableIcon.chatWindowKey.currentState;
  if (chatState != null) {
    // Instead of using updateUsername, directly call the existing _loadUsername method
    chatState._loadUsername();
  }
}
 Future<void> _checkAndClearHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String lastClearDate = prefs.getString('last_clear_date') ?? '';
    String today = DateTime.now().toIso8601String().split('T')[0];

    if (lastClearDate != today) {
      await prefs.setString('chat_history', '[]');
      await prefs.setString('last_clear_date', today);
      final chatState = FloatingDraggableIcon.chatWindowKey.currentState;
      if (chatState != null) {
        chatState.clearChatHistory();
      }
    }
  }
  @override
  void dispose() {
    _textAnimationController.dispose();
    for (var controller in _waveControllers) {
      controller.dispose();
    }
    super.dispose();
  }
 @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _offset ??= Offset(size.width * 0.7, size.height * 0.7);
return Stack(
    children: [
      if (_isChatOpen) ...[
        // Animated wave effects
        ...List.generate(_waveAnimations.length, (index) {
          return AnimatedBuilder(
            animation: _waveAnimations[index],
            builder: (context, child) {
              return Positioned(
                top: 60, // Moved up slightly
                left: size.width * 0.075,
                right: size.width * 0.075,
                child: Transform.scale(
                  scale: _waveAnimations[index].value,
                  child: Container(
                    height: size.height * 0.85, // Increased height
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFF9966).withOpacity(0.3 - (index * 0.1)),
                          Color(0xFFFF6B95).withOpacity(0.3 - (index * 0.1)),
                          Color.fromARGB(255, 107, 203, 255).withOpacity(0.3 - (index * 0.1)),
                          Color(0xFF8C52FF).withOpacity(0.3 - (index * 0.1)),
                          Color(0xFF5E5AEC).withOpacity(0.3 - (index * 0.1)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
Positioned(
            top: 60,
            left: size.width * 0.075,
            right: size.width * 0.075,
            child: ChatWindow(
              key: FloatingDraggableIcon.chatWindowKey,
              onClose: () {
                setState(() {
                  _isChatOpen = false;
                  _offset = Offset(size.width * 0.8, size.height * 0.3);
                });
              },
              onOpen: () {
                FloatingDraggableIcon.chatWindowKey.currentState?.scrollToBottom();
              },
            ),
          ),
        ],
 if (!_isChatOpen)
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: _offset!.dx,
            top: _offset!.dy,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isChatOpen = true;
                  FloatingDraggableIcon.chatWindowKey.currentState?.scrollToBottom();
                });
              },
              child: Draggable(
                feedback: _buildIconWithText(),
                childWhenDragging: Container(),
                onDragEnd: (details) {
                  setState(() {
                    _offset = _getPositionWithinBounds(details.offset, size);
                  });
                },
                child: _buildIconWithText(),
              ),
            ),
          ),
      ],
    );
  }
Widget _buildIconWithText() {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedBuilder(
              animation: _textColorAnimation,
              builder: (context, child) {
                return Text(
                  'HM AI',
                  style: TextStyle(
                    color: _textColorAnimation.value,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 4),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  spreadRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Image.asset(
              'assets/iconAI.png',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Offset _getPositionWithinBounds(Offset position, Size size) {
    double x = math.min(math.max(position.dx, 0), size.width - 56);
    double y = math.min(math.max(position.dy, 0), size.height - 80);
    return Offset(x, y);
  }
}
class ChatWindow extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onOpen;

  const ChatWindow({Key? key, required this.onClose, required this.onOpen}) : super(key: key);

  @override
  State<ChatWindow> createState() => ChatWindowState();
}
class ChatWindowState extends State<ChatWindow> with SingleTickerProviderStateMixin {
  String _username = ''; 
  File? _image; 
  final ImagePicker _picker = ImagePicker();
  final FlutterTts flutterTts = FlutterTts();
  bool _isKeyboardVisible = false;
  final TextEditingController _textController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _currentLocaleId = '';
  late AnimationController _animationController;
  late Animation<double> _animation;
List<Map<String, dynamic>> _chatHistory = [];  
  final math.Random _random = math.Random();
  final ScrollController _scrollController = ScrollController();
  bool _isWaitingForResponse = false;
  int _loadingDots = 0;
  
  File? _firstImage;
  set image(File? value) {
  setState(() {
    _image = value;
    if (value != null) {
      _firstImage = value;
    }
  });
}

  set messageText(String value) {
    _textController.text = value;
  }

  void sendMessage() {
    _sendMessage();
  }
@override
void initState() {
  super.initState();
  _initSpeech();
  _loadChatHistory();
  _loadUsername();
  _animationController = AnimationController(
    duration: const Duration(milliseconds: 1500),
    vsync: this,
  );
  
  _animation = Tween<double>(
    begin: 0.2,
    end: 0.6,
  ).animate(CurvedAnimation(
    parent: _animationController,
    curve: Curves.easeInOut,
  ));
  
  _animationController.repeat(reverse: true);
  _initTts();
}

void setImageFromMemory(Uint8List imageBytes) async {
  final tempDir = await getTemporaryDirectory();
  final tempFile = File('${tempDir.path}/memory_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
  await tempFile.writeAsBytes(imageBytes);
  setState(() {
    _image = tempFile;
  });
  scrollToBottom();
}
static void sendImageToChat(BuildContext context, {
  required File imageFile,
  String? prompt,
}) {
  // First ensure the chat is open
  final iconState = FloatingDraggableIcon.globalKey.currentState;
  if (iconState != null) {
    iconState.setState(() {
      iconState._isChatOpen = true;
    });
    
    // After ensuring chat is open, set the image
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatState = FloatingDraggableIcon.chatWindowKey.currentState;
      if (chatState != null) {
        chatState.setState(() {
          chatState._image = imageFile;
        });
        
        // If prompt is provided, set it
        if (prompt != null) {
          chatState._textController.text = prompt;
        }
        
        chatState.scrollToBottom();
      }
    });
  }
}
Future<void> _getImageFromClipboard() async {
  try {
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Kiểm tra clipboard...'))
    );

    // In Flutter, we can check if clipboard has text
    final clipboardData = await FlutterClipboard.paste();
    
    // Check if it's a file path that might be an image
    if (clipboardData.isNotEmpty && 
        (clipboardData.endsWith('.jpg') || 
         clipboardData.endsWith('.jpeg') || 
         clipboardData.endsWith('.png'))) {
      
      final file = File(clipboardData);
      if (await file.exists()) {
        setState(() {
          _image = file;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã tìm thấy ảnh trong clipboard'))
        );
        return;
      }
    }
    
    // If we get here, no image was found
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Không tìm thấy ảnh trong clipboard'))
    );
  } catch (e) {
    print('Error getting image from clipboard: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Không thể truy cập clipboard'))
    );
  }
}
void _handleImageDragDrop(DragUpdateDetails details) {
  // This would be implemented in your platform-specific code
  // For web, you could use a plugin like file_picker_cross
}
String _processTextFormatting(String text) {
  String displayText = text;
  RegExp boldPattern = RegExp(r'\*\*(.*?)\*\*');
  displayText = displayText.replaceAllMapped(boldPattern, (match) {
    String content = match.group(1) ?? '';
    return '<b>$content</b>';
  });
  RegExp singleAsteriskPattern = RegExp(r'\*(.*?)(?=\s|$)');
  displayText = displayText.replaceAllMapped(singleAsteriskPattern, (match) {
    String content = match.group(1) ?? '';
    return '<b>$content</b>';
  });
  return displayText;
}
String _stripFormattingForTTS(String text) {
  return text.replaceAll(RegExp(r'<[^>]*>'), '');
}
  Future<void> _loadUsername() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? '';
    });
  }
  Future<void> _logQuery(String query) async {
  try {
    await http.post(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/aichat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "text": query,
        "username": _username
      })
    );
  } catch (e) {
    print('Error logging query: $e');
    // We don't handle the error since logging should not affect main functionality
  }
}
void _sendImageToAI(String photoPath) {
  File imageFile = File(photoPath);
  final FloatingDraggableIconState? iconState = 
      context.findAncestorStateOfType<FloatingDraggableIconState>();
  
  if (iconState != null) {
    iconState.analyzeImageWithAI(imageFile);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Không thể kết nối với AI. Vui lòng thử lại sau.')),
    );
  }
}
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }
void _initTts() async {
  await flutterTts.setLanguage("vi-VN");
  await flutterTts.setSpeechRate(0.6);
  await flutterTts.setVolume(1.1);
  await flutterTts.setPitch(1.0);
}
Future<void> _speak(String text) async {
  await flutterTts.speak(text);
}
  @override
  void dispose() {
    flutterTts.stop();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) => print('Speech status: $status'),
      onError: (errorNotification) => print('Speech error: $errorNotification'),
    );
    var systemLocale = await _speech.systemLocale();
    _currentLocaleId = systemLocale?.localeId ?? '';
    setState(() {});
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        await _speech.listen(
          onResult: (result) {
            setState(() {
              _textController.text = result.recognizedWords;
            });
          },
          localeId: _currentLocaleId,
          listenMode: stt.ListenMode.dictation,
        );
      } else {
        print("The user has denied the use of speech recognition.");
      }
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
    if (_username.isEmpty) {
    _textController.clear();
    _addAIMessage("Xin lỗi, không thể xử lý yêu cầu vì chưa đăng nhập. Vui lòng đăng nhập và thử lại.");
    return;
  }
    Future.delayed(Duration(seconds: 1), () {
      _logQuery(_textController.text);
      _sendMessage();
    });
  }
  void _loadChatHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? history = prefs.getString('chat_history');
    if (history != null) {
      setState(() {
        _chatHistory = (jsonDecode(history) as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } else {
      _addAIMessage("Xin chào! Tôi là trợ lý AI từ Hoàn Mỹ. Tôi có kiến thức về các mẫu robot khác nhau, cũng như sử dụng ứng dụng. Tôi sẽ rất vui lòng trả lời bất kỳ câu hỏi nào bạn bằng tiếng Việt. Bạn muốn biết thông tin gì? (bạn có thể nói chuyện với tôi)");
    }
  }
  void _saveChatHistory() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  // Convert the chat history to a format that can be stored
  List<Map<String, dynamic>> storableHistory = _chatHistory.map((message) {
    var storable = Map<String, dynamic>.from(message);
    return storable;
  }).toList();
  await prefs.setString('chat_history', jsonEncode(storableHistory));
}
void _addUserMessage(String message, {File? image, String? displayMessage}) {
  setState(() {
    if (image != null) {
      _chatHistory.add({
        "user": displayMessage ?? message, 
        "image": image.path,
        "original_message": message 
      });
    } else {
      _chatHistory.add({"user": message});
    }
    _saveChatHistory();
  });
  _scrollToBottom();
}
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  void _addAIMessage(String message) {
  setState(() {
    String ttsText = message;
    String displayText = _processTextFormatting(message);
    
    _chatHistory.add({"ai": displayText, "raw_text": ttsText});
    _saveChatHistory();
  });
  _scrollToBottom();
  _speak(_stripFormattingForTTS(message));
}
void scrollToBottom() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });
}
final List<String> urlList = [
  'https://splendid-binder-432809-k6.as.r.appspot.com/generate',
  'https://hmtime.as.r.appspot.com/generate',
  'https://sincere-beacon-432912-e6.as.r.appspot.com/generate',
];
Future<void> _sendMessage() async {
  if (_username.isEmpty) {
    _addAIMessage("Xin lỗi, không thể xử lý yêu cầu vì chưa đăng nhập. Vui lòng đăng nhập và thử lại.");
    return;
  }
    String message = _textController.text.trim();
    if (message.isEmpty && _image == null) return;
    _logQuery(message);
    // Store the current image before clearing it
    File? currentImage = _image;
    
    _addUserMessage(message, image: currentImage);
    _textController.clear();

    setState(() {
      _isWaitingForResponse = true;
      _image = null;  // Clear the image after sending
    });
    _animateLoadingDots();

    try {
      final randomIndex = math.Random().nextInt(urlList.length);
      String randomUrl = urlList[randomIndex];
      
      if (currentImage != null) {
  // Image with text scenario
  randomUrl = randomUrl.replaceAll('/generate', '/generate_with_image');
  
  print('Sending request to: $randomUrl');
  
  var request = http.MultipartRequest('POST', Uri.parse(randomUrl));
  
  // Add file
  var stream = http.ByteStream(currentImage.openRead());
  var length = await currentImage.length();
  
  // Log the file size for debugging
  print('Sending image with size: $length bytes');
  
  var multipartFile = http.MultipartFile(
    'file',
    stream,
    length,
    filename: 'image.jpg', // Use a consistent filename
    contentType: MediaType('image', 'jpeg')
  );
  
  request.files.add(multipartFile);
  request.fields['prompt'] = message;
  
  print('Sending image with prompt: $message');
  
  try {
    var response = await request.send();
    var responseData = await http.Response.fromStream(response);
    
    print('Response status: ${responseData.statusCode}');
    print('Response body: ${responseData.body}');
    
    setState(() {
      _isWaitingForResponse = false;
    });
    
    if (responseData.statusCode == 200) {
      var data = jsonDecode(responseData.body);
      _addAIMessage(data['response']);
    } else {
      print('Server error: ${responseData.statusCode} - ${responseData.body}');
      _addAIMessage("Xin lỗi, tôi đang gặp sự cố kỹ thuật. Vui lòng thử lại sau.");
    }
  } catch (e) {
    print('Error sending image: $e');
    _addAIMessage("Xin lỗi, có lỗi khi gửi ảnh. Vui lòng thử lại sau.");
    setState(() {
      _isWaitingForResponse = false;
    });
  }
} else {
        // Text-only scenario
        var response = await http.post(
          Uri.parse(randomUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({"prompt": message})
        ).timeout(Duration(seconds: 30));
        
        setState(() {
          _isWaitingForResponse = false;
        });
        
        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);
          _addAIMessage(data['response']);
        } else {
          _addAIMessage("Xin lỗi, tôi đang gặp sự cố kỹ thuật. Vui lòng thử lại sau.");
        }
      }

      if (_random.nextDouble() < 0.2) {
        _addFollowUpQuestion();
      }
    } catch (e) {
      print('Error in _sendMessage: $e');
      setState(() {
        _isWaitingForResponse = false;
      });
      _addAIMessage("Xin lỗi, có lỗi xảy ra. Vui lòng kiểm tra kết nối mạng và thử lại.");
    }
  }
  void _animateLoadingDots() {
    if (_isWaitingForResponse) {
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted && _isWaitingForResponse) {
          setState(() {
            _loadingDots = (_loadingDots + 1) % 4;
          });
          _animateLoadingDots();
        }
      });
    }
  }

  void _addFollowUpQuestion() {
    List<String> followUpQuestions = [
      "Bạn có muốn hỏi thêm điều gì không?",
      "Còn vấn đề nào bạn muốn tìm hiểu thêm không?",
      "Bạn có câu hỏi nào khác không?",
      "Tôi có thể giúp gì thêm cho bạn không?",
      "Bạn cần biết thêm thông tin gì nữa không?"
    ];
    String question = followUpQuestions[_random.nextInt(followUpQuestions.length)];
    _addAIMessage(question);
  }
@override
Widget build(BuildContext context) {
  final size = MediaQuery.of(context).size;
  final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
  _isKeyboardVisible = bottomPadding > 0;
  
  return GestureDetector(
    onTap: () => FocusScope.of(context).unfocus(),
    child: Container(
      height: _isKeyboardVisible ? size.height * 0.45 : size.height * 0.8, // Adjusted height
      width: size.width * 0.95,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF9966),
            Color(0xFFFF6B95),
            Color.fromARGB(255, 107, 203, 255),
            Color(0xFF8C52FF),
            Color(0xFF5E5AEC),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Container(
        margin: EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildChatControl(bottomPadding),
            Expanded(
              child: _buildChatHistory(),
            ),
          ],
        ),
      ),
    ),
  );
}
Widget _buildHeader() {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      gradient: LinearGradient(
        colors: [
          Color(0xFFFF9966),
          Color(0xFFFF6B95),
        ],
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              child: Image.asset(
                'assets/iconAI.png',
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HM AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_username.isNotEmpty)
                  Text(
                    _username,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
        IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: widget.onClose,
        ),
      ],
    ),
  );
}
Future<void> _processImageMessage(String message, File currentImage) async {
  try {
    final randomIndex = math.Random().nextInt(urlList.length);
    String randomUrl = urlList[randomIndex];
    
    // Image with text scenario
    randomUrl = randomUrl.replaceAll('/generate', '/generate_with_image');
    
    print('Sending request to: $randomUrl');
    
    var request = http.MultipartRequest('POST', Uri.parse(randomUrl));
    
    // Add file
    var stream = http.ByteStream(currentImage.openRead());
    var length = await currentImage.length();
    
    // Log the file size for debugging
    print('Sending image with size: $length bytes');
    
    var multipartFile = http.MultipartFile(
      'file',
      stream,
      length,
      filename: 'image.jpg',
      contentType: MediaType('image', 'jpeg')
    );
    
    request.files.add(multipartFile);
    request.fields['prompt'] = message;
    
    print('Sending image with prompt: $message');
    
    try {
      var response = await request.send();
      var responseData = await http.Response.fromStream(response);
      
      print('Response status: ${responseData.statusCode}');
      print('Response body: ${responseData.body}');
      
      setState(() {
        _isWaitingForResponse = false;
      });
      
      if (responseData.statusCode == 200) {
        var data = jsonDecode(responseData.body);
        _addAIMessage(data['response']);
        
        if (_random.nextDouble() < 0.2) {
          _addFollowUpQuestion();
        }
      } else {
        print('Server error: ${responseData.statusCode} - ${responseData.body}');
        _addAIMessage("Xin lỗi, tôi đang gặp sự cố kỹ thuật. Vui lòng thử lại sau.");
      }
    } catch (e) {
      print('Error sending image: $e');
      _addAIMessage("Xin lỗi, có lỗi khi gửi ảnh. Vui lòng thử lại sau.");
      setState(() {
        _isWaitingForResponse = false;
      });
    }
  } catch (e) {
    print('Error in _processImageMessage: $e');
    setState(() {
      _isWaitingForResponse = false;
    });
    _addAIMessage("Xin lỗi, có lỗi xảy ra. Vui lòng kiểm tra kết nối mạng và thử lại.");
  }
}
Future<File> _combineImages(File firstImage, File secondImage) async {
  // Decode images
  Uint8List firstBytes = await firstImage.readAsBytes();
  Uint8List secondBytes = await secondImage.readAsBytes();
  
  img.Image? image1 = img.decodeImage(firstBytes);
  img.Image? image2 = img.decodeImage(secondBytes);
  
  if (image1 == null || image2 == null) {
    throw Exception('Failed to decode images');
  }
  
  // Resize images to a more modest size to reduce file size
  final targetHeight = 300; // Reduced from 400
  final aspectRatio1 = image1.width / image1.height;
  final aspectRatio2 = image2.width / image2.height;
  
  final newWidth1 = (targetHeight * aspectRatio1).round();
  final newWidth2 = (targetHeight * aspectRatio2).round();
  
  img.Image resized1 = img.copyResize(image1, width: newWidth1, height: targetHeight);
  img.Image resized2 = img.copyResize(image2, width: newWidth2, height: targetHeight);
  
  // Create combined image
  final combinedWidth = newWidth1 + newWidth2 + 2; // +2 for the divider
  final combinedImage = img.Image(width: combinedWidth, height: targetHeight);
  
  // Fill with white background
  img.fill(combinedImage, color: img.ColorRgb8(255, 255, 255));
  
  // Copy first image to the left
  img.compositeImage(combinedImage, resized1, dstX: 0, dstY: 0);
  
  // Draw black divider line (2px)
  for (int y = 0; y < targetHeight; y++) {
    combinedImage.setPixel(newWidth1, y, img.ColorRgb8(0, 0, 0));
    combinedImage.setPixel(newWidth1 + 1, y, img.ColorRgb8(0, 0, 0));
  }
  
  // Copy second image to the right
  img.compositeImage(combinedImage, resized2, dstX: newWidth1 + 2, dstY: 0);
  
  // Save the combined image with lower quality to reduce file size
  final directory = await getTemporaryDirectory();
  final outputFile = File('${directory.path}/combined_${DateTime.now().millisecondsSinceEpoch}.jpg');
  
  // Use lower quality (85 instead of default 100) to reduce file size
  await outputFile.writeAsBytes(img.encodeJpg(combinedImage, quality: 85));
  
  print('Combined image created: ${outputFile.path}');
  print('Combined image size: ${await outputFile.length()} bytes');
  
  return outputFile;
}
Future<void> _pickSecondImage() async {
  // First make sure we have a valid first image
  if (_image == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Vui lòng chọn ảnh đầu tiên trước khi so sánh')),
    );
    return;
  }
  
  // Store the first image
  final File firstImage = _image!;
  
  try {
    // Pick second image
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile == null) return; // User canceled
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8C52FF)),
                ),
              ),
              SizedBox(width: 16),
              Text("Đang xử lý"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(),
              SizedBox(height: 16),
              Text("Đang kết hợp hai hình ảnh...", textAlign: TextAlign.center),
            ],
          ),
        );
      }
    );
    
    File secondImage = File(pickedFile.path);
    
    // Create combined image
    File combinedImage = await _combineImages(firstImage, secondImage);
    
    // Close loading dialog
    if (context.mounted) Navigator.of(context).pop();
    
    // Important - keep a reference to the combinedImage
    final File finalImage = combinedImage;
    
    // Define the prompt
    final String fullPrompt = 'So sánh chất lượng vệ sinh trước và sau trong ảnh này trên thang điểm 10, nếu dưới 7 điểm thì gợi ý hoá chất/ máy móc từ danh sách để xử lý. Bên trái là trước, bên phải là sau.';
    
    // Add user message first
    _addUserMessage(fullPrompt, image: finalImage, displayMessage: "Đánh giá trước sau");
    
    // Set up for the response
    setState(() {
      _isWaitingForResponse = true;
      _image = null; // Clear the image reference
    });
    
    // Send request directly to avoid any state issues
    try {
      final randomIndex = math.Random().nextInt(urlList.length);
      String randomUrl = urlList[randomIndex].replaceAll('/generate', '/generate_with_image');
      
      var request = http.MultipartRequest('POST', Uri.parse(randomUrl));
      
      var stream = http.ByteStream(finalImage.openRead());
      var length = await finalImage.length();
      
      var multipartFile = http.MultipartFile(
        'file',
        stream,
        length,
        filename: 'image.jpg',
        contentType: MediaType('image', 'jpeg')
      );
      
      request.files.add(multipartFile);
      request.fields['prompt'] = fullPrompt;
      
      print('Sending image with prompt: $fullPrompt');
      
      var response = await request.send();
      var responseData = await http.Response.fromStream(response);
      
      setState(() {
        _isWaitingForResponse = false;
      });
      
      if (responseData.statusCode == 200) {
        var data = jsonDecode(responseData.body);
        _addAIMessage(data['response']);
      } else {
        _addAIMessage("Xin lỗi, tôi đang gặp sự cố kỹ thuật. Vui lòng thử lại sau.");
      }
    } catch (e) {
      setState(() {
        _isWaitingForResponse = false;
      });
      _addAIMessage("Xin lỗi, có lỗi khi gửi ảnh. Vui lòng thử lại sau.");
    }
    
  } catch (e) {
    // Handle errors
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Có lỗi xảy ra: $e')),
      );
    }
  }
}
Widget _buildChatHistory() {
  return Expanded(
    child: Container(
      margin: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100]!.withOpacity(0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(16),
        itemCount: _chatHistory.length + (_isWaitingForResponse ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _chatHistory.length && _isWaitingForResponse) {
            return _buildLoadingIndicator();
          }
          final message = _chatHistory[index];
          if (message.containsKey('user')) {
            return _buildUserMessage(message);
          } else {
            return _buildAIMessage(message);
          }
        },
      ),
    ),
  );
}
  Widget _buildLoadingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green[100]!.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('✨⚡🌟💫${'.' * _loadingDots}'),
      ),
    );
  }
Widget _buildUserMessage(Map<String, dynamic> message) {
  return Align(
    alignment: Alignment.centerRight,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 4),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF248A3D),
                Color(0xFF30D158),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.containsKey('image'))
                Container(
                  margin: EdgeInsets.only(bottom: 8),
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(File(message['image'])),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Text(
                message['user'],
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: Size(0, 20),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
              ),
              child: Text('Copy', style: TextStyle(fontSize: 10)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: message['user']));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã sao chép tin nhắn')),
                );
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: Size(0, 20),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
              ),
              child: Text('Lưu', style: TextStyle(fontSize: 10)),
              onPressed: () => _createAndSharePDF(),
            ),
          ],
        ),
      ],
    ),
  );
}
Future<void> _createAndSharePDF() async {
  final pdf = pw.Document();
  
  // Load a font that supports Vietnamese
  final fontData = await rootBundle.load("assets/fonts/RobotoCondensed-Regular.ttf");
  final ttf = pw.Font.ttf(fontData);

  pdf.addPage(
    pw.Page(
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Header(
              level: 0, 
              text: 'HM AI Chat History',
              textStyle: pw.TextStyle(font: ttf),
            ),
            pw.SizedBox(height: 20),
            ...List.generate(_chatHistory.length, (index) {
              final message = _chatHistory[index];
              if (message.containsKey('user')) {
                return pw.Padding(
                  padding: pw.EdgeInsets.only(bottom: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('You:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: ttf)),
                      pw.Text(message['user'], style: pw.TextStyle(font: ttf)),
                    ],
                  ),
                );
              } else {
                return pw.Padding(
                  padding: pw.EdgeInsets.only(bottom: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('HM AI:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: ttf)),
                      pw.Text(message['raw_text'] ?? message['ai'], style: pw.TextStyle(font: ttf)),
                    ],
                  ),
                );
              }
            }),
          ],
        );
      },
    ),
  );

  // Save the PDF file
  final output = await getTemporaryDirectory();
  final file = File('${output.path}/hm_ai_chat_${DateTime.now().millisecondsSinceEpoch}.pdf');
  await file.writeAsBytes(await pdf.save());

  // Share the PDF file
  await Share.shareFiles(
    [file.path],
    text: 'HM AI Chat History',
    subject: 'Chat with HM AI',
  );
}
Widget _buildAIMessage(Map<String, dynamic> message) {
  String displayText = message['ai'];
  String rawText = message['raw_text'] ?? displayText;
  
  return Align(
    alignment: Alignment.centerLeft,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 4),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0A84FF),
                Color(0xFF007AFF),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: RichText(
            text: TextSpan(
              children: _buildFormattedText(displayText),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: Size(0, 20),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
              ),
              child: Text('Copy', style: TextStyle(fontSize: 10)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: rawText));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã sao chép tin nhắn')),
                );
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: Size(0, 20),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
              ),
              child: Text('Lưu', style: TextStyle(fontSize: 10)),
              onPressed: () => _createAndSharePDF(),
            ),
          ],
        ),
      ],
    ),
  );
}

List<TextSpan> _buildFormattedText(String text) {
  List<TextSpan> spans = [];
  // Check for <b> tags
  RegExp boldPattern = RegExp(r'<b>(.*?)</b>');
  int lastIndex = 0;
  for (Match match in boldPattern.allMatches(text)) {
    // Add text before the match
    if (match.start > lastIndex) {
      spans.add(TextSpan(
        text: text.substring(lastIndex, match.start),
        style: TextStyle(fontSize: 14.0),
      ));
    }
    String boldText = match.group(1) ?? '';
bool hasSingleAsterisk = text.substring(math.max(0, match.start - 1), match.start) == '*';
    if (hasSingleAsterisk) {
      spans.add(TextSpan(
        text: boldText,
        style: TextStyle(fontWeight: FontWeight.bold),
      ));
    } else {
      spans.add(TextSpan(
        text: boldText,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16, // Bigger text
        ),
      ));
    }
    lastIndex = match.end;
  }
  if (lastIndex < text.length) {
    spans.add(TextSpan(
      text: text.substring(lastIndex),
    ));
  }
  return spans;
}

  void _showCopyDialog(String message) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 238, 238, 238),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Xác nhận gửi ảnh',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color.fromARGB(255, 80, 66, 0),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bạn có muốn sao chép tin nhắn này không?',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  child: Text(
                    'Không',
                    textAlign: TextAlign.center,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                SizedBox(width: 16), // Space between the buttons
                ElevatedButton(
                  child: Text(
                    'Sao chép',
                    textAlign: TextAlign.center,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: message));
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã sao chép tin nhắn')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
  void clearChatHistory() {
    setState(() {
      // Delete all stored images from the device
      for (var message in _chatHistory) {
        if (message.containsKey('image')) {
          try {
            File(message['image']).deleteSync();
          } catch (e) {
            print('Error deleting image: $e');
          }
        }
      }
      
      _chatHistory.clear();
      _textController.clear();
      _image = null;
    });
    _saveChatHistory();
  }
  void _showImageSourceOptions() {
  showModalBottomSheet(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.photo_library, color: Color(0xFF8C52FF)),
            title: Text('Chọn từ thư viện'),
            onTap: () {
              Navigator.pop(context);
              _pickImage();
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.content_paste, color: Color(0xFF8C52FF)),
            title: Text('Dán từ clipboard'),
            onTap: () {
              Navigator.pop(context);
              _getImageFromClipboard();
            },
          ),
        ],
      ),
    ),
  );
}
Widget _buildChatControl(double bottomPadding) {
  return Container(
    padding: EdgeInsets.only(
      left: 8,
      right: 8,
      bottom: 8 + bottomPadding,
      top: 4, // Reduced top padding
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min, // Important to prevent excessive space
      children: [
        // Text input with pulsing border
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Color(0xFFFF9966).withOpacity(_animation.value * 0.7),
                Color(0xFFFF6B95).withOpacity(_animation.value * 0.7),
              ],
            ),
          ),
          padding: EdgeInsets.all(2), // Reduced padding
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(18),
            ),
            child: TextField(
              controller: _textController,
              maxLines: 3,
              minLines: 1,
              style: TextStyle(fontSize: 14.0),
              decoration: InputDecoration(
                hintText: 'Nhập tin nhắn của bạn...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(19),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Reduced padding
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
  padding: EdgeInsets.all(4),
  icon: Icon(Icons.attach_file, size: 20),
  onPressed: () {
    _showImageSourceOptions();
  },
),
                    IconButton(
                      padding: EdgeInsets.all(4), // Reduced padding
                      icon: Icon(Icons.delete_outline, size: 20), // Smaller icon
                      onPressed: clearChatHistory,
                    ),
                  ],
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                FocusScope.of(context).unfocus();
              },
            ),
          ),
        ),

        // Image preview with reduced spacing
        if (_image != null)
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Column(
      children: [
        // Image preview with close button
        Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _image!,
                height: 80,
                width: 80,
                fit: BoxFit.cover,
              ),
            ),
            IconButton(
              padding: EdgeInsets.all(4),
              icon: Icon(Icons.close, color: Colors.white, size: 18),
              onPressed: () => setState(() => _image = null),
            ),
          ],
        ),
        
        // Buttons row for image actions
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AI analysis button
            Container(
              margin: EdgeInsets.only(top: 4, right: 4),
              height: 36,
              width: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 154, 71, 255),
                    Color.fromARGB(255, 255, 110, 110),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: TextButton(
                child: Text(
                  'Gửi ảnh để AI phân tích',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
  if (_image != null) {
    // Store a reference to the current image before it gets nulled
    final File currentImage = _image!;
    
    String fullPrompt = 'Trả lời ngắn gọn: đánh giá việc chụp hình, chất lượng vệ sinh trong ảnh, tập trung vào đối tượng chính nhất (nếu chưa tốt thì mô tả vị trí nào trong ảnh). Đánh giá tổng quan trên hệ 10 điểm, nếu dưới 7 điểm thì gợi ý loại hoá chất trong danh sách đang có, hoặc máy móc chuyên sâu để xử lý. và gợi ý ngắn gọn về việc làm tiếp theo nếu tôi là người quản lý dịch vụ vệ sinh (không phải quản lý toà nhà hay nhân viên kỹ thuật) ở đây hoặc nếu hình ảnh không rõ ràng được là chụp gì thì mô tả cách chụp tốt hơn.';
    
    // Add the user message first
    _addUserMessage(fullPrompt, image: currentImage, displayMessage: "Đánh giá hình ảnh");
    
    // Clear the text field
    _textController.clear();
    
    // Update state
    setState(() {
      _isWaitingForResponse = true;
      _image = null;  // Clear the image reference after storing it
    });
    
    _animateLoadingDots();
    
    // Process the image with the stored reference
    _processImageMessage(fullPrompt, currentImage);
  }
},
              ),
            ),
            
            // Compare before/after button
            Container(
              margin: EdgeInsets.only(top: 4, left: 4),
              height: 36,
              width: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 0, 162, 255),
                    Color.fromARGB(255, 110, 255, 205),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: TextButton(
                child: Text(
                  'So sánh trước sau',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _pickSecondImage,
              ),
            ),
          ],
        ),
      ],
    ),
  ),

        // Buttons row with reduced spacing
        SizedBox(height: 4), // Reduced spacing
        Row(
          children: [
            // Send button
            Expanded(
              flex: 2,
              child: Container(
                height: 40, // Reduced height
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF5E5AEC), Color(0xFF8C52FF)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextButton(
                  child: Text('Gửi', 
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13, // Smaller font
                    )
                  ),
                  onPressed: _sendMessage,
                ),
              ),
            ),
            
            SizedBox(width: 6), // Reduced spacing
            
            // Voice button
            Expanded(
              flex: 3,
              child: GestureDetector(
                onLongPressStart: (_) {
                  _startListening();
                  _animationController.forward();
                },
                onLongPressEnd: (_) {
                  _stopListening();
                  _animationController.reverse();
                },
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isListening ? _animation.value : 1.0,
                      child: Container(
                        height: 40, // Reduced height
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isListening 
                              ? [Color(0xFFFF6B95), Color(0xFFFF9966)]
                              : [Color(0xFF5E5AEC), Color(0xFF8C52FF)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            _isListening ? 'Đang ghi âm...' : 'Nói chuyện với AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13, // Smaller font
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}}