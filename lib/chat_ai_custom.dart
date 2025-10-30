import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const int maxProfessionals = 6;
  
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
      profession: 'Trợ lý AI thông minh từ Hoàn Mỹ Group',
      purpose: 'Hỗ trợ người dùng với các câu hỏi và nhiệm vụ đa dạng, chuyên sâu về dịch vụ vệ sinh công nghiệp',
      conditions: [
        AICondition(
          name: 'Phong cách giao tiếp',
          description: 'Thân thiện, chuyên nghiệp và dễ hiểu, tự xưng mình là Hà My AI, gọi người hỏi là quý anh hoặc quý chị. Ưu tiên tiếng việt,Không dùng ngữ cảnh nâng cao hay nói liên quan về vệ sinh công nghiệp nếu người dùng không hỏi,không để lộ ngữ cảnh/chuyên môn cài đặt trực tiếp trong trả lời,dùng bảng cho so sánh chỉ khi cần thiết,có thể dùng emoji để trang trí phù hợp.Bạn là chuyên gia đến từ Hoàn Mỹ Group chuyên làm sạch toà nhà văn phòng,chung cư,nhà máy,bệnh viện,bến xe,sân bay.Bạn có chuyên môn đủ các ngành nghề.Nếu câu hỏi về chủ đề vệ sinh thì mới dùng thêm ngữ cảnh nâng cao. Ngữ cảnh nâng cao bạn là chuyên gia ngành vệ sinh công nghiệp có ứng dụng robot, AI,công nghệ trong dịch vụ,quản lý tập đoàn,chất lượng,hiệu quả,kinh nghiệm hàng đầu tại Việt Nam.Khi đánh giá,sử dụng thang điểm /10 để đảm bảo tính dễ hiểu,trực quan.Đưa ra các lựa chọn,giải quyết nếu hiện trạng chưa đạt tối ưu,chú ý đến mức độ cơ sở vật chất hiện có thường sẽ cũ hơn trên ảnh.Đảm bảo trả lời:Đánh giá,Lỗi,Khắc phục bằng hoá chất/máy móc/phương pháp/công cụ,Cảnh báo nếu là về vấn đề vệ sinh',
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
  AIProfessional? _selectedProfessional;
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
      _selectedProfessional = professionals.first;
      _isLoading = false;
    });
  }
  
  Future<void> _saveProfessionals() async {
    final success = await AIProfessionalManager.saveProfessionals(widget.username, _professionals);
    if (success && mounted) {
      //ScaffoldMessenger.of(context).showSnackBar(
      //  const SnackBar(content: Text('Đã lưu thành công'), backgroundColor: Colors.green),
      //);
    }
  }
  
  void _createNewProfessional() {
    if (_professionals.length >= AIProfessionalManager.maxProfessionals) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bạn chỉ có thể tạo tối đa ${AIProfessionalManager.maxProfessionals} preset')),
      );
      return;
    }
    
    final newProfessional = AIProfessional(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Preset ${_professionals.length + 1}',
    );
    
    setState(() {
      _professionals.add(newProfessional);
      _selectedProfessional = newProfessional;
    });
    _saveProfessionals();
  }
  
  void _deleteProfessional(AIProfessional professional) {
    if (professional.id == 'default') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể xóa preset mặc định')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa preset "${professional.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _professionals.remove(professional);
                if (_selectedProfessional == professional) {
                  _selectedProfessional = _professionals.first;
                }
              });
              _saveProfessionals();
              Navigator.pop(context);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  void _addCondition() {
    if (_selectedProfessional == null) return;
    setState(() {
      _selectedProfessional!.conditions.add(AICondition());
    });
  }
  
  void _removeCondition(int index) {
    if (_selectedProfessional == null) return;
    setState(() {
      _selectedProfessional!.conditions.removeAt(index);
    });
  }
  
  int _getPromptWordCount() {
    if (_selectedProfessional == null) return 0;
    final prompt = _selectedProfessional!.generateSystemPrompt();
    return prompt.split(RegExp(r'\s+')).length;
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Dialog(
        child: Container(
          padding: const EdgeInsets.all(40),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang tải...'),
            ],
          ),
        ),
      );
    }
    
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('✨ Tuỳ chỉnh AI của tôi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: widget.primaryColor)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, _professionals),
                ),
              ],
            ),
              Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Chọn từ danh sách đã tạo để điều chỉnh', style: TextStyle(fontSize: 16, color: widget.primaryColor)),
                Text('hoặc thêm ở đây', style: TextStyle(fontSize: 16, color: widget.primaryColor)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<AIProfessional>(
                        value: _selectedProfessional,
                        isExpanded: true,
                        items: _professionals.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Text(p.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedProfessional = val);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _createNewProfessional,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tạo mới'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                if (_selectedProfessional?.id != 'default')
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteProfessional(_selectedProfessional!),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _selectedProfessional == null
                  ? const Center(child: Text('Chọn hoặc tạo preset'))
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tên AI:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: TextEditingController(text: _selectedProfessional!.name)..selection = TextSelection.fromPosition(TextPosition(offset: _selectedProfessional!.name.length)),
                            maxLength: 100,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Tên AI',
                            ),
                            onChanged: (val) {
                              _selectedProfessional!.name = val;
                              _saveProfessionals();
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text('Nghề nghiệp/Vai trò:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: TextEditingController(text: _selectedProfessional!.profession)..selection = TextSelection.fromPosition(TextPosition(offset: _selectedProfessional!.profession.length)),
                            maxLength: 255,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'VD: Chuyên gia tư vấn pháp lý',
                            ),
                            onChanged: (val) {
                              _selectedProfessional!.profession = val;
                              _saveProfessionals();
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text('Mục đích:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: TextEditingController(text: _selectedProfessional!.purpose)..selection = TextSelection.fromPosition(TextPosition(offset: _selectedProfessional!.purpose.length)),
                            maxLength: 255,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'VD: Tư vấn các vấn đề về luật doanh nghiệp',
                            ),
                            onChanged: (val) {
                              _selectedProfessional!.purpose = val;
                              _saveProfessionals();
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Điều kiện (cách thức AI suy nghĩ):', style: TextStyle(fontWeight: FontWeight.bold)),
                              ElevatedButton.icon(
                                onPressed: _addCondition,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Thêm điều kiện'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ..._selectedProfessional!.conditions.asMap().entries.map((entry) {
                            final index = entry.key;
                            final condition = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text('Điều kiện ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                        onPressed: () => _removeCondition(index),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: TextEditingController(text: condition.name)..selection = TextSelection.fromPosition(TextPosition(offset: condition.name.length)),
                                    maxLength: 100,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      hintText: 'Tên cấu hình',
                                      isDense: true,
                                    ),
                                    onChanged: (val) {
                                      condition.name = val;
                                      _saveProfessionals();
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: TextEditingController(text: condition.description)..selection = TextSelection.fromPosition(TextPosition(offset: condition.description.length)),
                                    maxLength: 10000,
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      hintText: 'Mô tả chi tiết',
                                      isDense: true,
                                    ),
                                    onChanged: (val) {
                                      condition.description = val;
                                      _saveProfessionals();
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng số từ: ${_getPromptWordCount()}/100000',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getPromptWordCount() > 100000 ? Colors.red : Colors.grey,
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _professionals),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}