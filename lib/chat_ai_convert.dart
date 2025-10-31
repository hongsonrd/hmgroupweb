import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

class DocumentConverter {
  static Future<File?> convertToText(File file) async {
    final extension = file.path.split('.').last.toLowerCase();
    
    print('📄 Converting file type: $extension');
    
    try {
      switch (extension) {
        case 'txt':
        case 'md':
          print('✅ Text file, no conversion needed');
          return file;
        case 'csv':
          print('✅ CSV file, no conversion needed (already text)');
          return file;
        case 'doc':
        case 'docx':
          return await _convertDocToText(file);
        case 'xls':
        case 'xlsx':
          return await _convertExcelToText(file);
        case 'rtf':
          return await _convertRtfToText(file);
        case 'pdf':
          return await _convertPdfToText(file);
        default:
          print('⚠️ Unsupported file type: $extension');
          return null;
      }
    } catch (e) {
      print('❌ Conversion error: $e');
      return null;
    }
  }

  static Future<File> _convertPdfToText(File pdfFile) async {
    try {
      print('📄 Processing PDF file...');
      
      final bytes = await pdfFile.readAsBytes();
      final tempDir = await getTemporaryDirectory();
      final txtFile = File('${tempDir.path}/${_getBaseName(pdfFile)}_converted.txt');
      
      String extractedText = '';
      
      try {
        // Basic text extraction from PDF bytes
        final buffer = StringBuffer();
        buffer.writeln('==================== PDF DOCUMENT ====================\n');
        buffer.writeln('File: ${pdfFile.path.split('/').last}');
        buffer.writeln('Size: ${(bytes.length / 1024).toStringAsFixed(2)} KB\n');
        buffer.writeln('--- EXTRACTED TEXT ---\n');
        
        // Convert bytes to string and extract text between parentheses (PDF text objects)
        final pdfString = String.fromCharCodes(bytes.where((b) => b >= 32 && b <= 126 || b == 10 || b == 13));
        
        // Extract text from PDF stream objects
        final streamRegex = RegExp(r'stream(.*?)endstream', dotAll: true);
        final streamMatches = streamRegex.allMatches(pdfString);
        
        // Extract text in parentheses (common PDF text format)
        final textRegex = RegExp(r'\(([^)]{2,})\)');
        final textParts = <String>[];
        
        for (var streamMatch in streamMatches) {
          final streamContent = streamMatch.group(1) ?? '';
          final textMatches = textRegex.allMatches(streamContent);
          
          for (var textMatch in textMatches) {
            final text = textMatch.group(1);
            if (text != null && text.trim().isNotEmpty) {
              // Clean up PDF escape sequences
              final cleanText = text
                  .replaceAll(r'\\', '\\')
                  .replaceAll(r'\(', '(')
                  .replaceAll(r'\)', ')')
                  .replaceAll(r'\n', '\n')
                  .replaceAll(r'\r', '\r')
                  .replaceAll(r'\t', '\t');
              
              if (cleanText.length > 1 && !cleanText.contains(RegExp(r'^[\x00-\x1F]+$'))) {
                textParts.add(cleanText);
              }
            }
          }
        }
        
        // Also try to extract text from Tj/TJ operators
        final tjRegex = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);
        final tjMatches = tjRegex.allMatches(pdfString);
        
        for (var match in tjMatches) {
          final content = match.group(1);
          if (content != null) {
            final innerTextMatches = textRegex.allMatches(content);
            for (var textMatch in innerTextMatches) {
              final text = textMatch.group(1);
              if (text != null && text.trim().isNotEmpty && text.length > 1) {
                textParts.add(text);
              }
            }
          }
        }
        
        if (textParts.isNotEmpty) {
          // Remove duplicates and join
          final uniqueTexts = textParts.toSet().toList();
          buffer.writeln(uniqueTexts.join('\n'));
          buffer.writeln('\n--- Total text segments extracted: ${uniqueTexts.length} ---');
        } else {
          buffer.writeln('[No readable text could be extracted from this PDF]');
          buffer.writeln('[This PDF may contain:]');
          buffer.writeln('- Scanned images without OCR');
          buffer.writeln('- Encrypted or protected content');
          buffer.writeln('- Complex formatting or embedded objects');
          buffer.writeln('- Non-standard encoding');
        }
        
        extractedText = buffer.toString();
        print('✅ PDF extraction completed: ${extractedText.length} characters');
        
      } catch (e) {
        print('⚠️ PDF text extraction failed: $e');
        extractedText = 'PDF file: ${pdfFile.path.split('/').last}\n\n[Text extraction failed: $e]\n\nThis PDF may require specialized tools for text extraction.';
      }
      
      await txtFile.writeAsString(extractedText, flush: true);
      print('✅ PDF converted: ${extractedText.length} chars -> ${txtFile.path}');
      
      return txtFile;
    } catch (e) {
      print('❌ PDF conversion error: $e');
      rethrow;
    }
  }

  static Future<File> _convertDocToText(File docFile) async {
    try {
      final bytes = await docFile.readAsBytes();
      final tempDir = await getTemporaryDirectory();
      final txtFile = File('${tempDir.path}/${_getBaseName(docFile)}_converted.txt');
      
      String extractedText = '';
      
      if (docFile.path.endsWith('.docx')) {
        print('📝 Processing DOCX file...');
        extractedText = await _extractDocxText(bytes);
      } else {
        print('📝 Processing DOC file (legacy)...');
        extractedText = await _extractDocText(bytes);
      }
      
      if (extractedText.isEmpty) {
        print('⚠️ No text extracted from DOC/DOCX');
        extractedText = 'No text content could be extracted from this document.';
      }
      
      await txtFile.writeAsString(extractedText, flush: true);
      print('✅ DOC/DOCX converted: ${extractedText.length} chars -> ${txtFile.path}');
      
      return txtFile;
    } catch (e) {
      print('❌ DOC/DOCX conversion error: $e');
      rethrow;
    }
  }

  static Future<String> _extractDocxText(List<int> bytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      ArchiveFile? documentXml;
      
      for (var file in archive.files) {
        if (file.name == 'word/document.xml') {
          documentXml = file;
          break;
        }
      }
      
      if (documentXml == null) {
        print('⚠️ No document.xml found in DOCX archive');
        return '';
      }
      
      final content = utf8.decode(documentXml.content as List<int>);
      
      final textRegex = RegExp(r'<w:t[^>]*>([^<]+)</w:t>');
      final matches = textRegex.allMatches(content);
      
      final textParts = <String>[];
      for (var match in matches) {
        final text = match.group(1);
        if (text != null && text.trim().isNotEmpty) {
          textParts.add(text);
        }
      }
      
      final extractedText = textParts.join(' ');
      print('📊 DOCX stats: ${textParts.length} text elements extracted');
      
      return extractedText;
    } catch (e) {
      print('❌ DOCX parsing error: $e');
      return '';
    }
  }

  static Future<String> _extractDocText(List<int> bytes) async {
    try {
      final buffer = StringBuffer();
      
      for (int i = 0; i < bytes.length - 1; i++) {
        if ((bytes[i] >= 32 && bytes[i] <= 126) || bytes[i] == 10 || bytes[i] == 13) {
          buffer.writeCharCode(bytes[i]);
        }
      }
      
      String text = buffer.toString();
      text = text
          .replaceAll(RegExp(r'[^\x20-\x7E\n\r\t]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      
      print('📊 DOC stats: ${text.length} characters extracted (legacy format)');
      
      return text;
    } catch (e) {
      print('❌ DOC parsing error: $e');
      return '';
    }
  }

  static Future<File> _convertExcelToText(File excelFile) async {
    try {
      final bytes = await excelFile.readAsBytes();
      final tempDir = await getTemporaryDirectory();
      final txtFile = File('${tempDir.path}/${_getBaseName(excelFile)}_converted.txt');
      
      String extractedText = '';
      
      if (excelFile.path.endsWith('.xlsx')) {
        print('📊 Processing XLSX file...');
        extractedText = await _extractXlsxText(bytes);
      } else {
        print('📊 Processing XLS file (legacy format)...');
        extractedText = 'Legacy XLS format detected. Please save as XLSX for better extraction.';
      }
      
      if (extractedText.isEmpty) {
        print('⚠️ No data extracted from Excel file');
        extractedText = 'No data could be extracted from this spreadsheet.';
      }
      
      await txtFile.writeAsString(extractedText, flush: true);
      print('✅ Excel converted: ${extractedText.length} chars -> ${txtFile.path}');
      
      return txtFile;
    } catch (e) {
      print('❌ Excel conversion error: $e');
      rethrow;
    }
  }

  static Future<String> _extractXlsxText(List<int> bytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final buffer = StringBuffer();
      
      Map<int, String> sharedStrings = {};
      for (var file in archive.files) {
        if (file.name == 'xl/sharedStrings.xml') {
          final content = utf8.decode(file.content as List<int>);
          
          print('🔍 Shared strings XML found, parsing...');
          
          final tRegex = RegExp(r'<t[^>]*>([^<]+)</t>');
          final tMatches = tRegex.allMatches(content);
          
          int index = 0;
          for (var match in tMatches) {
            final text = match.group(1);
            if (text != null && text.trim().isNotEmpty) {
              sharedStrings[index] = text.trim();
              print('  String[$index] = "${text.trim()}"');
              index++;
            }
          }
          
          print('✅ Extracted ${sharedStrings.length} shared strings');
          break;
        }
      }
      
      if (sharedStrings.isNotEmpty) {
        print('📝 Sample shared strings:');
        for (int i = 0; i < 10 && i < sharedStrings.length; i++) {
          print('  [$i]: ${sharedStrings[i]}');
        }
      }
      
      int sheetCount = 0;
      final sheetFiles = archive.files
          .where((f) => f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml'))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      
      for (var file in sheetFiles) {
        sheetCount++;
        final content = utf8.decode(file.content as List<int>);
        
        buffer.writeln('\n==================== SHEET $sheetCount ====================\n');
        
        final dimensionMatch = RegExp(r'<dimension[^>]*ref="([^"]+)"').firstMatch(content);
        if (dimensionMatch != null) {
          print('📐 Sheet dimension: ${dimensionMatch.group(1)}');
        }
        
        final rowRegex = RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true);
        final rowMatches = rowRegex.allMatches(content);
        
        List<Map<String, String>> allRows = [];
        
        for (var rowMatch in rowMatches) {
          final rowContent = rowMatch.group(1) ?? '';
          
          final cellRegex = RegExp(
            r'<c\s+r="([A-Z]+\d+)"(?:[^>]*\s+t="([^"]+)")?[^>]*>(?:<v>([^<]+)</v>)?(?:<is><t>([^<]+)</t></is>)?</c>',
            dotAll: true
          );
          final cellMatches = cellRegex.allMatches(rowContent);
          
          Map<String, String> rowData = {};
          
          for (var cellMatch in cellMatches) {
            final cellRef = cellMatch.group(1) ?? '';
            final col = cellRef.replaceAll(RegExp(r'\d'), '');
            final cellType = cellMatch.group(2);
            final cellValue = cellMatch.group(3);
            final inlineString = cellMatch.group(4);
            
            String displayValue = '';
            
            if (inlineString != null && inlineString.isNotEmpty) {
              displayValue = inlineString;
              print('  Cell $cellRef: inline string = "$displayValue"');
            } else if (cellType == 's' && cellValue != null) {
              final stringIndex = int.tryParse(cellValue);
              if (stringIndex != null && sharedStrings.containsKey(stringIndex)) {
                displayValue = sharedStrings[stringIndex]!;
                print('  Cell $cellRef: shared string[$stringIndex] = "$displayValue"');
              } else {
                displayValue = cellValue;
                print('  Cell $cellRef: string index $stringIndex NOT FOUND, using raw: "$displayValue"');
              }
            } else if (cellValue != null && cellValue.isNotEmpty) {
              displayValue = cellValue;
              print('  Cell $cellRef: direct value = "$displayValue"');
            }
            
            if (displayValue.isNotEmpty) {
              rowData[col] = displayValue;
            }
          }
          
          if (rowData.isNotEmpty) {
            allRows.add(rowData);
          }
        }
        
        if (allRows.isNotEmpty) {
          final allColumns = <String>{};
          for (var row in allRows) {
            allColumns.addAll(row.keys);
          }
          final sortedColumns = allColumns.toList()..sort();
          
          buffer.writeln('COLUMNS: ${sortedColumns.join(' | ')}');
          buffer.writeln('');
          
          for (int i = 0; i < allRows.length; i++) {
            final row = allRows[i];
            final values = sortedColumns.map((col) => row[col] ?? '').toList();
            buffer.writeln('Row ${i + 1}: ${values.join(' | ')}');
          }
          
          buffer.writeln('\n--- End of Sheet $sheetCount (${allRows.length} rows, ${sortedColumns.length} columns) ---\n');
        } else {
          buffer.writeln('(Empty sheet)');
        }
      }
      
      if (sheetCount == 0) {
        return 'No worksheets found in XLSX file.';
      }
      
      print('📊 XLSX stats: $sheetCount sheets processed');
      
      return buffer.toString().trim();
    } catch (e) {
      print('❌ XLSX parsing error: $e');
      return 'Error parsing XLSX: $e';
    }
  }

  static Future<File> _convertRtfToText(File rtfFile) async {
    try {
      print('📝 Processing RTF file...');
      
      final content = await rtfFile.readAsString();
      final tempDir = await getTemporaryDirectory();
      final txtFile = File('${tempDir.path}/${_getBaseName(rtfFile)}_converted.txt');
      
      String plainText = content
          .replaceAll(RegExp(r'\\[a-z]+\d*\s?'), '')
          .replaceAll(RegExp(r'[{}]'), '')
          .replaceAll(RegExp(r"\\\'[0-9a-f]{2}"), ' ')
          .replaceAll(RegExp(r'\\\*[^;]+;'), '')
          .replaceAll(RegExp(r'\\[^\s\\]+'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      
      if (plainText.isEmpty) {
        print('⚠️ No text extracted from RTF');
        plainText = 'No text content could be extracted from this RTF document.';
      }
      
      await txtFile.writeAsString(plainText, flush: true);
      print('✅ RTF converted: ${plainText.length} chars -> ${txtFile.path}');
      
      return txtFile;
    } catch (e) {
      print('❌ RTF conversion error: $e');
      rethrow;
    }
  }

  static String _getBaseName(File file) {
    final path = file.path;
    final name = path.split('/').last;
    final lastDot = name.lastIndexOf('.');
    return lastDot > 0 ? name.substring(0, lastDot) : name;
  }

  static String getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf': return '📄';
      case 'doc':
      case 'docx': return '📝';
      case 'xls':
      case 'xlsx':
      case 'csv': return '📊';
      case 'ppt':
      case 'pptx': return '📽️';
      case 'txt': return '📃';
      case 'rtf': return '📋';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp': return '🖼️';
      case 'mp4':
      case 'mpeg':
      case 'webm':
      case 'mov': return '🎬';
      default: return '📎';
    }
  }
}