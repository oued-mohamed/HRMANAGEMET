import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../data/models/user_model.dart';

class DashboardHeaderTitle extends StatelessWidget {
  final double titleFontSize;
  final Color titleColor;
  final String? fallbackName;

  const DashboardHeaderTitle({
    super.key,
    this.titleFontSize = 18,
    this.titleColor = Colors.black87,
    this.fallbackName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: UserService.instance.userStream,
      initialData: UserService.instance.currentUser,
      builder: (context, userSnapshot) {
        final userName =
            userSnapshot.data?.name ?? fallbackName ?? 'Utilisateur';
        return Text(
          'Bonjour $userName',
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.bold,
            color: titleColor,
            letterSpacing: titleFontSize > 20 ? 0.5 : 0,
          ),
        );
      },
    );
  }
}
