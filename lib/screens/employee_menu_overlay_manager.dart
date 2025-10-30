import 'package:flutter/material.dart';
import '../widgets/manager_drawer.dart';

class ManagerMenuOverlay extends StatelessWidget {
  const ManagerMenuOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const ManagerDrawer(),
      backgroundColor: Colors.transparent,
    );
  }
}
