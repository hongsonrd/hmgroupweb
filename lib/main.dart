import 'package:flutter/material.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    _loadSavedCredentials();
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
      _login();
    } else {
      _showLoginDialog();
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
      final url = "https://yourworldtravel.vn/api/query/login/${Uri.encodeComponent(encryptedQuery)}";
      final response = await fetchFromWeb(url);

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
          
          setState(() {
            _isAuthenticated = true;
            _currentUser = {
              'username': inputUsername,
              'name': name,
              'employee_id': employeeId,
              'cham_cong': chamCong,
              'query_type': queryType
            };
            _loginStatus = '';
          });

          await _userState.setUser(_currentUser!);
          await _userState.setLoginResponse(response);
          await _userState.setUpdateResponses('', '', '', '', chamCong);

          Navigator.of(context).pop();
        } else {
          setState(() {
            _loginStatus = 'Đăng nhập thất bại. Vui lòng kiểm tra lại thông tin.';
          });
        }
      } else {
        setState(() {
          _loginStatus = 'Lỗi kết nối. Vui lòng thử lại sau.';
        });
      }
    } catch (e) {
      setState(() {
        _loginStatus = 'Lỗi kết nối. Vui lòng thử lại sau.';
      });
    }
  }

  Future<String> fetchFromWeb(String url) async {
    try {
      if (kIsWeb) {
        final proxyUrl = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
        final response = await html.HttpRequest.request(
          proxyUrl,
          method: 'GET',
          requestHeaders: {
            'Content-Type': 'application/json',
            'Accept': '*/*',
          },
        );
        return response.responseText ?? '';
      } else {
        final response = await http.get(Uri.parse(url));
        return response.body;
      }
    } catch (e) {
      print('Request failed: $e');
      return '';
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
        return StatefulBuilder(
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

            return AlertDialog(
              title: Column(
                children: [
                  const Text('Đăng nhập',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                    const Text('(Lần đầu đăng nhập trên thiết bị, thời gian chờ có thể hơi lâu)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                  if (isLoading) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(),
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
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                        enabled: !isLoading,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                        enabled: !isLoading,
                      ),
                      obscureText: true,
                      onSubmitted: (_) => handleLogin(),
                    ),
                    if (_loginStatus.isNotEmpty) ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _loginStatus.contains('thất bại') ? 
                            Colors.red.withOpacity(0.1) : 
                            Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _loginStatus.contains('thất bại') ? 
                                Icons.error_outline : 
                                Icons.info_outline,
                              color: _loginStatus.contains('thất bại') ? 
                                Colors.red : 
                                Colors.blue,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _loginStatus,
                                style: TextStyle(
                                  color: _loginStatus.contains('thất bại') ? 
                                    Colors.red : 
                                    Colors.blue,
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
                Row(
                  children: [
                    if (!isLoading) 
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Huỷ'),
                      ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoading ? null : handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(vertical: 12),
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
                            : Text('Đăng nhập',
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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
      _currentUser = json.decode(userData);
      _queryType = _currentUser?['query_type'] ?? '1';
    }
    _updateResponse1 = prefs.getString('update_response1') ?? '';
    _updateResponse2 = prefs.getString('update_response2') ?? '';
    _updateResponse3 = prefs.getString('update_response3') ?? '';
    _updateResponse4 = prefs.getString('update_response4') ?? '';
    _chamCong = prefs.getString('cham_cong') ?? '';
    _defaultScreen = prefs.getString('default_screen') ?? 'Chụp ảnh';
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