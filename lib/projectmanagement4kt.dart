// projectmanagement4kt.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({Key? key}) : super(key: key);

  @override
  _WorkerDashboardState createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  String _username = '';

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('current_user') ?? '';
      
      setState(() {
        _username = username;
      });
    } catch (e) {
      print('Error loading username: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
   appBar: AppBar(
  title: Text('Worker Dashboard'),
  leading: IconButton(
    icon: Icon(
      Icons.arrow_back,
      color: Colors.black,
      size: 28,
    ),
    onPressed: () {
      Navigator.pop(context);
    },
  ),
),

      body: Center(
        child: Text(
          'Username: $_username',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}