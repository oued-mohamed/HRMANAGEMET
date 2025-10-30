import 'package:flutter/material.dart';
import '../widgets/employee_drawer.dart';

class EmployeeMenuOverlay extends StatelessWidget {
  const EmployeeMenuOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const EmployeeDrawer(),
      backgroundColor: Colors.transparent,
    );
  }
}
