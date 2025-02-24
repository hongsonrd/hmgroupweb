import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dongphucmanager.dart';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'projectworker2.dart';
import 'projectorder2.dart';
import 'projectmanagement.dart';

class ProjectManager extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DBHelper>(
          create: (_) => DBHelper(),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text('Quản lý hệ thống'),
          backgroundColor: Color.fromARGB(255, 114, 255, 217),
        ),
        body: GridView.count(
          padding: EdgeInsets.all(12),
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 1.2,
          children: [
            _buildGridItem(
              context,
              'Đơn đồng phục',
              Icons.checkroom,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DongPhucManager()),
              ),
            ),
            _buildGridItem(
              context,
              'Kiểm tra chấm công',
              Icons.timer,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectWorker2(
                    selectedBoPhan: 'QLDV',
                  ),
                ),
              ),
            ),
            _buildGridItem(
              context,
              'Duyệt vật tư',
              Icons.inventory,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectOrder2(
                    selectedBoPhan: 'QLDV',
                  ),
                ),
              ),
            ),
            _buildGridItem(
              context,
              'Giao diện GS',
              Icons.dashboard,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectManagement(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    // Rest of the _buildGridItem implementation remains the same
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Center(child: CircularProgressIndicator());
          },
        );
        
        Future.delayed(Duration(milliseconds: 100), () {
          Navigator.pop(context);
          onTap();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Color.fromARGB(255, 0, 154, 225)),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}