import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/app_localizations.dart';
import '../services/user_service.dart';
import '../data/models/user_model.dart';
import '../services/notification_service.dart';

class EmployeeDrawer extends StatefulWidget {
  const EmployeeDrawer({super.key});

  @override
  State<EmployeeDrawer> createState() => _EmployeeDrawerState();
}

class _EmployeeDrawerState extends State<EmployeeDrawer> {
  @override
  void initState() {
    super.initState();
    // Initialiser le service si nécessaire
    UserService.instance.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Drawer(
      width: MediaQuery.of(context).size.width,
      child: StreamBuilder<UserModel?>(
        stream: UserService.instance.userStream,
        initialData: UserService.instance.currentUser,
        builder: (context, snapshot) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF000B58), // Deep navy blue
                  Color(0xFF35BF8C), // Bright green
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header with Profile
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/personal-info');
                          },
                          borderRadius: BorderRadius.circular(40),
                          child: _buildProfileAvatar(snapshot.data),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          localizations.translate('employee_space'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white30, thickness: 1),

                  // Menu Items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      children: [
                        // Dashboard Button
                        ListTile(
                          leading: const Icon(
                            Icons.dashboard_outlined,
                            color: Colors.white,
                          ),
                          title: Text(
                            localizations.translate('dashboard'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushReplacementNamed(
                                context, '/employee-dashboard');
                          },
                        ),

                        const Divider(color: Colors.white30, thickness: 1),

                        // 1. Mon profil
                        _buildExpandableMenuItem(
                          context: context,
                          localizations: localizations,
                          icon: Icons.person_outline,
                          title: localizations.translate('my_profile'),
                          children: [
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations
                                  .translate('personal_employment_info'),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/personal-info');
                              },
                            ),
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title:
                                  localizations.translate('personal_documents'),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(
                                    context, '/personal-documents');
                              },
                            ),
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations
                                  .translate('profile_settings_menu'),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(
                                    context, '/profile-settings');
                              },
                            ),
                          ],
                        ),

                        // 2. Congés & absences
                        _buildExpandableMenuItem(
                          context: context,
                          localizations: localizations,
                          icon: Icons.event_available,
                          title: localizations.translate('leaves'),
                          children: [
                            // 1) Faire une demande de congé (first)
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('request_leave'),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/leave-request');
                              },
                            ),
                            // 2) Solde de mes congés
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('leave_balance'),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/leave-balance');
                              },
                            ),
                            // 3) Déclarer une absence imprévue
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations
                                  .translate('report_unexpected_absence'),
                              onTap: () {
                                Navigator.pop(context);
                                _showSnackBar(
                                    context,
                                    localizations.translate(
                                        'report_unexpected_absence'));
                              },
                            ),
                            // 4) Calendrier des congés (last)
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('calendar'),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/leave-calendar');
                              },
                            ),
                          ],
                        ),

                        // 3. Temps de travail
                        _buildExpandableMenuItem(
                          context: context,
                          localizations: localizations,
                          icon: Icons.access_time,
                          title: localizations.translate('working_time'),
                          children: [
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('time_tracking'),
                              onTap: () {
                                Navigator.pop(context);
                                _showSnackBar(context,
                                    localizations.translate('time_tracking'));
                              },
                            ),
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations
                                  .translate('time_tracking_history'),
                              onTap: () {
                                Navigator.pop(context);
                                _showSnackBar(
                                    context,
                                    localizations
                                        .translate('time_tracking_history'));
                              },
                            ),
                          ],
                        ),

                        const Divider(color: Colors.white30, thickness: 1),

                        // 5. Paie & avantages
                        _buildExpandableMenuItem(
                          context: context,
                          localizations: localizations,
                          icon: Icons.account_balance_wallet,
                          title: localizations.translate('pay_benefits'),
                          children: [
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title:
                                  localizations.translate('salary_information'),
                              onTap: () {
                                Navigator.pop(context);
                                _showSnackBar(
                                    context,
                                    localizations
                                        .translate('salary_information'));
                              },
                            ),
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('my_benefits'),
                              onTap: () {
                                Navigator.pop(context);
                                _showSnackBar(context,
                                    localizations.translate('my_benefits'));
                              },
                            ),
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('expense_report'),
                              onTap: () {
                                Navigator.pop(context);
                                _showSnackBar(context,
                                    localizations.translate('expense_report'));
                              },
                            ),
                          ],
                        ),

                        // 5. Notifications
                        _buildNotificationTile(localizations),

                        // Debug: Model Explorer (temporary)
                        ListTile(
                          leading: const Icon(
                            Icons.bug_report,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Model Explorer',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/model-explorer');
                          },
                        ),
                      ],
                    ),
                  ),

                  // Footer - Logout
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Divider(color: Colors.white30),
                        ListTile(
                          leading:
                              const Icon(Icons.logout, color: Colors.white70),
                          title: Text(
                            localizations.translate('logout'),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          onTap: () {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/login',
                              (route) => false,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpandableMenuItem({
    required BuildContext context,
    required AppLocalizations localizations,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(left: 16, right: 8, bottom: 4),
        children: children,
      ),
    );
  }

  Widget _buildSubMenuItem({
    required BuildContext context,
    required AppLocalizations localizations,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -3),
      contentPadding: const EdgeInsets.only(left: 16, right: 12),
      horizontalTitleGap: 8,
      minLeadingWidth: 0,
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildProfileAvatar(UserModel? user) {
    if (user?.profileImage != null) {
      try {
        final imageBytes = base64Decode(user!.profileImage!);
        return CircleAvatar(
          radius: 40,
          backgroundColor: Colors.white,
          backgroundImage: MemoryImage(imageBytes),
        );
      } catch (e) {
        // Erreur de décodage, utiliser l'icône par défaut
      }
    }

    return const CircleAvatar(
      radius: 40,
      backgroundColor: Colors.white,
      child: Icon(
        Icons.person,
        size: 40,
        color: Color(0xFF000B58),
      ),
    );
  }

  Widget _buildNotificationTile(AppLocalizations localizations) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1))
          .map((_) => NotificationService().unreadCount),
      initialData: NotificationService().unreadCount,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return ListTile(
          leading: Stack(
            children: [
              const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            localizations.translate('notifications'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/employee-notifications');
          },
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF35BF8C),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
