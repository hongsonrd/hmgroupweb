import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

class FileInfo {
  final String fileName;
  final String baseUrl;
  final bool isBinary;
  Uint8List? cachedBinaryContent;
  String? cachedTextContent;
  DateTime? lastModified;

  FileInfo(this.fileName, this.baseUrl, {this.isBinary = false});
    String get url {
    final random = Random().nextInt(100000);
    return '$baseUrl?v=$random';
  }
}

class MultiFileAccessUtility {
  static final Map<String, FileInfo> _files = {
    'lookup_data': FileInfo(
      'lookup_data.xlsx', 
      'https://storage.googleapis.com/times1/DocumentApp/lookup_data.xlsx',
      isBinary: true
    ),
    'checklist_data': FileInfo(
      'checklist_data.xlsx', 
      'https://storage.googleapis.com/times1/DocumentApp/checklist_data.xlsx',
      isBinary: true
    ),
    'staff_data': FileInfo(
      'staff_data.xlsx', 
      'https://storage.googleapis.com/times1/DocumentApp/staff_data.xlsx',
      isBinary: true
    ),
    'schedule_data': FileInfo(
      'schedule_data.xlsx', 
      'https://storage.googleapis.com/times1/DocumentApp/schedule_data.xlsx',
      isBinary: true
    ),
  };

  static Future<String> getBaseDirectory() async {
    if (Platform.isAndroid) {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/HMCamera';
    }
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<String> getAssetsDirectory() async {
    final baseDir = await getBaseDirectory();
    return '$baseDir/assets';
  }

  static Future<void> ensureDirectoryExists(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  static Future<dynamic> getFileContent(String fileKey) async {
    if (!_files.containsKey(fileKey)) {
      throw Exception('File key not found: $fileKey');
    }

    final fileInfo = _files[fileKey]!;
    
    // Check cache first
    if (fileInfo.isBinary && fileInfo.cachedBinaryContent != null) {
      return fileInfo.cachedBinaryContent!;
    }
    if (!fileInfo.isBinary && fileInfo.cachedTextContent != null) {
      return fileInfo.cachedTextContent!;
    }

    try {
      // Try app storage first
      final appContent = await _getFromAppStorage(fileInfo);
      if (appContent != null) return appContent;

      // Then try asset bundle
      final assetContent = await _getFromAssets(fileInfo);
      if (assetContent != null) return assetContent;

      // If both failed, try downloading
      final downloadedContent = await _downloadAndSave(fileInfo);
      if (downloadedContent != null) return downloadedContent;

      // If all methods failed, throw exception
      throw Exception('Unable to retrieve file content');
    } catch (e) {
      print('Error reading file ${fileInfo.fileName}: $e');
      // Final attempt to read from assets
      final lastResortContent = await _getFromAssets(fileInfo);
      if (lastResortContent != null) {
        return lastResortContent;
      }
      // If everything failed, throw the original error
      throw Exception('Failed to retrieve file content: $e');
    }
  }

  static Future<dynamic> _getFromAppStorage(FileInfo fileInfo) async {
    try {
      final assetsDir = await getAssetsDirectory();
      final filePath = '$assetsDir/${fileInfo.fileName}';
      final file = File(filePath);

      if (await file.exists()) {
        if (fileInfo.isBinary) {
          fileInfo.cachedBinaryContent = await file.readAsBytes();
          return fileInfo.cachedBinaryContent!;
        } else {
          fileInfo.cachedTextContent = await file.readAsString();
          return fileInfo.cachedTextContent!;
        }
      }
    } catch (e) {
      print('Error reading from app storage: $e');
    }
    return null;
  }

  static Future<dynamic> _getFromAssets(FileInfo fileInfo) async {
    try {
      if (fileInfo.isBinary) {
        fileInfo.cachedBinaryContent = (await rootBundle.load('assets/${fileInfo.fileName}')).buffer.asUint8List();
        return fileInfo.cachedBinaryContent!;
      } else {
        fileInfo.cachedTextContent = await rootBundle.loadString('assets/${fileInfo.fileName}');
        return fileInfo.cachedTextContent!;
      }
    } catch (e) {
      print('Error reading from assets: $e');
    }
    return null;
  }
static Future<String> _getMetadataFilePath() async {
    final baseDir = await getBaseDirectory();
    return '$baseDir/file_metadata.json';
  }

  // Save metadata for all files
  static Future<void> _saveMetadata() async {
    final metadataPath = await _getMetadataFilePath();
    final metadata = {
      for (var entry in _files.entries)
        entry.key: {
          'lastModified': entry.value.lastModified?.toIso8601String(),
          'fileName': entry.value.fileName
        }
    };
    
    await File(metadataPath).writeAsString(jsonEncode(metadata));
  }

  // Load metadata for all files
  static Future<void> _loadMetadata() async {
    try {
      final metadataPath = await _getMetadataFilePath();
      final file = File(metadataPath);
      
      if (await file.exists()) {
        final content = await file.readAsString();
        final metadata = jsonDecode(content) as Map<String, dynamic>;
        
        for (var entry in metadata.entries) {
          if (_files.containsKey(entry.key)) {
            final fileData = entry.value as Map<String, dynamic>;
            if (fileData['lastModified'] != null) {
              _files[entry.key]!.lastModified = 
                  DateTime.parse(fileData['lastModified'] as String);
            }
          }
        }
      }
    } catch (e) {
      print('Error loading metadata: $e');
    }
  }
static Future<bool> _needsUpdate(String fileKey) async {
    final fileInfo = _files[fileKey]!;
    
    try {
      // Use the getter that includes the random version parameter
      final response = await http.head(Uri.parse(fileInfo.url));
      
      if (response.statusCode == 200) {
        final lastModifiedHeader = response.headers['last-modified'];
        if (lastModifiedHeader != null) {
          final serverLastModified = HttpDate.parse(lastModifiedHeader);
          
          if (fileInfo.lastModified == null || 
              serverLastModified.isAfter(fileInfo.lastModified!)) {
            return true;
          }
        }
      }
    } catch (e) {
      print('Error checking file update status: $e');
      return true;
    }
    
    return false;
  }
  static Future<dynamic> _downloadAndSave(FileInfo fileInfo) async {
    try {
      // Use the getter that includes the random version parameter
      final response = await http.get(Uri.parse(fileInfo.url));
      if (response.statusCode == 200) {
        final assetsDir = await getAssetsDirectory();
        await ensureDirectoryExists(assetsDir);
        final filePath = '$assetsDir/${fileInfo.fileName}';
        final file = File(filePath);

        final lastModifiedHeader = response.headers['last-modified'];
        if (lastModifiedHeader != null) {
          fileInfo.lastModified = HttpDate.parse(lastModifiedHeader);
          await _saveMetadata();
        }

        if (fileInfo.isBinary) {
          await file.writeAsBytes(response.bodyBytes);
          fileInfo.cachedBinaryContent = response.bodyBytes;
          return fileInfo.cachedBinaryContent!;
        } else {
          await file.writeAsString(response.body);
          fileInfo.cachedTextContent = response.body;
          return fileInfo.cachedTextContent!;
        }
      }
    } catch (e) {
      print('Error downloading file: $e');
    }
    return null;
  }

  static Future<void> downloadAndReplaceFile(String fileKey) async {
    if (!_files.containsKey(fileKey)) {
      throw Exception('File key not found: $fileKey');
    }

    final fileInfo = _files[fileKey]!;
    try {
      if (await _needsUpdate(fileKey)) {
        final content = await _downloadAndSave(fileInfo);
        if (content == null) {
          throw Exception('Failed to download file');
        }
        print('File $fileKey downloaded and saved successfully');
      } else {
        print('File $fileKey is up to date, skipping download');
      }
    } catch (e) {
      print('Error downloading or saving file $fileKey: $e');
      rethrow;
    }
  }
  static Future<void> downloadAllFiles() async {
    final failures = <String>[];
    
    for (String fileKey in _files.keys) {
      try {
        print('Downloading $fileKey...');
        await downloadAndReplaceFile(fileKey);
        print('Successfully downloaded $fileKey');
      } catch (e) {
        print('Failed to download $fileKey: $e');
        failures.add(fileKey);
      }
    }
    
    if (failures.isNotEmpty) {
      throw Exception('Failed to download files: ${failures.join(", ")}');
    }
  }
  static Future<void> initialize() async {
    await _loadMetadata();
  }
  static void clearCache() {
    for (var fileInfo in _files.values) {
      fileInfo.cachedBinaryContent = null;
      fileInfo.cachedTextContent = null;
    }
  }

  static Future<bool> verifyFiles() async {
    bool allFilesValid = true;
    final assetsDir = await getAssetsDirectory();
    
    for (var entry in _files.entries) {
      final file = File('$assetsDir/${entry.value.fileName}');
      try {
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (bytes.isEmpty) {
            print('File ${entry.key} exists but is empty');
            allFilesValid = false;
          } else {
            print('File ${entry.key} exists and has ${bytes.length} bytes');
          }
        } else {
          print('File ${entry.key} does not exist');
          allFilesValid = false;
        }
      } catch (e) {
        print('Error verifying file ${entry.key}: $e');
        allFilesValid = false;
      }
    }
    
    return allFilesValid;
  }
}