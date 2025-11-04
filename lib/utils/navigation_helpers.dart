import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../core/enums/user_role.dart';

class NavigationHelpers {
  /// Navigate back to the appropriate screen:
  /// - If we can pop, just go back
  /// - Otherwise, check if we came from menu and go back to menu, else go to dashboard
  static Future<void> backToPrevious(BuildContext context) async {
    final navigator = Navigator.of(context);

    // Try to pop first - if there's a previous route, just go back
    if (navigator.canPop()) {
      // Check if the previous route is a menu route
      final previousRoute = ModalRoute.of(context)?.settings.name;
      if (previousRoute == '/employee-menu' || 
          previousRoute == '/manager-menu' || 
          previousRoute == '/hr-menu') {
        // If current route might be from menu, check navigation history
        // For now, just pop - if it fails, we'll go to menu
        navigator.pop();
        return;
      }
      navigator.pop();
      return;
    }

    // If we can't pop, try to go back to menu first (since user might have come from menu)
    // Check navigation history to see if we came from a menu
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final role = auth.currentCompany?.userRole ?? UserRole.employee;

      // Check if there's a menu route in the navigation stack
      final currentRoute = ModalRoute.of(context)?.settings.name;
      
      // If we're on notifications and can't pop, likely came from menu
      if (currentRoute == '/employee-notifications' || 
          currentRoute == '/manager-notifications') {
        // Go back to menu instead of dashboard
        await backToMenu(context);
        return;
      }

      // Otherwise, go to dashboard
      String dashboardRoute;

      if (role == UserRole.manager) {
        dashboardRoute = '/manager-dashboard';
      } else if (role == UserRole.hr) {
        dashboardRoute = '/hr-dashboard';
      } else {
        dashboardRoute = '/employee-dashboard';
      }

      // Navigate to dashboard
      Navigator.pushNamedAndRemoveUntil(
        context,
        dashboardRoute,
        (route) {
          final routeName = route.settings.name;
          final safeRoutes = [
            '/employee-dashboard',
            '/hr-dashboard',
            '/manager-dashboard',
            '/employee-menu',
            '/hr-menu',
            '/manager-menu',
            '/login',
            '/company-selection',
          ];
          return safeRoutes.contains(routeName);
        },
      );
    } catch (e) {
      print('Error in backToPrevious: $e');
      // Fallback to menu
      await backToMenu(context);
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
