import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../core/enums/user_role.dart';

class NavigationHelpers {
  /// Navigate back to the appropriate screen:
  /// - If we can pop, just go back
  /// - Otherwise, go back to menu to ensure we stay in authenticated area
  static Future<void> backToPrevious(BuildContext context) async {
    final navigator = Navigator.of(context);

    // Try to pop first - if there's a previous route, just go back
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    // If we can't pop, check the current route to determine where to go
    final currentRoute = ModalRoute.of(context)?.settings.name;
    print('Cannot pop, current route: $currentRoute');

    // If we're already on a menu or dashboard, stay there
    final authenticatedRoutes = [
      '/employee-menu',
      '/manager-menu',
      '/hr-menu',
      '/employee-dashboard',
      '/manager-dashboard',
      '/hr-dashboard',
    ];

    if (currentRoute != null && authenticatedRoutes.contains(currentRoute)) {
      print('Already on authenticated route, staying here');
      return;
    }

    // If we can't pop and we're not on a safe route, go to menu
    // This prevents accidentally going to welcome screen
    try {
      await backToMenu(context);
    } catch (e) {
      print('Error in backToPrevious: $e');
      // Final fallback: try to go to dashboard
      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final role = auth.currentCompany?.userRole ?? UserRole.employee;

        String dashboardRoute;
        if (role == UserRole.manager) {
          dashboardRoute = '/manager-dashboard';
        } else if (role == UserRole.hr) {
          dashboardRoute = '/hr-dashboard';
        } else {
          dashboardRoute = '/employee-dashboard';
        }

        // Use pushReplacementNamed instead of pushNamedAndRemoveUntil
        // to avoid clearing the entire stack
        Navigator.pushReplacementNamed(context, dashboardRoute);
      } catch (e2) {
        print('Error in backToPrevious fallback: $e2');
      }
    }
  }

  static Future<void> backToMenu(BuildContext context) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final role = auth.currentCompany?.userRole ?? UserRole.employee;

      String menuRoute;
      if (role == UserRole.manager) {
        menuRoute = '/manager-menu';
      } else if (role == UserRole.hr) {
        menuRoute = '/hr-menu';
      } else {
        menuRoute = '/employee-menu';
      }

      // Use pushReplacementNamed to navigate to menu
      // This replaces the current route without clearing the entire stack
      // This prevents accidentally going to welcome screen
      Navigator.pushReplacementNamed(context, menuRoute);
    } catch (e) {
      print('Error in backToMenu: $e');
      // Fallback: navigate to employee menu using pushReplacementNamed
      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final role = auth.currentCompany?.userRole ?? UserRole.employee;
        String menuRoute = '/employee-menu';
        if (role == UserRole.manager) {
          menuRoute = '/manager-menu';
        } else if (role == UserRole.hr) {
          menuRoute = '/hr-menu';
        }

        // Use pushReplacementNamed as fallback to avoid clearing stack
        Navigator.pushReplacementNamed(context, menuRoute);
      } catch (e2) {
        print('Error in backToMenu fallback: $e2');
      }
    }
  }
}
