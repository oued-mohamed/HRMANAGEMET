import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../core/enums/user_role.dart';

class NavigationHelpers {
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

      // Define safe routes (routes we can safely pop back to)
      final safeRoutes = [
        '/employee-dashboard',
        '/hr-dashboard',
        '/manager-dashboard',
        '/employee-menu',
        '/hr-menu',
        '/manager-menu',
      ];

      // Always navigate to menu with removeUntil to ensure we don't hit welcome screen
      // This is safer than trying to peek at navigation stack or pop, which might go to unsafe routes
      Navigator.pushNamedAndRemoveUntil(
        context,
        menuRoute,
        (route) {
          final routeName = route.settings.name;
          // Keep safe routes and authenticated entry points
          return safeRoutes.contains(routeName) ||
              routeName == '/login' ||
              routeName == '/company-selection';
        },
      );
    } catch (e) {
      print('Error in backToMenu: $e');
      // Fallback: navigate to employee menu
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final role = auth.currentCompany?.userRole ?? UserRole.employee;
      String menuRoute = '/employee-menu';
      if (role == UserRole.manager) {
        menuRoute = '/manager-menu';
      } else if (role == UserRole.hr) {
        menuRoute = '/hr-menu';
      }

      Navigator.pushNamedAndRemoveUntil(
        context,
        menuRoute,
        (route) {
          final routeName = route.settings.name;
          return routeName == '/employee-dashboard' ||
              routeName == '/hr-dashboard' ||
              routeName == '/manager-dashboard' ||
              routeName == '/employee-menu' ||
              routeName == '/hr-menu' ||
              routeName == '/manager-menu' ||
              routeName == '/login' ||
              routeName == '/company-selection';
        },
      );
    }
  }
}
