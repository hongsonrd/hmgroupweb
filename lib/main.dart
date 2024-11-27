import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';  // Add this import
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_web/webview_flutter_web.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/intro_screen.dart';
import 'screens/webview_screen.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'dart:html' as html;
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'dart:math' show pow;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Add this line to use URL strategy without hash
  setUrlStrategy(PathUrlStrategy());
  WebViewPlatform.instance = WebWebViewPlatform();
  runApp(const MyApp());
}

class UserCredentials extends ChangeNotifier {
  String _username = '';
  String _password = '';
  String get username => _username;
  String get password => _password;
  void setCredentials(String username, String password) {
    _username = username;
    _password = password;
    notifyListeners();
  }
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserCredentials()),
        ChangeNotifierProvider(create: (_) => UserState()),
      ],
      child: MaterialApp(
        title: 'HM GROUP',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.blue),
        // Add this to handle routing properly
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => const MainScreen(),
            settings: settings,
          );
        },
        home: const MainScreen(),
      ),
    );
  }
}
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}
class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isAuthenticated = false;
  String _loginStatus = '';
  Map<String, dynamic>? _currentUser;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final UserState _userState = UserState();

  List<Widget> get _screens => [
    IntroScreen(userData: _currentUser),
    const WebViewScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    await _userState.loadUser();
    
    if (_userState.isAuthenticated && _userState.currentUser != null) {
      setState(() {
        _isAuthenticated = true;
        _currentUser = _userState.currentUser;
      });
    } else {
      await _loadSavedCredentials();
    }
  }

  String encryptAES(String plainText, String key) {
    final keyBytes = encrypt.Key.fromUtf8(key);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(keyBytes, mode: encrypt.AESMode.cbc, padding: 'PKCS7'));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    final concatenated = iv.bytes + encrypted.bytes;
    return base64.encode(concatenated);
  }

  Future<void> _loadSavedCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString('username');
    String? password = prefs.getString('password');
    
    if (username != null && password != null) {
      setState(() {
        _usernameController.text = username;
        _passwordController.text = password;
      });
      await _login();
    } else {
      _showLoginDialog();
    }
  }
Future<String> fetchFromWeb(String url) async {
  try {
    // Replace the original API URL with the Worker URL
    String workerUrl = url.replaceAll(
      'https://yourworldtravel.vn', 
      'https://flat-leaf-9f05.hongson.workers.dev'
    );
    
    final response = await http.get(
      Uri.parse(workerUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': '*/*',
      },
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw TimeoutException('Request timed out');
      },
    );
    
    if (response.statusCode == 200) {
      return response.body;
    }
    throw Exception('Request failed with status: ${response.statusCode}');
  } catch (e) {
    print('Request failed: $e');
    return '';
  }
}
Future<void> _login() async {
  setState(() {
    _loginStatus = 'Đang đăng nhập...';
  });

  String inputUsername = _usernameController.text.trim().toLowerCase();
  String inputPassword = _passwordController.text.trim().toLowerCase();

  if (inputUsername.isEmpty || inputPassword.isEmpty) {
    setState(() {
      _loginStatus = 'Vui lòng nhập đầy đủ thông tin';
    });
    return;
  }

  Provider.of<UserCredentials>(context, listen: false)
      .setCredentials(inputUsername, inputPassword);

  String queryString = "$inputUsername@$inputPassword";
  String encryptionKey = "12345678901234567890123456789012";
  String encryptedQuery = encryptAES(queryString, encryptionKey);
  
  try {
    // Try original URL format first
    String url = "https://yourworldtravel.vn/api/query/login/${Uri.encodeComponent(encryptedQuery)}";
    var response = await fetchFromWeb(url);
    
    if (response.isEmpty) {
      // If original fails, try alternative URL format with query parameters
      final baseUrl = "https://yourworldtravel.vn/api/query/login";
      final queryParams = {
        'q': encryptedQuery,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };
      
      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
      response = await fetchFromWeb(uri.toString());
    }

    if (response.isNotEmpty) {
      List<String> responseParts = response.split('@');
      
      if (responseParts.isNotEmpty && responseParts[0] == "OK") {
        String name = responseParts.length > 1 ? responseParts[1] : 'Unknown';
        String employeeId = responseParts.length > 2 ? responseParts[2] : 'N/A';
        String chamCong = responseParts.length > 3 ? responseParts[3] : 'N/A';
        String queryType = responseParts.length > 4 ? responseParts[4] : '1';
        
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', inputUsername);
        await prefs.setString('password', inputPassword);
        await prefs.setString('cham_cong', chamCong);
        await prefs.setBool('is_authenticated', true);
        
        final userData = {
          'username': inputUsername,
          'name': name,
          'employee_id': employeeId,
          'cham_cong': chamCong,
          'query_type': queryType
        };

        setState(() {
          _isAuthenticated = true;
          _currentUser = userData;
          _loginStatus = '';
        });

        await _userState.setUser(userData);
        await _userState.setLoginResponse(response);
        await _userState.setUpdateResponses('', '', '', '', chamCong);

        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      } else {
        setState(() {
          _loginStatus = 'Đăng nhập thất bại. Vui lòng kiểm tra lại thông tin.';
        });
      }
    } else {
      throw Exception('Không nhận được phản hồi từ máy chủ');
    }
  } catch (e) {
    setState(() {
      _loginStatus = 'Lỗi kết nối. Vui lòng thử lại sau. (${e.toString()})';
    });
  }
}
  void _logout() async {
    await _userState.clearUser();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('password');
    setState(() {
      _isAuthenticated = false;
      _currentUser = null;
      _loginStatus = '';
      _usernameController.clear();
      _passwordController.clear();
    });
    _showLoginDialog();
  }
void _showLoginDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return VideoBackground(
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            bool isLoading = false;

            Future<void> handleLogin() async {
              if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
                setDialogState(() {
                  _loginStatus = 'Vui lòng nhập đầy đủ thông tin';
                });
                return;
              }

              setDialogState(() {
                _loginStatus = 'Đang xác thực...';
                isLoading = true;
              });

              await _login();
            }

            return Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: 400),
                child: AlertDialog(
                  backgroundColor: Colors.white.withOpacity(0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  title: Column(
                    children: [
                      const Text(
                        'Đăng nhập',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '(Lần đầu đăng nhập trên thiết bị, thời gian chờ có thể hơi lâu. Sau khoảng 30s mà vẫn hiện Đang đăng nhập, nên tải lại trang rồi đăng nhập lại chắc chắn được.)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color.fromARGB(255, 149, 0, 0),
                        ),
                      ),
                      if (isLoading) ...[
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ],
                    ],
                  ),
                  content: Container(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Tài khoản',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: Icon(Icons.person),
                            enabled: !isLoading,
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          textInputAction: TextInputAction.next,
                          style: TextStyle(color: Colors.black87),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: Icon(Icons.lock),
                            enabled: !isLoading,
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          obscureText: true,
                          onSubmitted: (_) => handleLogin(),
                          style: TextStyle(color: Colors.black87),
                        ),
                        if (_loginStatus.isNotEmpty) ...[
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _loginStatus.contains('thất bại') 
                                ? Colors.red.withOpacity(0.1)
                                : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _loginStatus.contains('thất bại')
                                  ? Colors.red.withOpacity(0.3)
                                  : Colors.blue.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _loginStatus.contains('thất bại')
                                    ? Icons.error_outline
                                    : Icons.info_outline,
                                  color: _loginStatus.contains('thất bại')
                                    ? Colors.red
                                    : Colors.blue,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _loginStatus,
                                    style: TextStyle(
                                      color: _loginStatus.contains('thất bại')
                                        ? Colors.red
                                        : Colors.blue,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          if (!isLoading)
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Huỷ',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isLoading ? null : handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                              child: isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    'Đăng nhập',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
@override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return VideoBackground(
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Banner(
      message: 'HM GROUP',
      location: BannerLocation.topEnd,
      color: const Color.fromARGB(255, 244, 54, 54),
      child: Scaffold(
        body: _screens[_selectedIndex],
        bottomNavigationBar: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width < 600 ? 8.0 : 16.0,
            vertical: MediaQuery.of(context).size.width < 600 ? 4.0 : 8.0,
          ),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: -5,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BottomNavigationBar(
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Hướng dẫn',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.web),
                    label: 'Vào app',
                  ),
                ],
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                backgroundColor: Colors.white,
                selectedItemColor: const Color.fromARGB(255, 73, 54, 244),
                unselectedItemColor: Colors.grey,
                showSelectedLabels: true,
                showUnselectedLabels: true,
                type: BottomNavigationBarType.fixed,
                elevation: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UserState extends ChangeNotifier {
  static final UserState _instance = UserState._internal();
  factory UserState() => _instance;
  UserState._internal();

  bool _isAuthenticated = false;
  String? _chamCong;
  String? _updateResponse1;
  String? _updateResponse2;
  String? _updateResponse3;
  String? _updateResponse4;
  Map<String, dynamic>? _currentUser;
  String _defaultScreen = 'Chụp ảnh';
  String? _loginResponse;
  String _queryType = '1';

  bool get isAuthenticated => _isAuthenticated;
  String? get chamCong => _chamCong;
  String? get updateResponse1 => _updateResponse1;
  String? get updateResponse2 => _updateResponse2;
  String? get updateResponse3 => _updateResponse3;
  String? get updateResponse4 => _updateResponse4;
  Map<String, dynamic>? get currentUser => _currentUser;
  String get defaultScreen => _defaultScreen;
  String? get loginResponse => _loginResponse;
  String get queryType => _queryType;

Future<void> setUpdateResponses(String response1, String response2, String response3, String response4, String chamCong) async {
    _updateResponse1 = response1;
    _updateResponse2 = response2;
    _updateResponse3 = response3;
    _updateResponse4 = response4;
    _chamCong = chamCong;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('update_response1', response1);
    await prefs.setString('update_response2', response2);
    await prefs.setString('update_response3', response3);
    await prefs.setString('update_response4', response4);
    await prefs.setString('cham_cong', chamCong);
    notifyListeners();
  }

  Future<void> loadUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('current_user');
    _isAuthenticated = prefs.getBool('is_authenticated') ?? false;
    
    if (userData != null) {
      try {
        _currentUser = json.decode(userData);
        _queryType = _currentUser?['query_type'] ?? '1';
        _chamCong = prefs.getString('cham_cong');
        _updateResponse1 = prefs.getString('update_response1') ?? '';
        _updateResponse2 = prefs.getString('update_response2') ?? '';
        _updateResponse3 = prefs.getString('update_response3') ?? '';
        _updateResponse4 = prefs.getString('update_response4') ?? '';
        _defaultScreen = prefs.getString('default_screen') ?? 'Chụp ảnh';
      } catch (e) {
        print('Error loading user data: $e');
        await clearUser();
      }
    }
    notifyListeners();
  }

  Future<void> setUser(Map<String, dynamic> user) async {
    _currentUser = user;
    _isAuthenticated = true;
    _queryType = user['query_type'] ?? '1';
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', json.encode(user));
    await prefs.setBool('is_authenticated', true);
    notifyListeners();
  }

  Future<void> setDefaultScreen(String screen) async {
    _defaultScreen = screen;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_screen', screen);
    notifyListeners();
  }

  Future<void> setLoginResponse(String response) async {
    _loginResponse = response;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('login_response', response);
    notifyListeners();
  }

  Future<void> clearUser() async {
    _currentUser = null;
    _isAuthenticated = false;
    _loginResponse = null;
    _updateResponse1 = null;
    _updateResponse2 = null;
    _updateResponse3 = null;
    _updateResponse4 = null;
    _chamCong = null;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    await prefs.remove('login_response');
    await prefs.remove('update_response1');
    await prefs.remove('update_response2');
    await prefs.remove('update_response3');
    await prefs.remove('update_response4');
    await prefs.remove('cham_cong');
    notifyListeners();
  }
}
class VideoBackground extends StatefulWidget {
  final Widget child;
  final bool showVideo;
  
  const VideoBackground({
    Key? key,
    required this.child,
    this.showVideo = true,
  }) : super(key: key);

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}
class _VideoBackgroundState extends State<VideoBackground> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.network(
      'https://video.wixstatic.com/video/9cf7b1_8236f043004f4db4988ce4fbea62c2a8/720p/mp4/file.mp4',
    );

    await _controller.initialize();
    _controller.setLooping(true);
    _controller.setVolume(0.0);
    _controller.play();
    
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
 @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.showVideo && _isInitialized) ...[
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
          Container(
            color: Colors.black.withOpacity(0.25),
          ),
        ],
        widget.child,
      ],
    );
  }
}