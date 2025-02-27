import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/intro_screen.dart';
import 'screens/webview_screen.dart';
import 'user_credentials.dart';
import 'projectrouter.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'dart:math' show pow, Random;
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'user_state.dart';
import 'multifile.dart';
import 'db_helper.dart';
import 'package:window_manager/window_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:media_kit/media_kit.dart';                    
import 'package:media_kit_video/media_kit_video.dart'; 
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<bool> checkWebView2Installation() async {
  if (!Platform.isWindows) return true;
  try {
    final prefs = await SharedPreferences.getInstance();
    bool webview2Checked = prefs.getBool('webview2_checked') ?? false;
    if (webview2Checked) return true;

    final result = await Process.run('reg', ['query', 'HKLM\\SOFTWARE\\WOW6432Node\\Microsoft\\EdgeUpdate\\Clients\\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', '/ve']);
    if (result.exitCode == 0) {
      await prefs.setBool('webview2_checked', true);
      return true;
    }
    return false;
  } catch (e) {
    return false;
  }
}

void showWebView2InstallDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Cần cài đặt WebView2 Runtime'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ứng dụng cần Microsoft WebView2 Runtime để hoạt động.'),
            SizedBox(height: 10),
            Text('Hướng dẫn cài đặt:'),
            Text('1. Tải và chạy file cài đặt'),
            Text('2. Khởi động lại ứng dụng sau khi hoàn tất'),
            SizedBox(height: 10),
            Text('Lưu ý: Cài đặt này chỉ cần thực hiện một lần.', 
              style: TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Tải WebView2 Runtime'),
            onPressed: () async {
              const url = 'https://go.microsoft.com/fwlink/p/?LinkId=2124703';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url), 
                  mode: LaunchMode.externalApplication);
              }
            },
          ),
          TextButton(
            child: const Text('Đóng'),
            onPressed: () => exit(0),
          ),
        ],
      );
    },
  );
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
    if (Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    await Future.delayed(const Duration(milliseconds: 100));

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      await windowManager.ensureInitialized();
      WindowOptions windowOptions = const WindowOptions(
        size: Size(1024, 768),
        minimumSize: Size(800, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.maximize();
      });
    }

    // Check WebView2 installation on Windows
    if (Platform.isWindows) {
      bool hasWebView2 = await checkWebView2Installation();
      if (!hasWebView2) {
        runApp(
          MaterialApp(
            home: Builder(
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showWebView2InstallDialog(context);
                });
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ),
        );
        return;
      }
    }

    // Initialize app dependencies
    await MultiFileAccessUtility.initialize();
    final dbHelper = DBHelper();
    await dbHelper.database;
    await dbHelper.checkDatabaseStatus();
    final userState = UserState();
    //await checkAppVersion();

    // Run the app with providers
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: userState),
          ChangeNotifierProvider(create: (_) => UserCredentials()),
        ],
        child: const MyApp(),
      ),
    );
    
    // Check app version after app is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await checkAppVersion();
    });
    
  } catch (e, stackTrace) {
    
    // Show error UI if initialization fails
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failed to initialize application',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    exit(0); // Or implement retry logic
                  },
                  child: const Text('Close Application'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,  
      title: 'HM GROUP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainScreen(),
    );
  }
}
Future<void> checkAppVersion() async {
  try {
    // Get current app version
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version;
    String latestVersion = 'Unknown';
    bool fetchSuccess = false;

    // Fetch latest version
    try {
      final response = await http.get(
        Uri.parse('https://yourworldtravel.vn/api/document/versiondesktop.txt')
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        latestVersion = response.body.trim();
        fetchSuccess = true;
      }
    } catch (e) {
      print('Error fetching version: $e');
    }

    // Always show version info dialog
    await showDialog(
      context: navigatorKey.currentContext!,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Thông tin phiên bản'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phiên bản hiện tại: $currentVersion'),
              Text('Phiên bản mới nhất: $latestVersion'),
              const SizedBox(height: 10),
              fetchSuccess 
                ? (currentVersion != latestVersion 
                  ? const Text('Cần cập nhật phiên bản mới!', 
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                  : const Text('Ứng dụng đã là phiên bản mới nhất.', 
                      style: TextStyle(color: Colors.green)))
                : const Text('Không thể kiểm tra phiên bản mới nhất.', 
                    style: TextStyle(color: Colors.orange)),
            ],
          ),
          actions: <Widget>[
            if (fetchSuccess && currentVersion != latestVersion) Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.laptop_mac),
                    label: const Text('Tải bản macOS'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color.fromARGB(255, 227, 255, 255),
                    ),
                    onPressed: () async {
                      final url = Uri.parse('https://storage.googleapis.com/times1/DocumentApp/HMGROUPmac.zip');
                      try {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } catch (e) {
                        print('Error launching URL: $e');
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.laptop),
                    label: const Text('Tải bản Windows'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color.fromARGB(255, 250, 234, 255),
                    ),
                    onPressed: () async {
                      final url = Uri.parse('https://storage.googleapis.com/times1/DocumentApp/HMGROUPwin.zip');
                      try {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } catch (e) {
                        print('Error launching URL: $e');
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
            TextButton(
              child: const Text('Đóng'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  } catch (e) {
    print('Error checking version: $e');
  }
}
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}
class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1;
  bool _isAuthenticated = false;
  String _loginStatus = '';
  Map<String, dynamic>? _currentUser;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  Timer? _tokenRefreshTimer;
   UserState get _userState => Provider.of<UserState>(context, listen: false);
  List<Widget> get _screens => [
  ProjectRouter(userState: _userState),
  const WebViewScreen(),
  IntroScreen(userData: _currentUser),
];

  @override
  void initState() {
    super.initState();
    _initializeAuth();
    _setupTokenRefresh();
  }
  void _setupTokenRefresh() {
    AppAuthentication.generateToken();
    _tokenRefreshTimer = Timer.periodic(
      const Duration(hours: 23),
      (_) => AppAuthentication.generateToken()
    );
  }
  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    super.dispose();
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
  final credentials = Provider.of<UserCredentials>(context, listen: false);
  
  if (credentials.username.isNotEmpty && credentials.password.isNotEmpty) {
    setState(() {
      _usernameController.text = credentials.username;
      _passwordController.text = credentials.password;
    });
    await _login();
  } else {
    _showLoginDialog();
  }
}
Future<String> fetchFromWeb(String url) async {
  try {
    // Get UserState from Provider
    final userState = Provider.of<UserState>(context, listen: false);
    
    // Generate new token if needed
    final tokenData = await AppAuthentication.generateToken();
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Authorization': 'Bearer ${tokenData['token'] ?? ''}',
        'X-Timestamp': tokenData['timestamp'] ?? ''
      },
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw TimeoutException('Request timed out');
      },
    );
    
    if (response.statusCode == 200) {
      return response.body;
    } else if (response.statusCode == 401) {
      // Token expired, generate new one
      final newTokenData = await AppAuthentication.generateToken();
      
      // Retry request with new token
      final retryResponse = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': '*/*',
          'Authorization': 'Bearer ${newTokenData['token'] ?? ''}',
          'X-Timestamp': newTokenData['timestamp'] ?? ''
        },
      );
      
      if (retryResponse.statusCode == 200) {
        return retryResponse.body;
      }
    }
    throw Exception('Request failed with status: ${response.statusCode}');
  } catch (e) {
    print('Request failed: $e');
    return '';
  }
}
Future<bool> verifyStoredToken() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('auth_token');
  String? timestamp = prefs.getString('token_timestamp');
  
  if (token == null || timestamp == null) {
    return false;
  }
  final tokenTime = int.parse(timestamp);
  if (DateTime.now().millisecondsSinceEpoch - tokenTime > 24 * 3600000) {
    return false;
  }
  
  return true;
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

  try {
    // Save credentials first
    final credentials = Provider.of<UserCredentials>(context, listen: false);
    await credentials.setCredentials(inputUsername, inputPassword);

    final tokenData = await AppAuthentication.generateToken();
    String verificationUrl = "https://hmclourdrun1-81200125587.asia-southeast1.run.app/tokenweb";
    
    final verificationResponse = await http.post(
      Uri.parse(verificationUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': '*/*',
      },
      body: json.encode({
        'token': tokenData['token'] ?? '',
        'timestamp': tokenData['timestamp'] ?? ''
      })
    );
    
    if (verificationResponse.statusCode != 200) {
      throw Exception('Token verification failed: ${verificationResponse.body}');
    }

    // Save credentials using UserCredentials provider
    await Provider.of<UserCredentials>(context, listen: false)
        .setCredentials(inputUsername, inputPassword);

    String queryString = "$inputUsername@$inputPassword";
    String encryptionKey = "12345678901234567890123456789012";
    String encryptedQuery = encryptAES(queryString, encryptionKey);
    
    String url = "https://hmclourdrun1-81200125587.asia-southeast1.run.app/loginweb/${Uri.encodeComponent(encryptedQuery)}";
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Authorization': 'Bearer ${tokenData['token'] ?? ''}',
        'X-Timestamp': tokenData['timestamp'] ?? ''
      },
    );

    if (response.body.isEmpty) {
      final baseUrl = "https://hmclourdrun1-81200125587.asia-southeast1.run.app/loginweb";
      final queryParams = {
        'q': encryptedQuery,
      };
      
      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
      final altResponse = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': '*/*',
          'Authorization': 'Bearer ${tokenData['token'] ?? ''}',
          'X-Timestamp': tokenData['timestamp'] ?? ''
        },
      );
      
      if (altResponse.statusCode == 200 && altResponse.body.isNotEmpty) {
        return await processLoginResponse(altResponse.body);
      } else {
        throw Exception('Alternative login request failed: ${altResponse.statusCode}');
      }
    }

    if (response.body.isNotEmpty) {
      return await processLoginResponse(response.body);
    } else {
      throw Exception('Không nhận được phản hồi từ máy chủ');
    }
  } catch (e) {
    print('Detailed error: $e');
    setState(() {
      _loginStatus = 'Lỗi kết nối. Vui lòng thử lại sau. (${e.toString()})';
    });
  }
}

Future<void> processLoginResponse(String responseBody) async {
  List<String> responseParts = responseBody.split('@');
  
  if (responseParts.isNotEmpty && responseParts[0] == "OK") {
    String name = responseParts.length > 1 ? responseParts[1] : 'Unknown';
    String employeeId = responseParts.length > 2 ? responseParts[2] : 'N/A';
    String chamCong = responseParts.length > 3 ? responseParts[3] : 'N/A';
    String queryType = responseParts.length > 4 ? responseParts[4] : '1';
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _usernameController.text.trim().toLowerCase());
    await prefs.setString('password', _passwordController.text.trim().toLowerCase());
    await prefs.setString('cham_cong', chamCong);
    await prefs.setBool('is_authenticated', true);
    
    final userData = {
      'username': _usernameController.text.trim().toLowerCase(),
      'name': name,
      'employee_id': employeeId,
      'cham_cong': chamCong,
      'queryType': queryType
    };

    setState(() {
      _isAuthenticated = true;
      _currentUser = userData;
      _loginStatus = '';
      _selectedIndex = 1;
    });

    await _userState.setUser(userData);
    await _userState.setLoginResponse(responseBody);
    await _userState.setUpdateResponses('', '', '', '', chamCong);

    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  } else if (responseParts.isNotEmpty && responseParts[0] == "WRONG") {
    // Handle WRONG response specifically
    setState(() {
      _loginStatus = 'Sai tên đăng nhập hoặc mật khẩu. Vui lòng kiểm tra lại thông tin hoặc sử dụng chức năng đặt lại mật khẩu nếu bạn quên mật khẩu.';
    });
  } else {
    setState(() {
      _loginStatus = 'Đăng nhập thất bại. Vui lòng kiểm tra lại thông tin.';
    });
  }
}
void processResponse(String responseBody) async {
  if (responseBody.isNotEmpty) {
    List<String> responseParts = responseBody.split('@');
    
    if (responseParts.isNotEmpty && responseParts[0] == "OK") {
      String name = responseParts.length > 1 ? responseParts[1] : 'Unknown';
      String employeeId = responseParts.length > 2 ? responseParts[2] : 'N/A';
      String chamCong = responseParts.length > 3 ? responseParts[3] : 'N/A';
      String queryType = responseParts.length > 4 ? responseParts[4] : '1';
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', _usernameController.text.trim().toLowerCase());
      await prefs.setString('password', _passwordController.text.trim().toLowerCase());
      await prefs.setString('cham_cong', chamCong);
      await prefs.setBool('is_authenticated', true);
      
      final userData = {
        'username': _usernameController.text.trim().toLowerCase(),
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
      await _userState.setLoginResponse(responseBody);
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
}
void _logout() async {
  await _userState.clearUser();
  
  final credentials = Provider.of<UserCredentials>(context, listen: false);
  await credentials.clearCredentials();
  
  setState(() {
    _isAuthenticated = false;
    _currentUser = null;
    _loginStatus = '';
    _usernameController.clear();
    _passwordController.clear();
  });
  _showLoginDialog();
}
void _showResetPasswordDialog() {
  final TextEditingController resetUsernameController = TextEditingController();
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      // Use ValueNotifier to manage loading state
      final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 5,
                    blurRadius: 15,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ValueListenableBuilder<bool>(
                valueListenable: isLoadingNotifier,
                builder: (context, isLoading, child) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'Quản lý mật khẩu',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: TextField(
                          controller: resetUsernameController,
                          decoration: InputDecoration(
                            labelText: 'Tài khoản',
                            labelStyle: TextStyle(color: Colors.blue[800]),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            prefixIcon: Icon(Icons.person_outline, color: Colors.blue[800]),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9.@_-]')),
                            LengthLimitingTextInputFormatter(50),
                          ],
                          enabled: !isLoading,
                        ),
                      ),
                      SizedBox(height: 20),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Mật khẩu mới sẽ được gửi tới số điện thoại nhân viên của bạn (nếu có hồ sơ), vui lòng kiểm tra và sử dụng mật khẩu mới (đổi cho app Group và Time)\nVui lòng bấm Tải lại trang sau khi thành công',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[800],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 25),
                      
                      // Loading or Button state
                      isLoading 
                        ? Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                'Đang xử lý yêu cầu...',
                                style: TextStyle(
                                  color: Colors.blue[800],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                        padding: EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 4,
                                      ),
                                      onPressed: isLoading ? null : () async {
                                        if (resetUsernameController.text.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Vui lòng nhập tài khoản'), backgroundColor: Colors.red)
                                          );
                                          return;
                                        }
                                        
                                        // Set loading state
                                        isLoadingNotifier.value = true;
                                        
                                        try {
                                          final tokenData = await AppAuthentication.generateToken();
                                          await http.post(
                                            Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/matkhauquen/${resetUsernameController.text.trim()}'),
                                            headers: {
                                              'Content-Type': 'application/json',
                                              'Accept': '*/*',
                                              'Authorization': 'Bearer ${tokenData['token'] ?? ''}',
                                              'X-Timestamp': tokenData['timestamp'] ?? ''
                                            },
                                          );
                                          
                                          await Future.delayed(Duration(seconds: 10));
                                          
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Yêu cầu lấy lại mật khẩu đã được gửi'), backgroundColor: Colors.green)
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Có lỗi xảy ra'), backgroundColor: Colors.red)
                                          );
                                        } finally {
                                          // Reset loading state
                                          isLoadingNotifier.value = false;
                                        }
                                      },
                                      child: Text(
                                        'Quên \nmật khẩu',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.indigo,
                                        padding: EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 4,
                                      ),
                                      onPressed: isLoading ? null : () async {
                                        if (resetUsernameController.text.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Vui lòng nhập tài khoản'), backgroundColor: Colors.red)
                                          );
                                          return;
                                        }
                                        
                                        // Set loading state
                                        isLoadingNotifier.value = true;
                                        
                                        try {
                                          final tokenData = await AppAuthentication.generateToken();
                                          await http.post(
                                            Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/matkhaureset/${resetUsernameController.text.trim()}'),
                                            headers: {
                                              'Content-Type': 'application/json',
                                              'Accept': '*/*',
                                              'Authorization': 'Bearer ${tokenData['token'] ?? ''}',
                                              'X-Timestamp': tokenData['timestamp'] ?? ''
                                            },
                                          );
                                          
                                          await Future.delayed(Duration(seconds: 10));
                                          
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Yêu cầu đặt lại mật khẩu đã được gửi'), backgroundColor: Colors.green)
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Có lỗi xảy ra'), backgroundColor: Colors.red)
                                          );
                                        } finally {
                                          // Reset loading state
                                          isLoadingNotifier.value = false;
                                        }
                                      },
                                      child: Text(
                                        'Đặt lại\nmật khẩu',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Huỷ', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                              ),
                            ],
                          ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      );
    },
  );
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
            bool showKeypad = true;

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
                constraints: const BoxConstraints(maxWidth: 400),
                child: SingleChildScrollView(
                  child: AlertDialog(
                    backgroundColor: Colors.white.withOpacity(0.9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    title: Column(
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          height: 130,
                          width: 130,
                          fit: BoxFit.contain,
                        ),
                        const Text(
                          'Đăng nhập tài khoản HM',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24, 
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '(Lần đầu đăng nhập trên thiết bị, thời gian chờ có thể hơi lâu.\nVui lòng tắt ứng dụng khi hết ngày, mở lại vào ngày mới .)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: Color.fromARGB(255, 149, 0, 0),
                          ),
                        ),
                        if (isLoading) ...[
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
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
    prefixIcon: const Icon(Icons.person),
    enabled: !isLoading,
    filled: true,
    fillColor: Colors.white,
  ),
  inputFormatters: [
    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9.@_-]')),
    LengthLimitingTextInputFormatter(50),
  ],
  textInputAction: TextInputAction.next,
  style: const TextStyle(color: Colors.black87),
),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                showKeypad = !showKeypad;
                              });
                            },
                            child: TextField(
  controller: _passwordController,
  decoration: InputDecoration(
    labelText: 'Mật khẩu',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    prefixIcon: const Icon(Icons.lock),
    suffixIcon: IconButton(
      icon: Icon(showKeypad ? Icons.keyboard_hide : Icons.keyboard),
      onPressed: () {
        setDialogState(() {
          showKeypad = !showKeypad;
        });
      },
    ),
    enabled: !isLoading,
    filled: true,
    fillColor: Colors.white,
  ),
  inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9.@]')),
                        LengthLimitingTextInputFormatter(50),
                      ],
  obscureText: true,
  onSubmitted: (_) => handleLogin(),
  style: const TextStyle(color: Colors.black87),
),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showResetPasswordDialog();
                            },
                            child: const Text(
                              'Quên / Đặt lại mật khẩu',
                              style: TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          if (_loginStatus.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
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
                                  const SizedBox(width: 8),
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
                  ),
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
      icon: Icon(Icons.folder),
      label: 'Dự án',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.web),
      label: 'Công việc',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: 'Hướng dẫn',
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
  late final player = Player();
  late final controller = VideoController(player);
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
  try {
    print('Attempting to load video from URL');
    // Set up the video
    await player.open(Media(
      'https://storage.googleapis.com/times1/DocumentApp/lychee.mp4'
    ));
    
    print('Video loaded successfully');
    
    player.stream.playing.listen((playing) {
      print('Video playing state changed: $playing');
      if (playing && mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
    
    // Set volume to 0
    player.setVolume(0);
    
    // Handle looping through playback ended event
    player.stream.completed.listen((_) {
      player.seek(Duration.zero);
      player.play();
    });
    
  } catch (e) {
    print('Video initialization error: $e');
    if (mounted) {
      setState(() {
        _isInitialized = false;
      });
    }
  }
}

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.showVideo && _isInitialized) ...[
          SizedBox.expand(
            child: Video(
              controller: controller,
              fit: BoxFit.cover,
            ),
          ),
          Container(
            color: Colors.black.withOpacity(0.25),
          ),
        ] else ...[
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue[900]!,
                  Colors.blue[600]!,
                ],
              ),
            ),
          ),
        ],
        widget.child,
      ],
    );
  }
}
class AppAuthentication {
  static const String _secretKey = "12345678901234567890123456789012";
  
  static Future<Map<String, String>> generateToken() async {
    // Get device identifier or generate instance ID
    final prefs = await SharedPreferences.getInstance();
    String? instanceId = prefs.getString('instance_id');
    final random = Random();
    
    if (instanceId == null) {
      instanceId = base64Encode(List<int>.generate(32, (_) => random.nextInt(256)));
      await prefs.setString('instance_id', instanceId);
    }
    
    // Create payload
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final nonce = base64Encode(List<int>.generate(16, (_) => random.nextInt(256)));
    
    final payload = {
      'instance_id': instanceId,
      'timestamp': timestamp,
      'nonce': nonce
    };
    
    // Generate signature
    final payloadString = json.encode(payload);
    final hmac = Hmac(sha256, utf8.encode(_secretKey));
    final signature = base64Encode(hmac.convert(utf8.encode(payloadString)).bytes);
    
    // Combine and encrypt final token
    final tokenData = {
      'payload': payload,
      'signature': signature
    };
    
    final token = encryptAES(json.encode(tokenData), _secretKey);
    
    // Store token for reuse
    await prefs.setString('auth_token', token);
    await prefs.setString('token_timestamp', timestamp);
    
    return {
      'token': token,
      'timestamp': timestamp
    };
  }

  static String encryptAES(String plainText, String key) {
    final keyBytes = encrypt.Key.fromUtf8(key);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(keyBytes, mode: encrypt.AESMode.cbc, padding: 'PKCS7'));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    final concatenated = iv.bytes + encrypted.bytes;
    return base64.encode(concatenated);
  }
}