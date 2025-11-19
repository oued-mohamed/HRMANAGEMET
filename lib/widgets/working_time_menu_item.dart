import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';

class WorkingTimeMenuItem extends StatelessWidget {
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

  const WorkingTimeMenuItem({
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
      icon: Icons.access_time,
      title: localizations.translate('working_time'),
      children: [
        buildSubMenuItem(
          context: context,
          localizations: localizations,
          title: localizations.translate('working_time'),
          onTap: () => _navigateToRoute(context, '/work-time-statistics'),
        ),
        buildSubMenuItem(
          context: context,
          localizations: localizations,
          title: localizations.translate('time_tracking'),
          onTap: () => _navigateToRoute(context, '/attendance'),
        ),
        buildSubMenuItem(
          context: context,
          localizations: localizations,
          title: localizations.translate('time_tracking_history'),
          onTap: () => _navigateToRoute(context, '/attendance-history'),
        ),
      ],
    );
  }

  void _navigateToRoute(BuildContext context, String route) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == menuRoute) {
      Navigator.pushNamed(context, route);
    } else {
      Navigator.pop(context);
      Navigator.pushNamed(context, route);
    }
  }
}

