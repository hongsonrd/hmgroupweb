# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**HM Group Web** (hmgroupweb) is a Flutter desktop application for digital transformation at Hoàn Mỹ Group. The application is a comprehensive enterprise management system that supports Windows and macOS platforms, handling employee management, project management, attendance tracking, warehouse management, customer relations, and more.

- **Current Version**: 1.3.4
- **Platforms**: Windows (primary), macOS, with cross-platform support
- **Primary Language**: Dart/Flutter
- **Target SDK**: Dart SDK >=3.2.0 <4.0.0
- **Min macOS SDK**: 10.11

## Build & Development Commands

### Running the Application

```bash
# Run in debug mode
flutter run -d macos  # for macOS
flutter run -d windows  # for Windows

# Run with diagnostic mode (for troubleshooting)
flutter run -- --diagnostic
# or
flutter run -- -d
```

### Building

```bash
# Build for macOS
flutter build macos --release

# Build for Windows
flutter build windows --release
```

### Testing & Linting

```bash
# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
flutter format lib/
```

### Dependency Management

```bash
# Get dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade

# Clean build artifacts
flutter clean
```

## Application Architecture

### Authentication & State Management

The application uses **Provider** pattern for state management with two main providers:

1. **UserState** (`lib/user_state.dart`): Singleton pattern managing user authentication, session data, and query type-based permissions
2. **UserCredentials** (`lib/user_credentials.dart`): Manages saved login credentials

**Authentication Flow**:
- Token-based authentication with HMAC-SHA256 signing
- Tokens stored in SharedPreferences with 24-hour expiration
- Auto-refresh mechanism runs every 23 hours
- Login endpoint: `https://hmclourdrun1-81200125587.asia-southeast1.run.app/loginweb`
- Token verification endpoint: `https://hmclourdrun1-81200125587.asia-southeast1.run.app/tokenweb`

**AppAuthentication** (`lib/app_authentication.dart` and in `main.dart`): Generates secure tokens using instance IDs, timestamps, nonces, and HMAC signatures with AES-CBC encryption.

### User Permissions System

The application uses a **queryType-based permission system**:
- `queryType '1'`: Standard employee (ProjectManagement)
- `queryType '2'`: Admin/Manager (ProjectManagement2, full access)
- `queryType '4'`: Special access (ProjectManagement4)
- `queryType '5'`: Guide-only access

Permissions control:
- Bottom navigation visibility (see `main.dart:1582-1635`)
- Floating action buttons (Admin panel, Sa bàn map, Airport T1)
- Feature access across different screens

### Project Router Pattern

**ProjectRouter** (`lib/projectrouter.dart`) dynamically routes users to different project management screens based on their `queryType`, ensuring users only see features they have permission to access.

### Database Architecture

**DBHelper** (`lib/db_helper.dart`):
- SQLite database using `sqflite` (mobile) and `sqflite_common_ffi` (desktop)
- Database path: `app_database.db` in application documents directory
- Version-controlled migrations with forced resets (currently v32)
- Database location:
  - Windows/Linux: Application Documents Directory
  - Mobile: Default databases path

The database schema is defined in `lib/table_models.dart` (not fully analyzed but referenced).

### Main Screen Structure

**Main Navigation** (5 tabs, visibility controlled by queryType):
1. **Dự án (Projects)**: Dynamic router based on user permissions
2. **Công việc (Work)**: WebView-based work management
3. **HM AI**: AI chat interface using FloatingDraggableIcon
4. **Hướng dẫn (Guide)**: IntroScreen with user data
5. **Khách hàng (Customers)**: Customer management WebView

**Left Navigation Rail** (`main.dart:1665-1782`):
- Gradient background (cyan theme)
- Action buttons at top (conditionally rendered)
- Navigation items below with glassmorphism effect
- Custom enhanced UI components

### Video Background System

**VideoBackground** widget (`main.dart:1968-2069`):
- Uses `media_kit` for cross-platform video playback
- Loads background video from: `https://storage.googleapis.com/times1/DocumentApp/appdesktop.mp4`
- Fallback gradient background if video fails
- Volume set to 0, auto-loops on completion
- Non-blocking initialization (app proceeds even if video fails)

### Desktop-Specific Features

**Windows**:
- WebView2 Runtime check on startup (`main.dart:36-94`)
- Controlled Folder Access detection (diagnostic mode)
- VC++ Redistributable detection
- Window management via `window_manager` package

**macOS**:
- Media Kit libs for video playback
- Standard window management

**Diagnostic Mode**:
- Run with `--diagnostic` or `-d` flag
- Comprehensive system checks (architecture, dependencies, permissions, disk space)
- Saves report to temp directory and opens in Notepad (Windows)

### Version Management

**Auto-Update System** (`main.dart:486-663`):
- Checks version from: `https://yourworldtravel.vn/api/document/versiondesktop.txt`
- Compares semantic versions (major.minor.patch)
- Download URLs:
  - macOS: `https://storage.googleapis.com/times1/DocumentApp/HMGROUPmac.zip`
  - Windows: `https://storage.googleapis.com/times1/DocumentApp/HMGROUPwin.zip`
- Forces update if version is 5+ versions behind
- Version check runs post-frame after app initialization

## Key Modules & Screen Categories

### Project Management
- **projectmanagement.dart**: Base project management for queryType '1'
- **projectmanagement2.dart**: Admin project management for queryType '2'
- **projectmanagement4.dart**: Special project management for queryType '4'
- **projectmanagementcongnhan.dart**: Worker management
- **projectdirector.dart**: Admin panel (director view)
- **projectdirector2.dart**: Airport Terminal 1 management
- **projectrouter.dart**: Permission-based routing

### Attendance (Chấm công)
Multiple attendance tracking screens with different views:
- **chamcong.dart**, **chamcong2.dart**: Main attendance
- **chamcongthang.dart**, **chamcongthang2.dart**: Monthly attendance
- **chamcongduyet.dart**: Attendance approval
- **chamcongtca.dart**: Shift-based attendance
- **chamcongvang.dart**: Absence tracking
- **chamcongnghi.dart**: Leave tracking
- **chamcongthanghr.dart**: HR monthly view
- **chamcongthangphep.dart**: Leave balance tracking

### Warehouse Management (Hàng hóa - hs_)
- **hs_kho.dart**, **hs_kho2.dart**: Warehouse inventory
- **hs_donhang.dart**, **hs_donhangmoi.dart**: Order management
- **hs_khachhang.dart**, **hs_khachhangsua.dart**: Customer management
- **hs_xuhuong.dart** series: Trend analytics (inventory, sales, customer, KPI)
- **hs_stat.dart**: Statistics and reporting
- **hs_scan.dart**: Barcode/QR scanning
- **hs_ptform.dart**, **hs_pycform.dart**: Form management

### Contract Management (Hợp đồng - hd_)
- **hd_moi.dart**: New contracts
- **hd_thang.dart**, **hd_thang2.dart**: Monthly contracts
- **hd_chiphi.dart**: Cost management
- **hd_yeucaumay.dart** series: Equipment requests

### Project Operations
- **projectworker.dart** series: Worker/employee management with various views
- **projecttimeline.dart** series: Project timeline and scheduling
- **projectorder.dart** series: Order and task management
- **projectmachine.dart** series: Equipment/machine management
- **map_project.dart**: Project location mapping (Sa bàn)
- **map_floor.dart**, **map_report.dart**: Floor plans and location-based reporting

### Checklist System
- **checklist_manager.dart**: Checklist creation and management
- **checklist_item.dart**: Individual checklist items
- **checklist_report.dart**: Checklist reporting
- **checklist_supervisor.dart**: Supervisor view
- **checklist_list.dart**: Checklist listing

### Payroll (Pay_)
- **pay_account.dart**, **pay_account2.dart**: Account management
- **pay_history.dart**, **pay_historyac.dart**: Payment history
- **pay_hour.dart**: Hour tracking
- **pay_location.dart**: Location-based pay
- **pay_standard.dart**: Pay standards
- **pay_policy.dart**: Payment policies

### Utilities
- **export_helper.dart**, **export_helper_period.dart**: Excel export functionality
- **multifile.dart**: Multi-file access utility
- **floating_draggable_icon.dart**: Draggable AI chat icon
- **work_suggestions.dart**: AI-powered work suggestions
- **chat_ai.dart**: AI chat integration
- **http_client.dart**: HTTP request wrapper

## Common Patterns

### HTTP Requests with Authentication

All API requests should include token authentication:

```dart
final tokenData = await AppAuthentication.generateToken();
final response = await http.get(
  Uri.parse(url),
  headers: {
    'Content-Type': 'application/json',
    'Accept': '*/*',
    'Authorization': 'Bearer ${tokenData['token'] ?? ''}',
    'X-Timestamp': tokenData['timestamp'] ?? ''
  },
);
```

### Accessing User State

```dart
// In a widget
final userState = Provider.of<UserState>(context, listen: false);
final username = userState.currentUser?['username'] ?? '';
final queryType = userState.queryType;
```

### Database Access

```dart
final dbHelper = DBHelper();
final db = await dbHelper.database;
// Perform database operations
```

### Navigation with Context

```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (context) => SomeScreen()),
);
```

## Important Configuration Details

### Encryption
- **AES Key**: 32-character key "12345678901234567890123456789012"
- **Mode**: AES-CBC with PKCS7 padding
- **IV**: Random 16 bytes generated per encryption

### Asset Management
Assets are organized in `assets/` directory:
- Logos for different business units (logo.png, logo2.png, etc.)
- Brand-specific logos (hotellogo.png, logogoclean.png, etc.)
- Checklist logos for different clients
- Video backgrounds (.mp4 files)
- Avatar directory

### Input Validation
- Username/Password: Allow `[a-zA-Z0-9.@_-]`, max 50 chars
- Lowercase normalization on login

## Troubleshooting

### Windows-Specific Issues
1. **WebView2 Runtime**: Required for Windows. Auto-prompt if missing.
2. **SQLite FFI**: Must initialize `sqfliteFfiInit()` before database access
3. **Controlled Folder Access**: May block app - check diagnostic mode
4. **VC++ Redistributable**: Required for some native dependencies

### Database Issues
- Check version migrations in db_helper.dart
- Current version: v32 (forced reset flag: 'db_reset_v32')
- Database resets clear all local data

### Authentication Issues
- Token expiry: 24 hours
- Failed login: Check if token verification endpoint is accessible
- Loading timeout: 5-second timeout triggers force login if stuck

## API Endpoints

Base URL: `https://hmclourdrun1-81200125587.asia-southeast1.run.app`

- `/loginweb/{encryptedQuery}`: User login
- `/tokenweb`: Token verification (POST)
- `/matkhauquen/{username}`: Password recovery (POST)
- `/matkhaureset/{username}`: Password reset (POST)

Version check: `https://yourworldtravel.vn/api/document/versiondesktop.txt`
