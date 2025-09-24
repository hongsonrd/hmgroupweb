import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PayAccountScreen extends StatefulWidget {
  final String username;
  final String userRole;
  final List<Map<String, dynamic>> accountData;

  const PayAccountScreen({
    Key? key,
    required this.username,
    required this.userRole,
    required this.accountData,
  }) : super(key: key);

  @override
  State<PayAccountScreen> createState() => _PayAccountScreenState();
}

class _PayAccountScreenState extends State<PayAccountScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedBP = 'Tất cả';
  String _selectedAvatar = 'Tất cả';
  String _selectedStatus = 'Tất cả';
  List<Map<String, dynamic>> _filteredData = [];
  bool _buttonsEnabled = true;
  static const String baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';

  @override
  void initState() {
    super.initState();
    _filteredData = List.from(widget.accountData);
    _sortAccountsByStatus();
    _searchController.addListener(_filterAccounts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _sortAccountsByStatus() {
    _filteredData.sort((a, b) {
      final aActive = _isActive(a);
      final bActive = _isActive(b);
      if (aActive && !bActive) return -1;
      if (!aActive && bActive) return 1;
      return 0;
    });
  }

  bool _isActive(Map<String, dynamic> account) {
    final avatar = account['Avatar']?.toString() ?? '';
    return avatar.isNotEmpty && avatar != 'N/A';
  }

  List<String> _getBPOptions() {
    final bpSet = <String>{'Tất cả'};
    for (final account in widget.accountData) {
      final bp = account['BP']?.toString() ?? '';
      if (bp.isNotEmpty && bp != 'N/A') {
        bpSet.add(bp);
      }
    }
    return bpSet.toList();
  }

  List<String> _getBPOptionsForCreate() {
    final bpSet = <String>{};
    for (final account in widget.accountData) {
      final bp = account['BP']?.toString() ?? '';
      if (bp.isNotEmpty && bp != 'N/A') {
        bpSet.add(bp);
      }
    }
    return bpSet.toList();
  }

  List<String> _getAvatarOptions() {
    final avatarSet = <String>{'Tất cả'};
    for (final account in widget.accountData) {
      final avatar = account['Avatar']?.toString() ?? '';
      if (avatar.isNotEmpty && avatar != 'N/A') {
        avatarSet.add(avatar);
      }
    }
    return avatarSet.toList();
  }

  bool _isDuplicateUsername(String username, [String? excludeOriginal]) {
    return widget.accountData.any((account) {
      final existingUsername = account['Username']?.toString() ?? '';
      return existingUsername == username && existingUsername != excludeOriginal;
    });
  }

  bool _isDuplicateUserID(String userID, [String? excludeOriginal]) {
    return widget.accountData.any((account) {
      final existingUserID = account['UserID']?.toString() ?? '';
      return existingUserID == userID && existingUserID != excludeOriginal;
    });
  }

  void _filterAccounts() {
    final searchQuery = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredData = widget.accountData.where((account) {
        final username = account['Username']?.toString().toLowerCase() ?? '';
        final name = account['Name']?.toString().toLowerCase() ?? '';
        final userID = account['UserID']?.toString().toLowerCase() ?? '';
        
        final matchesSearch = searchQuery.isEmpty ||
            username.contains(searchQuery) ||
            name.contains(searchQuery) ||
            userID.contains(searchQuery);

        final bp = account['BP']?.toString() ?? '';
        final matchesBP = _selectedBP == 'Tất cả' || bp == _selectedBP;

        final avatar = account['Avatar']?.toString() ?? '';
        final matchesAvatar = _selectedAvatar == 'Tất cả' || avatar == _selectedAvatar;

        final isActive = _isActive(account);
        final matchesStatus = _selectedStatus == 'Tất cả' ||
            (_selectedStatus == 'Hoạt động' && isActive) ||
            (_selectedStatus == 'Không hoạt động' && !isActive);

        return matchesSearch && matchesBP && matchesAvatar && matchesStatus;
      }).toList();
      
      _sortAccountsByStatus();
    });
  }

  String? _validateUsername(String? value, String avatar) {
    if (value == null || value.isEmpty) {
      return 'Trường này là bắt buộc';
    }
    if (_isDuplicateUsername(value)) {
      return 'Username đã tồn tại';
    }
    
    final avatarType = avatar.trim();
    if (avatarType == '1' || avatarType == '2' || avatarType == '4') {
      if (!value.toLowerCase().startsWith('hm.')) {
        return 'Username phải bắt đầu với "hm." cho loại tài khoản này';
      }
    } else if (avatarType == '5') {
      if (!value.toLowerCase().startsWith('kh.')) {
        return 'Username phải bắt đầu với "kh." cho khách hàng';
      }
    }
    
    return null;
  }

  String? _validateAvatar(String? value) {
    if (value == null || value.isEmpty) {
      return 'Trường này là bắt buộc';
    }
    if (value.trim() == '3') {
      return 'Không được tạo tài khoản loại 3 (công nhân) ở đây';
    }
    if (!['1', '2', '4', '5'].contains(value.trim())) {
      return 'Avatar chỉ được phép: 1 (giám sát), 2 (văn phòng), 4 (thợ máy), 5 (khách hàng)';
    }
    return null;
  }

  void _showCreateAccountDialog() {
    if (!_buttonsEnabled) return;
    
    final formKey = GlobalKey<FormState>();
    final controllers = {
      'Username': TextEditingController(),
      'Password': TextEditingController(),
      'Name': TextEditingController(),
      'UserID': TextEditingController(),
      'Avatar': TextEditingController(),
      'ChamCong': TextEditingController(),
    };
    String selectedBP = '';
    final bpOptions = _getBPOptionsForCreate();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tạo tài khoản mới'),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['Username']!,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => _validateUsername(value, controllers['Avatar']!.text),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['Password']!,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Trường này là bắt buộc';
                          }
                          if (value.length < 6 || value.length > 10) {
                            return 'Mật khẩu phải từ 6-10 ký tự';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['Name']!,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Trường này là bắt buộc';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['UserID']!,
                        decoration: const InputDecoration(
                          labelText: 'UserID',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Trường này là bắt buộc';
                          }
                          if (_isDuplicateUserID(value)) {
                            return 'User ID đã tồn tại';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['Avatar']!,
                        decoration: const InputDecoration(
                          labelText: 'Avatar (1,2,4,5)',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateAvatar,
                        onChanged: (value) {
                          setDialogState(() {});
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        value: selectedBP.isEmpty ? null : selectedBP,
                        decoration: const InputDecoration(
                          labelText: 'BP',
                          border: OutlineInputBorder(),
                        ),
                        items: bpOptions.map((bp) {
                          return DropdownMenuItem(value: bp, child: Text(bp));
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedBP = value ?? '';
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng chọn BP';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['ChamCong']!,
                        decoration: const InputDecoration(
                          labelText: 'ChamCong',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Trường này là bắt buộc';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  _confirmCreateAccount(controllers, selectedBP);
                }
              },
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCreateAccount(Map<String, TextEditingController> controllers, String selectedBP) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc chắn muốn tạo tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              _createAccount(controllers, selectedBP);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Future<void> _createAccount(Map<String, TextEditingController> controllers, String selectedBP) async {
    try {
      final data = {
        'Username': controllers['Username']!.text,
        'Password': controllers['Password']!.text,
        'Name': controllers['Name']!.text,
        'UserID': controllers['UserID']!.text,
        'BP': selectedBP,
        'Avatar': controllers['Avatar']!.text,
        'ChamCong': controllers['ChamCong']!.text,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/paynew/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo tài khoản thành công')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi kết nối')),
      );
    }
  }

  void _showStopAccountDialog() {
    if (!_buttonsEnabled) return;
    
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dừng tài khoản'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bạn có chắc chắn muốn dừng tài khoản?'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Nhập username cần dừng',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                _stopAccount(controller.text);
              }
            },
            child: const Text('Dừng'),
          ),
        ],
      ),
    );
  }

  Future<void> _stopAccount(String username) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/paystop/$username'),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dừng tài khoản thành công')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi kết nối')),
      );
    }
  }

  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ghi chú - Quy tắc hệ thống'),
        content: const SingleChildScrollView(
          child: Text(
            '''Avatar là loại tài khoản:
- 3 = công nhân (không nên tạo ở đây)
- 2 = nhân viên văn phòng
- 1 = giám sát công trình
- 4 = thợ máy
- 5 = khách hàng

BP là giá trị phòng ban, chỉ chọn từ các giá trị có sẵn.

Chấm công là tên nhóm để phân loại nhân viên trong bảng khác.

Tất cả các trường đều bắt buộc.

Mật khẩu phải từ 6-10 ký tự, chỉ sử dụng số và chữ thường, không dùng ký tự đặc biệt.

Username:
- Giám sát/nhân viên: bắt đầu với "hm."
- Khách hàng: bắt đầu với "kh."

Nút dừng tài khoản sẽ đăng xuất trên thiết bị, hãy sử dụng cẩn thận!''',
            style: TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showEditAccountDialog(Map<String, dynamic> account) {
    if (!_buttonsEnabled) return;
    
    final formKey = GlobalKey<FormState>();
    final originalUsername = account['Username']?.toString() ?? '';
    final originalUserID = account['UserID']?.toString() ?? '';
    
    final controllers = {
      'Username': TextEditingController(text: originalUsername),
      'Name': TextEditingController(text: account['Name']?.toString() ?? ''),
      'UserID': TextEditingController(text: originalUserID),
      'Avatar': TextEditingController(text: account['Avatar']?.toString() ?? ''),
      'ChamCong': TextEditingController(text: account['ChamCong']?.toString() ?? account['Chấm công']?.toString() ?? ''),
    };
    String selectedBP = account['BP']?.toString() ?? '';
    final bpOptions = _getBPOptionsForCreate();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Chỉnh sửa tài khoản'),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['Username']!,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Trường này là bắt buộc';
                          }
                          if (_isDuplicateUsername(value, originalUsername)) {
                            return 'Username đã tồn tại';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['Name']!,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Trường này là bắt buộc';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['UserID']!,
                        decoration: const InputDecoration(
                          labelText: 'UserID',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Trường này là bắt buộc';
                          }
                          if (_isDuplicateUserID(value, originalUserID)) {
                            return 'User ID đã tồn tại';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['Avatar']!,
                        decoration: const InputDecoration(
                          labelText: 'Avatar',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Trường này là bắt buộc';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        value: selectedBP.isEmpty ? null : selectedBP,
                        decoration: const InputDecoration(
                          labelText: 'BP',
                          border: OutlineInputBorder(),
                        ),
                        items: bpOptions.map((bp) {
                          return DropdownMenuItem(value: bp, child: Text(bp));
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedBP = value ?? '';
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng chọn BP';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers['ChamCong']!,
                        decoration: const InputDecoration(
                          labelText: 'ChamCong',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Trường này là bắt buộc';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  _updateAccount(account, controllers, selectedBP);
                }
              },
              child: const Text('Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(Map<String, dynamic> account) {
    if (!_buttonsEnabled) return;
    
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi mật khẩu'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mật khẩu mới',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Mật khẩu không được để trống';
              }
              if (value.length < 6 || value.length > 10) {
                return 'Mật khẩu phải từ 6-10 ký tự';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                _updatePassword(account, controller.text);
              }
            },
            child: const Text('Đổi'),
          ),
        ],
      ),
    );
  }

  void _showReactivateAccountDialog(Map<String, dynamic> account) {
    if (!_buttonsEnabled) return;
    
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kích hoạt tài khoản'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Giá trị Avatar',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Avatar không được để trống';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                _reactivateAccount(account, controller.text);
              }
            },
            child: const Text('Kích hoạt'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAccount(Map<String, dynamic> originalAccount, Map<String, TextEditingController> controllers, String selectedBP) async {
    try {
      final data = {
        'Username': controllers['Username']!.text,
        'Password': originalAccount['Password']?.toString() ?? '',
        'Name': controllers['Name']!.text,
        'UserID': controllers['UserID']!.text,
        'BP': selectedBP,
        'Avatar': controllers['Avatar']!.text,
        'ChamCong': controllers['ChamCong']!.text,
        'OriginalUsername': originalAccount['Username']?.toString() ?? '',
      };

      final response = await http.post(
        Uri.parse('$baseUrl/paycapnhat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật tài khoản thành công')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi kết nối')),
      );
    }
  }

  Future<void> _updatePassword(Map<String, dynamic> account, String newPassword) async {
    try {
      final data = {
        'Username': account['Username']?.toString() ?? '',
        'Password': newPassword,
        'Name': account['Name']?.toString() ?? '',
        'UserID': account['UserID']?.toString() ?? '',
        'BP': account['BP']?.toString() ?? '',
        'Avatar': account['Avatar']?.toString() ?? '',
        'ChamCong': account['ChamCong']?.toString() ?? account['Chấm công']?.toString() ?? '',
        'OriginalUsername': account['Username']?.toString() ?? '',
        'PasswordOnly': true,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/paycapnhat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đổi mật khẩu thành công')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi kết nối')),
      );
    }
  }

  Future<void> _reactivateAccount(Map<String, dynamic> account, String avatarValue) async {
    try {
      final data = {
        'Username': account['Username']?.toString() ?? '',
        'Password': account['Password']?.toString() ?? '',
        'Name': account['Name']?.toString() ?? '',
        'UserID': account['UserID']?.toString() ?? '',
        'BP': account['BP']?.toString() ?? '',
        'Avatar': avatarValue,
        'ChamCong': account['ChamCong']?.toString() ?? account['Chấm công']?.toString() ?? '',
        'OriginalUsername': account['Username']?.toString() ?? '',
      };

      final response = await http.post(
        Uri.parse('$baseUrl/paycapnhat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kích hoạt tài khoản thành công')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi kết nối')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Tài khoản app - ${widget.username}'),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.purple[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Thông tin hệ thống',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Người dùng hiện tại:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text(widget.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Vai trò:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getRoleColor(widget.userRole).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _getRoleColor(widget.userRole), width: 1),
                            ),
                            child: Text(
                              widget.userRole,
                              style: TextStyle(
                                color: _getRoleColor(widget.userRole),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tổng số tài khoản: ${widget.accountData.length} | Hiển thị: ${_filteredData.length}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm theo Username, Tên, hoặc User ID...',
                  prefixIcon: Icon(Icons.search, color: Colors.purple[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.purple[200]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedBP,
                        items: _getBPOptions().map((bp) {
                          return DropdownMenuItem(
                            value: bp,
                            child: Text('BP: $bp', style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedBP = value!;
                            _filterAccounts();
                          });
                        },
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.purple[200]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedAvatar,
                        items: _getAvatarOptions().map((avatar) {
                          return DropdownMenuItem(
                            value: avatar,
                            child: Text('Avatar: $avatar', style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedAvatar = value!;
                            _filterAccounts();
                          });
                        },
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.purple[200]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStatus,
                        items: ['Tất cả', 'Hoạt động', 'Không hoạt động'].map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status, style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value!;
                            _filterAccounts();
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _buttonsEnabled ? _showCreateAccountDialog : null,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Tạo tài khoản', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _buttonsEnabled ? Colors.green : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _buttonsEnabled ? _showStopAccountDialog : null,
                    icon: const Icon(Icons.stop, size: 16),
                    label: const Text('Dừng tài khoản', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _buttonsEnabled ? Colors.red : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showRulesDialog,
                    icon: const Icon(Icons.info, size: 16),
                    label: const Text('Ghi chú', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.people, color: Colors.purple[600], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Danh sách tài khoản',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _filteredData.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Không có dữ liệu tài khoản',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(0),
                              itemCount: _filteredData.length,
                              itemBuilder: (context, index) {
                                final account = _filteredData[index];
                                return _buildAccountItem(account, index);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Admin':
        return Colors.red;
      case 'HR':
        return Colors.blue;
      case 'AC':
        return Colors.green;
      case 'Viewer':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildAccountItem(Map<String, dynamic> account, int index) {
    final username = account['Username']?.toString() ?? 'N/A';
    final password = account['Password']?.toString() ?? '';
    final name = account['Name']?.toString() ?? 'N/A';
    final userID = account['UserID']?.toString() ?? 'N/A';
    final bp = account['BP']?.toString() ?? 'N/A';
    final avatar = account['Avatar']?.toString() ?? 'N/A';
    final isActive = _isActive(account);
    final chamCong = account['ChamCong']?.toString() ?? 
                     account['Chấm công']?.toString() ?? 
                     'N/A';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: ExpansionTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isActive ? Colors.green[100] : Colors.red[100],
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: isActive ? Colors.green[600] : Colors.red[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isActive ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isActive ? 'Hoạt động' : 'Không hoạt động',
                style: TextStyle(
                  color: isActive ? Colors.green[700] : Colors.red[700],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          name,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(2),
                  },
                  children: [
                    _buildTableRow('Username', username),
                    _buildTableRow('Password', '••••••••'),
                    _buildTableRow('Tên', name),
                    _buildTableRow('User ID', userID),
                    _buildTableRow('BP', bp),
                    _buildTableRow('Avatar', avatar),
                    _buildTableRow('Chấm công', chamCong),
                    _buildTableRow('Trạng thái', isActive ? 'Hoạt động' : 'Không hoạt động'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _buttonsEnabled ? () => _showEditAccountDialog(account) : null,
                        icon: const Icon(Icons.edit, size: 14),
                        label: const Text('Sửa', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _buttonsEnabled ? Colors.blue : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _buttonsEnabled ? () => _showChangePasswordDialog(account) : null,
                        icon: const Icon(Icons.lock, size: 14),
                        label: const Text('Đổi MK', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _buttonsEnabled ? Colors.orange : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (_buttonsEnabled && !isActive) ? () => _showReactivateAccountDialog(account) : null,
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Kích hoạt', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_buttonsEnabled && !isActive) ? Colors.green : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}