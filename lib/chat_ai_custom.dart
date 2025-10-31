import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'chat_ai_convert.dart';

class AIProfessional {
  String id;
  String name;
  String profession;
  String purpose;
  List<AICondition> conditions;
  
  AIProfessional({
    required this.id,
    required this.name,
    this.profession = '',
    this.purpose = '',
    List<AICondition>? conditions,
  }) : conditions = conditions ?? [];
  
  String generateSystemPrompt() {
    final buffer = StringBuffer();
    
    if (profession.isNotEmpty) {
      buffer.write('Vai trò: $profession. ');
    }
    if (purpose.isNotEmpty) {
      buffer.write('Mục đích: $purpose. ');
    }
    
    if (conditions.isNotEmpty) {
      buffer.write('Điều kiện: ');
      for (var condition in conditions) {
        if (condition.name.isNotEmpty) {
          buffer.write('${condition.name}');
          if (condition.description.isNotEmpty) {
            buffer.write(': ${condition.description}');
          }
          buffer.write('. ');
        }
      }
    }
    
    String prompt = buffer.toString().trim();
    if (prompt.isNotEmpty) {
      prompt += ',Sau đây là câu hỏi của người dùng:';
    }
    
    final wordCount = prompt.split(RegExp(r'\s+')).length;
    if (wordCount > 100000) {
      return '';
    }
    
    return prompt;
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'profession': profession,
    'purpose': purpose,
    'conditions': conditions.map((c) => c.toJson()).toList(),
  };
  
  factory AIProfessional.fromJson(Map<String, dynamic> json) => AIProfessional(
    id: json['id'],
    name: json['name'],
    profession: json['profession'] ?? '',
    purpose: json['purpose'] ?? '',
    conditions: (json['conditions'] as List?)?.map((c) => AICondition.fromJson(c)).toList(),
  );
}

class AICondition {
  String name;
  String description;
  
  AICondition({this.name = '', this.description = ''});
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
  };
  
  factory AICondition.fromJson(Map<String, dynamic> json) => AICondition(
    name: json['name'] ?? '',
    description: json['description'] ?? '',
  );
}

class AIProfessionalManager {
  static const String _storageKey = 'ai_professionals';
  static const int maxProfessionals = 12;
  
  static Future<List<AIProfessional>> loadProfessionals(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_storageKey}_$username';
    final jsonString = prefs.getString(key);
    
    if (jsonString == null) {
      return [_getDefaultProfessional()];
    }
    
    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      final professionals = jsonList.map((j) => AIProfessional.fromJson(j)).toList();
      
      if (professionals.isEmpty) {
        return [_getDefaultProfessional()];
      }
      
      return professionals;
    } catch (e) {
      return [_getDefaultProfessional()];
    }
  }
  
  static Future<bool> saveProfessionals(String username, List<AIProfessional> professionals) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_storageKey}_$username';
      final jsonString = json.encode(professionals.map((p) => p.toJson()).toList());
      return await prefs.setString(key, jsonString);
    } catch (e) {
      return false;
    }
  }
  
  static AIProfessional _getDefaultProfessional() {
    return AIProfessional(
      id: 'default',
      name: 'Hà My AI',
      profession: 'Trợ lý AI đa năng',
      purpose: 'Hỗ trợ người dùng trong mọi tác vụ',
      conditions: [
        AICondition(
          name: 'Phong cách giao tiếp',
          description: 'Thân thiện, chuyên nghiệp và dễ hiểu',
        ),
      ],
    );
  }
}

class CustomAIDialog extends StatefulWidget {
  final String username;
  final Color primaryColor;
  
  const CustomAIDialog({
    Key? key,
    required this.username,
    required this.primaryColor,
  }) : super(key: key);
  
  @override
  State<CustomAIDialog> createState() => _CustomAIDialogState();
}

class _CustomAIDialogState extends State<CustomAIDialog> {
  List<AIProfessional> _professionals = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadProfessionals();
  }
  
  Future<void> _loadProfessionals() async {
    setState(() => _isLoading = true);
    final professionals = await AIProfessionalManager.loadProfessionals(widget.username);
    setState(() {
      _professionals = professionals;
      _isLoading = false;
    });
  }
  
  Future<void> _saveProfessionals() async {
    await AIProfessionalManager.saveProfessionals(widget.username, _professionals);
  }
  
  void _createNewProfessional() {
    if (_professionals.length >= AIProfessionalManager.maxProfessionals) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bạn chỉ có thể tạo tối đa ${AIProfessionalManager.maxProfessionals} preset'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final newProfessional = AIProfessional(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'AI Preset ${_professionals.length + 1}',
    );
    
    setState(() {
      _professionals.add(newProfessional);
    });
    _saveProfessionals();
    
    _openEditScreen(newProfessional);
  }
  
  void _openEditScreen(AIProfessional professional) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfessionalScreen(
          professional: professional,
          username: widget.username,
          primaryColor: widget.primaryColor,
          onSave: (updated) {
            final index = _professionals.indexWhere((p) => p.id == updated.id);
            if (index != -1) {
              setState(() {
                _professionals[index] = updated;
              });
              _saveProfessionals();
            }
          },
          onDelete: () {
            setState(() {
              _professionals.removeWhere((p) => p.id == professional.id);
            });
            _saveProfessionals();
          },
        ),
      ),
    );
    
    if (result == true) {
      _loadProfessionals();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Dialog(
        backgroundColor: const Color(0xFF1A1F2E),
        child: Container(
          padding: const EdgeInsets.all(40),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.deepPurple),
              SizedBox(height: 16),
              Text('Đang tải...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }
    
    return Dialog(
      backgroundColor: const Color(0xFF1A1F2E),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '✨ Quản lý AI của tôi',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context, _professionals),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tạo và quản lý các mẫu AI tuỳ chỉnh (${_professionals.length}/${AIProfessionalManager.maxProfessionals})',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemCount: _professionals.length + 1,
                itemBuilder: (context, index) {
                  if (index == _professionals.length) {
                    return _buildAddCard();
                  }
                  return _buildProfessionalCard(_professionals[index]);
                },
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _professionals),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProfessionalCard(AIProfessional professional) {
    final isDefault = professional.id == 'default';
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openEditScreen(professional),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF252D3D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDefault ? Colors.amber.withOpacity(0.5) : Colors.deepPurple.withOpacity(0.3),
              width: 5,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.psychology, color: Colors.teal, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                professional.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isDefault)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Mặc định',
                                    style: TextStyle(color: Colors.amber, fontSize: 10),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (professional.profession.isNotEmpty)
                      Text(
                        professional.profession,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.rule, size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          '${professional.conditions.length} điều kiện',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.edit,
                  color: Colors.grey.shade600,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildAddCard() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _createNewProfessional,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF252D3D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.deepPurple.withOpacity(0.5),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 48,
                color: Colors.deepPurple.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                'Tạo chuyên gia AI mới',
                style: TextStyle(
                  color: Colors.deepPurple.shade300,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditProfessionalScreen extends StatefulWidget {
  final AIProfessional professional;
  final String username;
  final Color primaryColor;
  final Function(AIProfessional) onSave;
  final VoidCallback onDelete;
  
  const EditProfessionalScreen({
    Key? key,
    required this.professional,
    required this.username,
    required this.primaryColor,
    required this.onSave,
    required this.onDelete,
  }) : super(key: key);
  
  @override
  State<EditProfessionalScreen> createState() => _EditProfessionalScreenState();
}

class _EditProfessionalScreenState extends State<EditProfessionalScreen> {
  late AIProfessional _editedProfessional;
  final Map<int, TextEditingController> _conditionNameControllers = {};
  final Map<int, TextEditingController> _conditionDescControllers = {};
  
  @override
  void initState() {
    super.initState();
    _editedProfessional = AIProfessional(
      id: widget.professional.id,
      name: widget.professional.name,
      profession: widget.professional.profession,
      purpose: widget.professional.purpose,
      conditions: widget.professional.conditions.map((c) => AICondition(name: c.name, description: c.description)).toList(),
    );
    
    for (int i = 0; i < _editedProfessional.conditions.length; i++) {
      _conditionNameControllers[i] = TextEditingController(text: _editedProfessional.conditions[i].name);
      _conditionDescControllers[i] = TextEditingController(text: _editedProfessional.conditions[i].description);
    }
  }
  
  @override
  void dispose() {
    _conditionNameControllers.values.forEach((c) => c.dispose());
    _conditionDescControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }
  
  void _addCondition() {
    setState(() {
      _editedProfessional.conditions.add(AICondition());
      final index = _editedProfessional.conditions.length - 1;
      _conditionNameControllers[index] = TextEditingController();
      _conditionDescControllers[index] = TextEditingController();
    });
  }
  
  void _removeCondition(int index) {
    setState(() {
      _editedProfessional.conditions.removeAt(index);
      _conditionNameControllers[index]?.dispose();
      _conditionDescControllers[index]?.dispose();
      _conditionNameControllers.remove(index);
      _conditionDescControllers.remove(index);
    });
  }
  
  Future<void> _attachFileToCondition(int index) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['doc', 'docx', 'xls', 'csv', 'xlsx', 'pdf', 'rtf', 'txt'],
        allowMultiple: false,
      );
      
      if (result != null) {
        final file = File(result.files.single.path!);
        final ext = file.path.split('.').last.toLowerCase();
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            backgroundColor: Color(0xFF252D3D),
            content: Row(
              children: [
                CircularProgressIndicator(color: Colors.deepPurple),
                SizedBox(width: 16),
                Text('Đang trích xuất văn bản...', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        );
        
        String extractedText = '';
        
        if (['doc', 'docx', 'csv', 'xls', 'xlsx', 'rtf'].contains(ext)) {
          print('🔄 Converting $ext file...');
          final converted = await DocumentConverter.convertToText(file);
          
          if (converted != null && await converted.exists()) {
            extractedText = await converted.readAsString();
            print('✅ Extracted ${extractedText.length} characters');
          }
        } else if (ext == 'txt') {
          extractedText = await file.readAsString();
        } else if (ext == 'pdf') {
          extractedText = 'PDF file: ${file.path.split('/').last}\n[PDF content will be processed by AI]';
        }
        
        if (mounted) Navigator.pop(context);
        
        if (extractedText.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể trích xuất văn bản từ file'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        setState(() {
          final currentDesc = _conditionDescControllers[index]!.text;
          final newDesc = currentDesc.isEmpty 
              ? extractedText 
              : '$currentDesc\n\n--- File đính kèm: ${file.path.split('/').last} ---\n$extractedText';
          
          _editedProfessional.conditions[index].description = newDesc;
          _conditionDescControllers[index]!.text = newDesc;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã trích xuất ${extractedText.length} ký tự từ file'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  int _getPromptWordCount() {
    final prompt = _editedProfessional.generateSystemPrompt();
    return prompt.split(RegExp(r'\s+')).length;
  }
  
  void _saveAndExit() {
    widget.onSave(_editedProfessional);
    Navigator.pop(context, true);
  }
  
  void _confirmDelete() {
    if (_editedProfessional.id == 'default') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa preset mặc định'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252D3D),
        title: const Text('Xác nhận xóa', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bạn có chắc muốn xóa preset "${_editedProfessional.name}"?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              widget.onDelete();
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final wordCount = _getPromptWordCount();
    final isOverLimit = wordCount > 100000;
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF252D3D),
        title: Text(
          'Chỉnh sửa: ${_editedProfessional.name}',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _saveAndExit,
        ),
        actions: [
          if (_editedProfessional.id != 'default')
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _confirmDelete,
            ),
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: _saveAndExit,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Tên AI'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: TextEditingController(text: _editedProfessional.name)..selection = TextSelection.fromPosition(TextPosition(offset: _editedProfessional.name.length)),
                    maxLength: 100,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Tên AI'),
                    onChanged: (val) => _editedProfessional.name = val,
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader('Nghề nghiệp/Vai trò'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: TextEditingController(text: _editedProfessional.profession)..selection = TextSelection.fromPosition(TextPosition(offset: _editedProfessional.profession.length)),
                    maxLength: 255,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('VD: Chuyên gia tư vấn pháp lý'),
                    onChanged: (val) => _editedProfessional.profession = val,
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader('Mục đích'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: TextEditingController(text: _editedProfessional.purpose)..selection = TextSelection.fromPosition(TextPosition(offset: _editedProfessional.purpose.length)),
                    maxLength: 255,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('VD: Tư vấn các vấn đề về luật doanh nghiệp'),
                    onChanged: (val) => _editedProfessional.purpose = val,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader('Điều kiện (cách AI suy nghĩ)'),
                      ElevatedButton.icon(
                        onPressed: _addCondition,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Thêm điều kiện'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[800],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._editedProfessional.conditions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final condition = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252D3D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Điều kiện ${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.attach_file, color: Colors.teal),
                                onPressed: () => _attachFileToCondition(index),
                                tooltip: 'Đính kèm file',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeCondition(index),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _conditionNameControllers[index],
                            maxLength: 100,
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration('Tên điều kiện'),
                            onChanged: (val) => condition.name = val,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _conditionDescControllers[index],
                            maxLength: 50000,
                            maxLines: 6,
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration('Mô tả chi tiết (hoặc đính kèm file)'),
                            onChanged: (val) => condition.description = val,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF252D3D),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng số từ: $wordCount/100000',
                  style: TextStyle(
                    fontSize: 14,
                    color: isOverLimit ? Colors.red : Colors.grey,
                    fontWeight: isOverLimit ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _saveAndExit,
                  icon: const Icon(Icons.save),
                  label: const Text('Lưu & Đóng'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.teal,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
  
  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFF1E2837),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade800),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade800),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
      ),
    );
  }
}