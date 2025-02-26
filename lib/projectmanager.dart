import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dongphucmanager.dart';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'projectworker2.dart';
import 'projectorder2.dart';
import 'projectmanagement.dart';
import 'projectplan.dart';
import 'projectmachine.dart'; 
class ProjectManager extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    if (screenWidth > 1200) {
      crossAxisCount = 5;
    } else if (screenWidth > 800) {
      crossAxisCount = 3;
    }
    
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
        body: Container(
          width: screenWidth,
          padding: EdgeInsets.all(screenWidth > 800 ? 32 : 16),
          child: GridView.count(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: screenWidth > 800 ? 24 : 16,
            crossAxisSpacing: screenWidth > 800 ? 24 : 16,
            childAspectRatio: screenWidth > 800 ? 1.5 : 1.0,
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
                'Đơn vật tư',
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
              _buildGridItem(
                context,
                'Kế hoạch',
                Icons.calendar_today,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectPlan(),
                  ),
                ),
              ),
            _buildGridItem(
              context,
              'Quản lý máy móc',
              Icons.build,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectMachine(),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 800;
    
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
          borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
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
            Icon(
              icon, 
              size: isDesktop ? 64 : 48, 
              color: Color.fromARGB(255, 0, 154, 225)
            ),
            SizedBox(height: isDesktop ? 16 : 12),
            Text(
              title,
              style: TextStyle(
                fontSize: isDesktop ? 20 : 16,
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