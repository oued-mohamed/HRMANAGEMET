import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/app_localizations.dart';
import '../services/user_service.dart';
import '../data/models/user_model.dart';
import '../services/odoo_service.dart';

class HRDrawer extends StatefulWidget {
  const HRDrawer({super.key});

  @override
  State<HRDrawer> createState() => _HRDrawerState();
}

class _HRDrawerState extends State<HRDrawer> {
  int _unreadNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    // Initialiser le service si nécessaire
    UserService.instance.initialize();
    _loadUnreadNotificationsCount();
  }

  @override
  void didUpdateWidget(HRDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh count when widget updates
    _loadUnreadNotificationsCount();
  }

  Future<void> _loadUnreadNotificationsCount() async {
    try {
      final notifications = await OdooService().getUnreadNotifications();
      final unreadCount =
          notifications.where((n) => n['is_read'] == false).length;

      if (mounted) {
        setState(() {
          _unreadNotificationsCount = unreadCount;
        });
      }
    } catch (e) {
      print('❌ Error loading notifications count: $e');
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = 0;
        });
      }
    }
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
                  // Header with Manager Profile
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
                          child: _buildManagerAvatar(snapshot.data),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Espace RH',
                          style: TextStyle(
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
                            final currentRoute =
                                ModalRoute.of(context)?.settings.name;
                            if (currentRoute == '/hr-menu') {
                              Navigator.pushReplacementNamed(
                                  context, '/hr-dashboard');
                            } else {
                              Navigator.pop(context);
                              Future.microtask(() =>
                                  Navigator.pushReplacementNamed(
                                      context, '/hr-dashboard'));
                            }
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
                                final currentRoute =
                                    ModalRoute.of(context)?.settings.name;
                                if (currentRoute == '/hr-menu') {
                                  Navigator.pushNamed(
                                      context, '/personal-info');
                                } else {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(
                                      context, '/personal-info');
                                }
                              },
                            ),
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title:
                                  localizations.translate('personal_documents'),
                              onTap: () {
                                final currentRoute =
                                    ModalRoute.of(context)?.settings.name;
                                if (currentRoute == '/hr-menu') {
                                  Navigator.pushNamed(
                                      context, '/personal-documents');
                                } else {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(
                                      context, '/personal-documents');
                                }
                              },
                            ),
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title:
                                  localizations.translate('profile_settings'),
                              onTap: () {
                                final currentRoute =
                                    ModalRoute.of(context)?.settings.name;
                                if (currentRoute == '/hr-menu') {
                                  Navigator.pushNamed(
                                      context, '/profile-settings');
                                } else {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(
                                      context, '/profile-settings');
                                }
                              },
                            ),
                          ],
                        ),

                        // 2. Congés
                        _buildExpandableMenuItem(
                          context: context,
                          localizations: localizations,
                          icon: Icons.event_available,
                          title: localizations.translate('leaves'),
                          children: [
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('request_leave'),
                              onTap: () {
                                final currentRoute =
                                    ModalRoute.of(context)?.settings.name;
                                if (currentRoute == '/hr-menu') {
                                  Navigator.pushNamed(
                                      context, '/leave-request');
                                } else {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(
                                      context, '/leave-request');
                                }
                              },
                            ),
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('leave_balance'),
                              onTap: () {
                                final currentRoute =
                                    ModalRoute.of(context)?.settings.name;
                                if (currentRoute == '/hr-menu') {
                                  Navigator.pushNamed(
                                      context, '/leave-balance');
                                } else {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(
                                      context, '/leave-balance');
                                }
                              },
                            ),
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('calendar'),
                              onTap: () {
                                final currentRoute =
                                    ModalRoute.of(context)?.settings.name;
                                if (currentRoute == '/hr-menu') {
                                  Navigator.pushNamed(
                                      context, '/leave-calendar');
                                } else {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(
                                      context, '/leave-calendar');
                                }
                              },
                            ),
                          ],
                        ),

                        // 3. Temps de travail
                        _buildExpandableMenuItem(
                          context: context,
                          localizations: localizations,
                          icon: Icons.access_time,
                          title: localizations.translate('work_time'),
                          children: [
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('punch_in_out'),
                              onTap: () {
                                final currentRoute =
                                    ModalRoute.of(context)?.settings.name;
                                if (currentRoute == '/hr-menu') {
                                  Navigator.pushNamed(context, '/attendance');
                                } else {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(context, '/attendance');
                                }
                              },
                            ),
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('punch_history'),
                              onTap: () {
                                final currentRoute =
                                    ModalRoute.of(context)?.settings.name;
                                if (currentRoute == '/hr-menu') {
                                  Navigator.pushNamed(
                                      context, '/attendance-history');
                                } else {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(
                                      context, '/attendance-history');
                                }
                              },
                            ),
                          ],
                        ),

                        // 4. Gestion des employés (HR specific)
                        ListTile(
                          leading:
                              const Icon(Icons.people, color: Colors.white),
                          title: Text(
                            localizations.translate('employee_management'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            final currentRoute =
                                ModalRoute.of(context)?.settings.name;
                            if (currentRoute == '/hr-menu') {
                              Navigator.pushNamed(context, '/hr-employees');
                            } else {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/hr-employees');
                            }
                          },
                        ),

                        // 5. Gestion des congés (HR specific)
                        ListTile(
                          leading: const Icon(Icons.event_available,
                              color: Colors.white),
                          title: Text(
                            localizations.translate('leave_management'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            final currentRoute =
                                ModalRoute.of(context)?.settings.name;
                            if (currentRoute == '/hr-menu') {
                              Navigator.pushNamed(context, '/leave-management');
                            } else {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/leave-management');
                            }
                          },
                        ),

                        const Divider(color: Colors.white30, thickness: 1),

                        // 6. Paie & avantages
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
                                final currentRoute =
                                    ModalRoute.of(context)?.settings.name;
                                if (currentRoute != '/hr-menu') {
                                  Navigator.pop(context);
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(localizations
                                        .translate('salary_information')),
                                    backgroundColor: const Color(0xFF35BF8C),
                                  ),
                                );
                              },
                            ),
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('my_benefits'),
                              onTap: () {
                                final currentRoute =
                                    ModalRoute.of(context)?.settings.name;
                                if (currentRoute != '/hr-menu') {
                                  Navigator.pop(context);
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        localizations.translate('my_benefits')),
                                    backgroundColor: const Color(0xFF35BF8C),
                                  ),
                                );
                              },
                            ),
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('expense_report'),
                              onTap: () {
                                final currentRoute =
                                    ModalRoute.of(context)?.settings.name;
                                if (currentRoute == '/hr-menu') {
                                  Navigator.pushNamed(
                                      context, '/expense-reports');
                                } else {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(
                                      context, '/expense-reports');
                                }
                              },
                            ),
                          ],
                        ),

                        // 7. Notifications RH
                        ListTile(
                          leading: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                          ),
                          title: Text(
                            localizations.translate('hr_notifications'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: _unreadNotificationsCount > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$_unreadNotificationsCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () async {
                            final currentRoute =
                                ModalRoute.of(context)?.settings.name;
                            if (currentRoute == '/hr-menu') {
                              await Navigator.pushNamed(
                                  context, '/hr-notifications');
                            } else {
                              Navigator.pop(context);
                              await Navigator.pushNamed(
                                  context, '/hr-notifications');
                            }
                            // Refresh count when returning from notifications screen
                            _loadUnreadNotificationsCount();
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

  Widget _buildManagerAvatar(UserModel? user) {
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
        Icons.business_center,
        size: 40,
        color: Color(0xFF000B58),
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
      leading: Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: Icon(
          Icons.circle,
          size: 9,
          color: Colors.white
              .withOpacity(0.6), // Changed from white54 to more visible
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white
              .withOpacity(0.85), // Changed from white70 to better contrast
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      onTap: onTap,
    );
  }
}
