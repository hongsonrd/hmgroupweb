import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/intro_screen.dart';
import 'screens/webview_screen.dart';
import 'screens/webview_screenKH.dart';

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
import 'floating_draggable_icon.dart';
import 'projectdirector.dart';
import 'projectdirector2.dart';
import 'map_project.dart';
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
Future<void> runDiagnosticMode() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final report = StringBuffer();
  report.writeln('=== HM GROUP DIAGNOSTIC REPORT ===');
  report.writeln('Timestamp: ${DateTime.now()}');
  report.writeln('App Version: 1.2.9');
  report.writeln('');
  
  // System info
  report.writeln('[SYSTEM INFO]');
  report.writeln('Platform: ${Platform.operatingSystem}');
  report.writeln('Version: ${Platform.operatingSystemVersion}');
  report.writeln('Locale: ${Platform.localeName}');
  report.writeln('Executable: ${Platform.resolvedExecutable}');
  report.writeln('Path length: ${Platform.resolvedExecutable.length} characters');
  report.writeln('');
  
  // Architecture
  report.writeln('[ARCHITECTURE]');
  try {
    final result = await Process.run('wmic', ['OS', 'get', 'OSArchitecture']);
    if (result.exitCode == 0) {
      report.writeln('Architecture: ${result.stdout.toString().trim()}');
      report.writeln('Status: ✓');
    }
  } catch (e) {
    report.writeln('Error: $e');
    report.writeln('Status: ✗');
  }
  report.writeln('');
  
  // VC++ Redistributable check
  report.writeln('[VC++ REDISTRIBUTABLE]');
  try {
    final result = await Process.run('reg', [
      'query',
      'HKLM\\SOFTWARE\\Microsoft\\VisualStudio\\14.0\\VC\\Runtimes\\X64',
      '/v',
      'Version'
    ]);
    if (result.exitCode == 0) {
      report.writeln('VC++ Redistributable: Installed ✓');
      report.writeln('Details: ${result.stdout}');
    } else {
      report.writeln('VC++ Redistributable: NOT FOUND ✗');
      report.writeln('This may cause issues!');
    }
  } catch (e) {
    report.writeln('Error checking: $e');
    report.writeln('Status: ✗');
  }
  report.writeln('');
  
  // Controlled Folder Access
  report.writeln('[CONTROLLED FOLDER ACCESS]');
  try {
    final result = await Process.run('powershell', [
      '-Command',
      'Get-MpPreference | Select-Object -ExpandProperty EnableControlledFolderAccess'
    ]);
    final status = result.stdout.toString().trim();
    if (status == '0') {
      report.writeln('Status: Disabled ✓');
    } else if (status == '1' || status == '2') {
      report.writeln('Status: ENABLED ✗ (This is blocking the app!)');
      report.writeln('ACTION REQUIRED: Add HMGroup.exe to allowed apps in Windows Security');
    } else {
      report.writeln('Status: Unknown');
    }
  } catch (e) {
    report.writeln('Error checking: $e');
  }
  report.writeln('');
  
  // SmartScreen / Zone Identifier
  report.writeln('[SMARTSCREEN / DOWNLOAD BLOCK]');
  try {
    final result = await Process.run('powershell', [
      '-Command',
      'Get-Content "${Platform.resolvedExecutable}" -Stream Zone.Identifier -ErrorAction SilentlyContinue'
    ]);
    if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
      report.writeln('Status: File marked as downloaded from internet ✗');
      report.writeln('This may cause security restrictions!');
      report.writeln('Details: ${result.stdout}');
    } else {
      report.writeln('Status: Not marked ✓');
    }
  } catch (e) {
    report.writeln('Status: Not marked ✓');
  }
  report.writeln('');
  
  // Temp directory test
  report.writeln('[TEMP DIRECTORY]');
  try {
    final tempDir = await getTemporaryDirectory();
    report.writeln('Path: ${tempDir.path}');
    
    final testFile = File('${tempDir.path}/hm_test_${DateTime.now().millisecondsSinceEpoch}.tmp');
    await testFile.writeAsString('test data');
    
    if (await testFile.exists()) {
      report.writeln('Write test: SUCCESS ✓');
      await testFile.delete();
      report.writeln('Delete test: SUCCESS ✓');
    } else {
      report.writeln('Write test: FAILED ✗');
    }
  } catch (e) {
    report.writeln('Temp directory test: FAILED ✗');
    report.writeln('Error: $e');
  }
  report.writeln('');
  
  // SQLite FFI test
  report.writeln('[SQLITE FFI]');
  try {
    if (Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      report.writeln('FFI Initialization: SUCCESS ✓');
      
      // Try to create a test database
      final dbHelper = DBHelper();
      await dbHelper.database;
      report.writeln('Database creation: SUCCESS ✓');
    }
  } catch (e) {
    report.writeln('SQLite initialization: FAILED ✗');
    report.writeln('Error: $e');
    report.writeln('This is likely the main issue!');
  }
  report.writeln('');
  
  // MediaKit test
  report.writeln('[MEDIA KIT]');
  try {
    MediaKit.ensureInitialized();
    report.writeln('Initialization: SUCCESS ✓');
  } catch (e) {
    report.writeln('MediaKit initialization: FAILED ✗');
    report.writeln('Error: $e');
    report.writeln('(This is non-critical - video background only)');
  }
  report.writeln('');
  
  // Assets test
  report.writeln('[ASSETS TEST]');
  final criticalAssets = [
    'assets/logo.png',
    'assets/iconAI.png',
    'assets/appbackgrid.png',
    'assets/hotellogo.png',
  ];
  
  int successCount = 0;
  int failCount = 0;
  
  for (final asset in criticalAssets) {
    try {
      final data = await rootBundle.load(asset);
      report.writeln('✓ $asset (${data.lengthInBytes} bytes)');
      successCount++;
    } catch (e) {
      report.writeln('✗ $asset - FAILED');
      report.writeln('  Error: $e');
      failCount++;
    }
  }
  
  report.writeln('');
  report.writeln('Assets Summary: $successCount OK, $failCount Failed');
  
  if (failCount > 0) {
    report.writeln('ACTION REQUIRED: Re-extract the application files!');
  }
  report.writeln('');
  
  // WebView2 check
  report.writeln('[WEBVIEW2 RUNTIME]');
  try {
    final result = await Process.run('reg', [
      'query',
      'HKLM\\SOFTWARE\\WOW6432Node\\Microsoft\\EdgeUpdate\\Clients\\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
      '/ve'
    ]);
    if (result.exitCode == 0) {
      report.writeln('WebView2 Runtime: Installed ✓');
    } else {
      report.writeln('WebView2 Runtime: NOT FOUND ✗');
      report.writeln('ACTION REQUIRED: Install WebView2 Runtime');
    }
  } catch (e) {
    report.writeln('Error checking: $e');
  }
  report.writeln('');
  
  // Disk space check
  report.writeln('[DISK SPACE]');
  try {
    final appDrive = Platform.resolvedExecutable.substring(0, 2);
    final result = await Process.run('wmic', [
      'logicaldisk',
      'where',
      'DeviceID="$appDrive"',
      'get',
      'FreeSpace,Size'
    ]);
    report.writeln('Drive $appDrive:');
    report.writeln(result.stdout);
  } catch (e) {
    report.writeln('Error checking: $e');
  }
  report.writeln('');
  
  report.writeln('=== END OF DIAGNOSTIC REPORT ===');
  report.writeln('');
  report.writeln('NEXT STEPS:');
  report.writeln('1. Save this report');
  report.writeln('2. Look for any ✗ marks above');
  report.writeln('3. Follow the "ACTION REQUIRED" instructions');
  report.writeln('4. Send this report to support if issues persist');
  
  // Save report to file
  String reportPath = '';
  try {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final reportFile = File('${tempDir.path}/HMGroup_Diagnostic_$timestamp.txt');
    await reportFile.writeAsString(report.toString());
    reportPath = reportFile.path;
    
    print('\n' + '='*60);
    print(report.toString());
    print('='*60);
    print('\n✓ Diagnostic report saved to: $reportPath');
    
    // Try to open in notepad
    try {
      await Process.start('notepad.exe', [reportPath], mode: ProcessStartMode.detached);
      print('✓ Opening report in Notepad...');
    } catch (e) {
      print('Could not open Notepad: $e');
    }
    
  } catch (e) {
    print('\n' + '='*60);
    print(report.toString());
    print('='*60);
    print('\n✗ Could not save report to file: $e');
  }
  
  // Keep console open
  print('\nPress Enter to exit...');
  stdin.readLineSync();
  
  exit(0);
}
void main(List<String> args) async {
  if (args.contains('--diagnostic') || args.contains('-d')) {
    await runDiagnosticMode();
    return;
  }
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
        size: Size(1280, 720),
        minimumSize: Size(860, 480),
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
    bool isSignificantlyOutdated = false;
    bool isCurrentVersionNewer = false;

    // Fetch latest version with 5-second timeout
    try {
      final response = await http.get(
        Uri.parse('https://yourworldtravel.vn/api/document/versiondesktop.txt')
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        latestVersion = response.body.trim();
        fetchSuccess = true;
        
        // Compare versions more accurately
        try {
          List<int> currentParts = currentVersion.split('.').map((part) => int.parse(part)).toList();
          List<int> latestParts = latestVersion.split('.').map((part) => int.parse(part)).toList();
          
          // Ensure both version arrays have the same length by padding with zeros
          while (currentParts.length < 3) currentParts.add(0);
          while (latestParts.length < 3) latestParts.add(0);
          while (currentParts.length < latestParts.length) currentParts.add(0);
          while (latestParts.length < currentParts.length) latestParts.add(0);
          
          // Compare versions part by part
          int versionComparison = 0;
          for (int i = 0; i < currentParts.length; i++) {
            if (currentParts[i] > latestParts[i]) {
              versionComparison = 1; // Current is newer
              break;
            } else if (currentParts[i] < latestParts[i]) {
              versionComparison = -1; // Current is older
              break;
            }
          }
          
          if (versionComparison > 0) {
            isCurrentVersionNewer = true;
          } else if (versionComparison < 0) {
            // Check if significantly outdated (5+ versions behind in patch level)
            if (currentParts[0] < latestParts[0] || 
               (currentParts[0] == latestParts[0] && currentParts[1] < latestParts[1] - 5) ||
               (currentParts[0] == latestParts[0] && currentParts[1] == latestParts[1] && currentParts[2] < latestParts[2] - 5)) {
              isSignificantlyOutdated = true;
            }
          }
        } catch (e) {
          print('Error comparing versions: $e');
        }
      }
    } catch (e) {
      print('Error fetching version: $e');
    }

    // Only show dialog if current version is not newer than server version
    if (!isCurrentVersionNewer) {
      // Show version info dialog
      await showDialog(
        context: navigatorKey.currentContext!,
        barrierDismissible: !isSignificantlyOutdated,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async => !isSignificantlyOutdated,
            child: AlertDialog(
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
                      ? Text(
                          isSignificantlyOutdated 
                            ? 'Phiên bản quá cũ! Cần cập nhật ngay!' 
                            : 'Cần cập nhật phiên bản mới!',
                          style: TextStyle(
                            color: isSignificantlyOutdated ? Colors.red[900] : Colors.red, 
                            fontWeight: FontWeight.bold
                          )
                        )
                      : const Text('Ứng dụng đã là phiên bản mới nhất.', 
                          style: TextStyle(color: Colors.green)))
                    : const Text('Không thể kiểm tra phiên bản mới nhất.', 
                        style: TextStyle(color: Colors.orange)),
                        
                  if (isSignificantlyOutdated) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red)
                      ),
                      child: const Text(
                        'Phiên bản của bạn quá cũ. Vui lòng cập nhật để tiếp tục sử dụng ứng dụng.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
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
                          if (!isSignificantlyOutdated) {
                            Navigator.of(context).pop();
                          }
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
                          if (!isSignificantlyOutdated) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (!isSignificantlyOutdated) TextButton(
                  child: const Text('Đóng'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // Optional: Print a message for debugging when current version is newer
      print('Current version ($currentVersion) is newer than server version ($latestVersion). No update dialog shown.');
    }
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
  Timer? _loadingTimeoutTimer;
  
  UserState get _userState => Provider.of<UserState>(context, listen: false);
  
  List<Widget> get _screens => [
    ProjectRouter(userState: _userState),
    const WebViewScreen(),
    const HMAIScreen(), 
    IntroScreen(userData: _currentUser),
    const WebViewScreenKH(),
  ];

  @override
  void initState() {
    super.initState();
    
    // Start a timer to detect if we're stuck in loading state
    _loadingTimeoutTimer = Timer(const Duration(seconds: 5), () {
      // If we're still not authenticated after 5 seconds, clear data and force login
      if (!_isAuthenticated && mounted) {
        print("Loading timeout reached - forcing new login");
        _forceNewLogin();
      }
    });
    
    // Start authentication process
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeAuth();
      _setupTokenRefresh();
    });
  }
   void _setupTokenRefresh() {
    AppAuthentication.generateToken();
    _tokenRefreshTimer = Timer.periodic(
      const Duration(hours: 23),
      (_) => AppAuthentication.generateToken()
    );
  }
  // Force new login by clearing all saved data
  Future<void> _forceNewLogin() async {
    print("Forcing new login by clearing all saved data");
    
    try {
      // Clear UserState
      await _userState.clearUser();
      
      // Clear UserCredentials
      final credentials = Provider.of<UserCredentials>(context, listen: false);
      await credentials.clearCredentials();
      
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Update state to show login dialog
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _currentUser = null;
          _loginStatus = '';
          _usernameController.clear();
          _passwordController.clear();
        });
        
        // Show login dialog
        _showLoginDialog();
      }
    } catch (e) {
      print("Error while forcing new login: $e");
      // Still try to show login dialog even if clearing data failed
      if (mounted) {
        _showLoginDialog();
      }
    }
  }
  
  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    _loadingTimeoutTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _initializeAuth() async {
    try {
      await _userState.loadUser();
      
      if (_userState.isAuthenticated && _userState.currentUser != null) {
        // Successfully authenticated, cancel timeout timer
        _loadingTimeoutTimer?.cancel();
        
        if (mounted) {
          setState(() {
            _isAuthenticated = true;
            _currentUser = _userState.currentUser;
            print("Authentication successful, setting _isAuthenticated to true");
          });
        }
      } else {
        await _loadSavedCredentials();
      }
    } catch (e) {
      print('Authentication error: $e');
      _forceNewLogin();
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
    
    try {
      await _login();
      // If login successful, cancel the timeout timer
      _loadingTimeoutTimer?.cancel();
    } catch (e) {
      print("Error in _loadSavedCredentials: $e");
      // If login failed, force new login
      _forceNewLogin();
    }
  } else {
    // No saved credentials, cancel timeout and show login dialog
    _loadingTimeoutTimer?.cancel();
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
  print("Processing login response: $responseBody");
  List<String> responseParts = responseBody.split('@');
  
  if (responseParts.isNotEmpty && responseParts[0] == "OK") {
    // Login successful, cancel timeout timer
    _loadingTimeoutTimer?.cancel();
    
    String name = responseParts.length > 1 ? responseParts[1] : 'Unknown';
    String employeeId = responseParts.length > 2 ? responseParts[2] : 'N/A';
    String chamCong = responseParts.length > 3 ? responseParts[3] : 'N/A';
    String queryType = responseParts.length > 4 ? responseParts[4] : '1';
    
    try {
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

      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _currentUser = userData;
          _loginStatus = '';
          _selectedIndex = 1;
          print("Login successful, setting _isAuthenticated to true");
        });
      }

      await _userState.setUser(userData);
      await _userState.setLoginResponse(responseBody);
      await _userState.setUpdateResponses('', '', '', '', chamCong);

      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print("Error saving user data: $e");
      // If saving data fails, still consider the login successful
      // but show a message to the user
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _loginStatus = 'Đăng nhập thành công nhưng có lỗi lưu dữ liệu.';
        });
        
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      }
    }
  } else if (responseParts.isNotEmpty && responseParts[0] == "WRONG") {
    // Handle WRONG response specifically
    if (mounted) {
      setState(() {
        _loginStatus = 'Sai tên đăng nhập hoặc mật khẩu. Vui lòng kiểm tra lại thông tin hoặc sử dụng chức năng đặt lại mật khẩu nếu bạn quên mật khẩu.';
      });
    }
  } else if (responseParts.isEmpty) {
    // Handle empty response
    if (mounted) {
      setState(() {
        _loginStatus = 'Máy chủ không phản hồi. Vui lòng thử lại sau.';
      });
    }
  } else {
    // Handle other error cases
    if (mounted) {
      setState(() {
        _loginStatus = 'Đăng nhập thất bại. Vui lòng kiểm tra lại thông tin.';
      });
    }
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
                          '(Nếu quá 10s mà chưa đăng nhập xong thì bạn đã nhập sai thông tin.\nVui lòng tắt ứng dụng khi hết ngày, mở lại vào ngày mới .)',
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

  // Get the current user's queryType
  final userState = Provider.of<UserState>(context, listen: false);
  final userQueryType = userState.queryType;
  
  // Define which queryTypes can access each tab
  final Map<int, List<String>> allowedQueryTypes = {
    0: [], // Projects tab
    1: ['1','2', '4'], // Work tab
    2: ['1','2', '4'], // HM AI tab
    3: ['1','2', '4', '5'], // Guide tab
    4: [''] //KH tab
  };
  
  // Define permissions for floating action buttons
  final Map<String, List<String>> allowedActionButtons = {
    'admin': ['2'], 
    'saban': ['2'],
    'airport': ['2'],
  };
  
  final List<Widget> visibleScreens = [];
  final List<BottomNavigationBarItem> visibleNavItems = [];
  
  final allScreens = _screens;
  final allNavItems = const [
    BottomNavigationBarItem(
      icon: Icon(Icons.folder),
      label: 'Dự án',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.web),
      label: 'Công\nviệc',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.smart_toy),
      label: 'HM AI',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: 'Hướng\ndẫn',
    ),
      BottomNavigationBarItem(
      icon: Icon(Icons.dry),
      label: 'Khách\nhàng',
    ),
  ];
  
  // Create mapping of visible indexes to original indexes
  Map<int, int> visibleToOriginalIndex = {};
  int visibleIndex = 0;
  for (int i = 0; i < allScreens.length; i++) {
    List<String> allowed = allowedQueryTypes[i] ?? [];
    // Show if list is empty (all allowed) or user's queryType is in the allowed list
    if (allowed.isEmpty || allowed.contains(userQueryType)) {
      visibleScreens.add(allScreens[i]);
      visibleNavItems.add(allNavItems[i]);
      visibleToOriginalIndex[visibleIndex] = i;
      visibleIndex++;
    }
  }  
  // Adjust selected index if needed
  int visibleSelectedIndex = 0;
  for (int i = 0; i < visibleToOriginalIndex.length; i++) {
    if (visibleToOriginalIndex[i] == _selectedIndex) {
      visibleSelectedIndex = i;
      break;
    }
  }

  // Determine which action buttons to show based on permissions
  final adminPermissions = allowedActionButtons['admin'] ?? [];
  final airportPermissions = allowedActionButtons['airport'] ?? [];
  
bool showAdminButton = adminPermissions.isEmpty || adminPermissions.contains(userQueryType);
bool showSaBanButton = (allowedActionButtons['saban']?.isEmpty ?? true) || (allowedActionButtons['saban']?.contains(userQueryType) ?? false);
bool showAirportButton = airportPermissions.isEmpty || airportPermissions.contains(userQueryType);

  // Calculate left margin for airport button (can't use dynamic values in const constructor)
  final airportLeftMargin = (showAdminButton || showSaBanButton) ? 10.0 : 0.0;

  return Banner(
    message: 'HM GROUP',
    location: BannerLocation.topEnd,
    color: const Color.fromARGB(255, 0, 71, 171),
    child: Scaffold(
      body: Row(
        children: [
          // Enhanced Left Navigation Rail
          Container(
            width: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.cyan[900]!.withOpacity(0.95),
                  Colors.cyan[700]!.withOpacity(0.90),
                  Colors.cyan[500]!.withOpacity(0.85),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(3, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Action buttons at the top
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Column(
                    children: [
                      // Logo/Title
                      Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        child: const Text(
                          '1.3.6',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      
                      // Action buttons
                      if (showAdminButton) _buildEnhancedActionButton(
                        icon: Icons.admin_panel_settings,
                        label: 'Quản trị',
                        color: Colors.red,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const ProjectDirectorScreen()),
                        ),
                      ),
                      if (showSaBanButton) _buildEnhancedActionButton(
                        icon: Icons.map,
                        label: 'Sa bàn',
                        color: Colors.green,
                        onPressed: () {
                          final username = _userState.currentUser?['username'] ?? '';
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => MapProjectScreen(username: username),
                            ),
                          );
                        },
                      ),
                      if (showAirportButton) _buildEnhancedActionButton(
                        icon: Icons.flight,
                        label: 'Sân bay\nT1',
                        color: const Color.fromARGB(255, 0, 99, 179),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const ProjectDirector2Screen()),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Animated divider
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                
                // Navigation items
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: visibleNavItems.asMap().entries.map((entry) {
                        int index = entry.key;
                        BottomNavigationBarItem item = entry.value;
                        bool isSelected = index == visibleSelectedIndex;
                        
                        return _buildEnhancedNavItem(
                          icon: item.icon as Icon,
                          label: item.label!,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              _selectedIndex = visibleToOriginalIndex[index]!;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Vertical divider with gradient
          Container(
            width: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.cyan[200]!.withOpacity(0.3),
                  Colors.cyan[400]!.withOpacity(0.6),
                  Colors.cyan[200]!.withOpacity(0.3),
                ],
              ),
            ),
          ),
          
          // Main content area
          Expanded(
            child: visibleScreens[visibleSelectedIndex],
          ),
        ],
      ),
    ),
  );
}

// Enhanced action button with glassmorphism effect
Widget _buildEnhancedActionButton({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onPressed,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 6),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.8),
                color.withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 8,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Enhanced navigation item with hover effects and animations
Widget _buildEnhancedNavItem({
  required Icon icon,
  required String label,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            gradient: isSelected 
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.25),
                    Colors.white.withOpacity(0.15),
                  ],
                )
              : null,
            borderRadius: BorderRadius.circular(12),
            border: isSelected 
              ? Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                )
              : null,
            boxShadow: isSelected 
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected 
                    ? Colors.white.withOpacity(0.2)
                    : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon.icon,
                  color: isSelected 
                    ? Colors.white 
                    : Colors.white.withOpacity(0.7),
                  size: isSelected ? 26 : 24,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 8,
                  color: isSelected 
                    ? Colors.white 
                    : Colors.white.withOpacity(0.8),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
      
      // Set up the video with await
      await player.open(Media(
        'https://storage.googleapis.com/times1/DocumentApp/appdesktop.mp4'
      ));
      
      print('Video loaded successfully');
      
      // Set volume to 0
      player.setVolume(0);
      
      // Mark as initialized right away to prevent UI blocking
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
      
      // Handle looping through playback ended event
      player.stream.completed.listen((_) {
        player.seek(Duration.zero);
        player.play();
      });
      
    } catch (e) {
      print('Video initialization error: $e');
      // Still mark as initialized so the app can proceed even if video fails
      if (mounted) {
        setState(() {
          _isInitialized = true;
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
// Add this class to handle the HM AI screen in navigation
class HMAIScreen extends StatelessWidget {
  const HMAIScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color.fromARGB(255, 210, 173, 255)!,
                  Colors.blue[600]!,
                ],
              ),
            ),
          ),
          // Center the FloatingDraggableIcon's ChatWindow directly
          Center(
            child: ChatWindow(
              key: FloatingDraggableIcon.chatWindowKey,
              onClose: () {
                // Instead of hiding, navigate back to previous screen
                Navigator.of(context).pop();
              },
              onOpen: () {
                FloatingDraggableIcon.chatWindowKey.currentState?.scrollToBottom();
              },
            ),
          ),
        ],
      ),
    );
  }
}