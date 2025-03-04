// projectmachineorder.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'user_credentials.dart';

class ProjectMachineOrder extends StatefulWidget {
  final String boPhan;
  final String username;

  const ProjectMachineOrder({
    Key? key,
    required this.boPhan,
    required this.username,
  }) : super(key: key);

  @override
  _ProjectMachineOrderState createState() => _ProjectMachineOrderState();
}

class _ProjectMachineOrderState extends State<ProjectMachineOrder> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _availableMachines = [];
  List<Map<String, dynamic>> _selectedMachines = [];
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAvailableMachines();
    // Initialize with tomorrow's date
    final tomorrow = DateTime.now().add(Duration(days: 1));
    _dateController.text = "${tomorrow.day}/${tomorrow.month}/${tomorrow.year}";
  }

  @override
  void dispose() {
    _dateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableMachines() async {
    setState(() {
      _isLoading = true;
    });

    // This would normally come from an API or database
    // For this example, we'll use sample data
    await Future.delayed(Duration(seconds: 1)); // Simulate network delay

    setState(() {
      _availableMachines = [
        {'id': '1', 'name': 'Máy cắt cỏ công nghiệp', 'type': 'Cắt cỏ', 'available': 3},
        {'id': '2', 'name': 'Máy thổi lá cầm tay', 'type': 'Làm vườn', 'available': 5},
        {'id': '3', 'name': 'Máy phun rửa áp lực', 'type': 'Vệ sinh', 'available': 2},
        {'id': '4', 'name': 'Máy hút bụi công nghiệp', 'type': 'Vệ sinh', 'available': 4},
        {'id': '5', 'name': 'Máy đánh bóng sàn', 'type': 'Vệ sinh', 'available': 1},
      ];
      _isLoading = false;
    });
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  void _addMachine(Map<String, dynamic> machine) {
    setState(() {
      if (machine['available'] > 0) {
        // Check if already in selected list
        int existingIndex = _selectedMachines.indexWhere((m) => m['id'] == machine['id']);
        if (existingIndex >= 0) {
          // Increment quantity if already selected
          _selectedMachines[existingIndex]['quantity']++;
        } else {
          // Add new selection with quantity 1
          _selectedMachines.add({
            ...machine,
            'quantity': 1,
          });
        }
        // Decrease available count
        int availableMachineIndex = _availableMachines.indexWhere((m) => m['id'] == machine['id']);
        _availableMachines[availableMachineIndex]['available']--;
      }
    });
  }

  void _removeMachine(int index) {
    setState(() {
      final machine = _selectedMachines[index];
      // Increase available count
      int availableMachineIndex = _availableMachines.indexWhere((m) => m['id'] == machine['id']);
      _availableMachines[availableMachineIndex]['available'] += machine['quantity'];
      
      // Remove from selected list
      _selectedMachines.removeAt(index);
    });
  }

  void _submitOrder() {
    if (_selectedMachines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng chọn ít nhất một máy móc')),
      );
      return;
    }

    // Show confirmation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận đặt máy móc'),
        content: Text('Bạn muốn đặt ${_selectedMachines.length} loại máy cho bộ phận ${widget.boPhan}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _processOrder();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 0, 204, 34),
              foregroundColor: Colors.white,
            ),
            child: Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  void _processOrder() {
    // Show loading indicator
    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        _isLoading = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đặt máy móc thành công'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final userCredentials = Provider.of<UserCredentials>(context);
    String username = userCredentials.username.toUpperCase();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 45,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromARGB(255, 255, 160, 114),
                Color.fromARGB(255, 255, 201, 155),
                Color.fromARGB(255, 255, 127, 79),
                Color.fromARGB(255, 255, 188, 150),
              ],
            ),
          ),
        ),
        title: Text(
          'Đặt máy móc - $username',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_selectedMachines.isNotEmpty)
            TextButton(
              onPressed: _submitOrder,
              style: TextButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 255, 255, 255),
              ),
              child: Text(
                'Đặt hàng',
                style: TextStyle(
                  fontSize: 12,
                  color: const Color.fromARGB(255, 0, 204, 34),
                ),
              ),
            ),
          SizedBox(width: 16)
        ],
      ),
      body: _isLoading
        ? Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color.fromARGB(255, 255, 127, 79),
              ),
            ),
          )
        : Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đặt máy móc cho bộ phận: ${widget.boPhan}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _dateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Ngày cần sử dụng',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        onTap: _selectDate,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: 'Ghi chú',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 16),
                Text(
                  'Máy móc đã chọn (${_selectedMachines.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                if (_selectedMachines.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Chưa có máy móc nào được chọn',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    flex: 1,
                    child: ListView.builder(
                      itemCount: _selectedMachines.length,
                      itemBuilder: (context, index) {
                        final machine = _selectedMachines[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(machine['name']),
                            subtitle: Text('Loại: ${machine['type']}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('SL: ${machine['quantity']}'),
                                SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeMachine(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                SizedBox(height: 16),
                Text(
                  'Máy móc có sẵn',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Expanded(
                  flex: 2,
                  child: ListView.builder(
                    itemCount: _availableMachines.length,
                    itemBuilder: (context, index) {
                      final machine = _availableMachines[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(machine['name']),
                          subtitle: Text('Loại: ${machine['type']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Còn: ${machine['available']}'),
                              SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  Icons.add_circle,
                                  color: machine['available'] > 0
                                    ? const Color.fromARGB(255, 0, 204, 34)
                                    : Colors.grey,
                                ),
                                onPressed: machine['available'] > 0
                                  ? () => _addMachine(machine)
                                  : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      floatingActionButton: _selectedMachines.isNotEmpty
        ? FloatingActionButton(
            onPressed: _submitOrder,
            backgroundColor: const Color.fromARGB(255, 0, 204, 34),
            child: Icon(Icons.check),
          )
        : null,
    );
  }
}