import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';

class LeavesMenuItem extends StatelessWidget {
  final String menuRoute; // '/employee-menu', '/hr-menu', ou '/manager-menu'
  final Widget Function({
    required BuildContext context,
    required AppLocalizations localizations,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) buildExpandableMenuItem;
  final Widget Function({
    required BuildContext context,
    required AppLocalizations localizations,
    required String title,
    required VoidCallback onTap,
  }) buildSubMenuItem;

  const LeavesMenuItem({
    super.key,
    required this.menuRoute,
    required this.buildExpandableMenuItem,
    required this.buildSubMenuItem,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return buildExpandableMenuItem(
      context: context,
      localizations: localizations,
      icon: Icons.event_available,
      title: localizations.translate('leaves'),
      children: [
        buildSubMenuItem(
          context: context,
          localizations: localizations,
          title: localizations.translate('request_leave'),
          onTap: () => _navigateToRoute(context, '/leave-request', alwaysPop: menuRoute == '/employee-menu'),
        ),
        buildSubMenuItem(
          context: context,
          localizations: localizations,
          title: localizations.translate('leave_balance'),
          onTap: () => _navigateToRoute(context, '/leave-balance', alwaysPop: menuRoute == '/employee-menu'),
        ),
        buildSubMenuItem(
          context: context,
          localizations: localizations,
          title: localizations.translate('calendar'),
          onTap: () => _navigateToRoute(context, '/leave-calendar'),
        ),
      ],
    );
  }

  void _navigateToRoute(BuildContext context, String route, {bool alwaysPop = false}) {
    if (alwaysPop) {
      // Employee drawer always pops for request_leave and leave_balance
      Navigator.pop(context);
      Navigator.pushNamed(context, route);
    } else {
      // HR and Manager check the current route
      final currentRoute = ModalRoute.of(context)?.settings.name;
      if (currentRoute == menuRoute) {
        Navigator.pushNamed(context, route);
      } else {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      }
    }
  }
}

