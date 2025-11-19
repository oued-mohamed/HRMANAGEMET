import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';

class ProfileMenuItem extends StatelessWidget {
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

  const ProfileMenuItem({
    super.key,
    required this.menuRoute,
    required this.buildExpandableMenuItem,
    required this.buildSubMenuItem,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    // Determine which translation key to use for profile settings
    // Employee uses 'profile_settings_menu', HR and Manager use 'profile_settings'
    final profileSettingsKey = menuRoute == '/employee-menu' 
        ? 'profile_settings_menu' 
        : 'profile_settings';
    
    return buildExpandableMenuItem(
      context: context,
      localizations: localizations,
      icon: Icons.person_outline,
      title: localizations.translate('my_profile'),
      children: [
        buildSubMenuItem(
          context: context,
          localizations: localizations,
          title: localizations.translate('personal_employment_info'),
          onTap: () => _navigateToRoute(context, '/personal-info'),
        ),
        buildSubMenuItem(
          context: context,
          localizations: localizations,
          title: localizations.translate('personal_documents'),
          onTap: () => _navigateToRoute(context, '/personal-documents'),
        ),
        buildSubMenuItem(
          context: context,
          localizations: localizations,
          title: localizations.translate(profileSettingsKey),
          onTap: () => _navigateToRoute(context, '/profile-settings'),
        ),
      ],
    );
  }

  void _navigateToRoute(BuildContext context, String route) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    
    // Employee drawer always pops, HR and Manager check the route
    if (menuRoute == '/employee-menu') {
      Navigator.pop(context);
      Navigator.pushNamed(context, route);
    } else {
      if (currentRoute == menuRoute) {
        Navigator.pushNamed(context, route);
      } else {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      }
    }
  }
}

