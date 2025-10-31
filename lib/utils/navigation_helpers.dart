import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../core/enums/user_role.dart';

class NavigationHelpers {
  static Future<void> backToMenu(BuildContext context) async {
    try {
      final navigator = Navigator.of(context);

      // If there is a previous page, pop to it (normal back behavior)
      if (navigator.canPop()) {
        // Check if the previous route is safe to pop to (not welcome screen)
        final currentRoute = ModalRoute.of(context);
        if (currentRoute != null) {
          // Pop normally - if previous route is welcome, it will be handled by route guards
          navigator.pop();
          return;
        }
      }

      // If nothing to pop, navigate to menu and clear stack except for authenticated routes
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final role = auth.currentCompany?.userRole ?? UserRole.employee;
      String route;
      if (role == UserRole.manager) {
        route = '/manager-menu';
      } else if (role == UserRole.hr) {
        route = '/hr-menu';
      } else {
        route = '/employee-menu';
      }

      // Navigate to menu and remove all routes until we reach an authenticated route
      // This ensures we don't go back to welcome screen
      Navigator.pushNamedAndRemoveUntil(
        context,
        route,
        (route) {
          // Stop removing routes when we hit an authenticated route
          // We explicitly avoid route.isFirst to prevent going to welcome screen
          final routeName = route.settings.name;
          return routeName == '/employee-dashboard' ||
              routeName == '/hr-dashboard' ||
              routeName == '/manager-dashboard' ||
              routeName == '/employee-menu' ||
              routeName == '/hr-menu' ||
              routeName == '/manager-menu' ||
              routeName == '/login' || // Keep login as fallback
              routeName ==
                  '/company-selection'; // Keep company selection as fallback
        },
      );
    } catch (e) {
      print('Error in backToMenu: $e');
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        // Fallback: navigate to employee menu (same logic as above)
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/employee-menu',
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
}
