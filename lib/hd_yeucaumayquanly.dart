// hd_yeucaumayquanly.dart

import 'package:flutter/material.dart';

class HDYeuCauMayQuanLyScreen extends StatefulWidget {
  final String username;
  final String userRole;
  final String currentPeriod;
  final String nextPeriod;

  const HDYeuCauMayQuanLyScreen({
    Key? key,
    required this.username,
    required this.userRole,
    required this.currentPeriod,
    required this.nextPeriod,
  }) : super(key: key);

  @override
  _HDYeuCauMayQuanLyScreenState createState() => _HDYeuCauMayQuanLyScreenState();
}

class _HDYeuCauMayQuanLyScreenState extends State<HDYeuCauMayQuanLyScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản lý yêu cầu máy móc'),
        backgroundColor: Color(0xFF024965),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text(
          'Tính năng đang phát triển',
          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
        ),
      ),
    );
  }
}