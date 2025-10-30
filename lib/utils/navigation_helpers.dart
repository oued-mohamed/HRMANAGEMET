import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../core/enums/user_role.dart';

class NavigationHelpers {
  static Future<void> backToMenu(BuildContext context) async {
    try {
      // If there is a previous page (e.g., menu), simply pop to preserve history
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final role = auth.currentCompany?.userRole ?? UserRole.employee;
      final route =
          role == UserRole.manager ? '/manager-menu' : '/employee-menu';
      // If nothing to pop, replace with the appropriate menu
      Navigator.pushReplacementNamed(context, route);
    } catch (_) {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        Navigator.pushReplacementNamed(context, '/employee-menu');
      }
    }
  }
}
