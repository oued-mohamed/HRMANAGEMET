import 'package:flutter/material.dart';
import '../widgets/hr_drawer.dart';

class HRMenuOverlay extends StatelessWidget {
  const HRMenuOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: HRDrawer(),
      backgroundColor: Colors.transparent,
    );
  }
}
