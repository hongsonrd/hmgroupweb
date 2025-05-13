// projectmanagement4ad.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
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
  title: Text('Worker Dashboard3'),
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