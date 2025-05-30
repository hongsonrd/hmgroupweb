// hd_dashboard.dart

import 'package:flutter/material.dart';

class HDDashboard extends StatefulWidget {
  final String currentPeriod;
  final String nextPeriod;

  const HDDashboard({
    Key? key,
    required this.currentPeriod,
    required this.nextPeriod,
  }) : super(key: key);

  @override
  _HDDashboardState createState() => _HDDashboardState();
}

class _HDDashboardState extends State<HDDashboard> {
    @override
  void initState() {
    super.initState();
    print("HD Dashboard initialized with periods:");
    print("Current: ${widget.currentPeriod}");
    print("Next: ${widget.nextPeriod}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HD Dashboard'),
        backgroundColor: Color(0xFF024965),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment,
              size: 100,
              color: Colors.grey[400],
            ),
            SizedBox(height: 20),
            Text(
              'HD Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Trang này đang được phát triển',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}