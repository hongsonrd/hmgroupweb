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
  set image(File? value) {
    setState(() {
      _image = value;
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
void _addUserMessage(String message, {File? image}) {
    setState(() {
      if (image != null) {
        _chatHistory.add({
          "user": message,
          "image": image.path  // Store the image path
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
      _chatHistory.add({"ai": message});
      _saveChatHistory();
    });
    _scrollToBottom();
    _speak(message);
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
  'https://https://splendid-binder-432809-k6.as.r.appspot.com/generate',
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
        
        var multipartFile = http.MultipartFile(
          'file',
          stream,
          length,
          filename: currentImage.path.split('/').last,
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
              return _buildAIMessage(message['ai']!);
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
        child: Text('Đang trả lời${'.' * _loadingDots}'),
      ),
    );
  }
Widget _buildUserMessage(Map<String, dynamic> message) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF5E5AEC),
              Color(0xFF8C52FF),
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
  );
}
Widget _buildAIMessage(String message) {
  return GestureDetector(
    onLongPress: () => _showCopyDialog(message),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFF9966),
              Color(0xFFFF6B95),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message,
          style: TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
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
                      padding: EdgeInsets.all(4), // Reduced padding
                      icon: Icon(Icons.attach_file, size: 20), // Smaller icon
                      onPressed: _pickImage,
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
            padding: const EdgeInsets.symmetric(vertical: 4.0), // Reduced padding
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
                        height: 80, // Slightly smaller preview
                        width: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.all(4), // Reduced padding
                      icon: Icon(Icons.close, color: Colors.white, size: 18),
                      onPressed: () => setState(() => _image = null),
                    ),
                  ],
                ),
                
                // AI analysis button
                Container(
                  margin: EdgeInsets.only(top: 4),
                  height: 36,
                  width: 200, // Fixed width for button
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
                        // Set analysis prompt
                        _textController.text = 'Trả lời ngắn gọn: đánh giá việc chụp hình, chất lượng vệ sinh trong ảnh (nếu chưa tốt thì mô tả vị trí nào trong ảnh) và gợi ý ngắn gọn về việc làm tiếp theo nếu tôi là người quản lý dịch vụ vệ sinh (không phải quản lý toà nhà hay nhân viên kỹ thuật) ở đây. Đánh giá tổng quan trên hệ 10 điểm (nếu có thể thì gợi ý nhanh tôi cách chụp ảnh tốt hơn. Nếu dưới 7 điểm thì gợi ý cách làm sạch chuyên sâu bằng loại máy hoặc hoá chất phù hợp)';
                        // Send message
                        _sendMessage();
                      }
                    },
                  ),
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