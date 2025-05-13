// project_router.dart
import 'package:flutter/material.dart';
import 'user_state.dart';
import 'projectmanagement.dart';
import 'projectmanagement2.dart';
import 'projectmanagement4.dart';

class ProjectRouter extends StatelessWidget {
  final UserState userState;
  
  const ProjectRouter({
    Key? key,
    required this.userState,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
  final queryType = userState.queryType;

  if (queryType.isNotEmpty) {
    if (queryType == '1') {
      return ProjectManagement(); 
    } else if (queryType == '2') {
      return ProjectManagement2(); 
    } else if (queryType == '4') {
      return ProjectManagement4(); 
    }
  }
  
  return Container();
}
}