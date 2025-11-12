import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/app_localizations.dart';
import '../services/user_service.dart';
import '../data/models/user_model.dart';

class ManagerDrawer extends StatefulWidget {
  const ManagerDrawer({super.key});

  @override
  State<ManagerDrawer> createState() => _ManagerDrawerState();
}

class _ManagerDrawerState extends State<ManagerDrawer> {
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
                          'Espace Manager',
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
                            if (currentRoute == '/manager-menu') {
                              // We are in the overlay; just replace with dashboard
                              Navigator.pushReplacementNamed(
                                  context, '/manager-dashboard');
                            } else {
                              // Close drawer then navigate on next microtask to avoid lock
                              Navigator.pop(context);
                              Future.microtask(() =>
                                  Navigator.pushReplacementNamed(
                                      context, '/manager-dashboard'));
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
                                if (currentRoute == '/manager-menu') {
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
                                if (currentRoute == '/manager-menu') {
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
                                if (currentRoute == '/manager-menu') {
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
                                if (currentRoute == '/manager-menu') {
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
                                if (currentRoute == '/manager-menu') {
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
                                if (currentRoute == '/manager-menu') {
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
                                if (currentRoute == '/manager-menu') {
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
                                if (currentRoute == '/manager-menu') {
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

                        const Divider(color: Colors.white30, thickness: 1),

                        // 4. Gestion des employés (Manager specific)
                        ListTile(
                          leading: const Icon(
                            Icons.people_outline,
                            color: Colors.white,
                          ),
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
                            if (currentRoute == '/manager-menu') {
                              Navigator.pushNamed(
                                  context, '/manager-employees');
                            } else {
                              Navigator.pop(context);
                              Navigator.pushNamed(
                                  context, '/manager-employees');
                            }
                          },
                        ),

                        // 5. Gestion des congés (Manager specific)
                        ListTile(
                          leading: const Icon(
                            Icons.event_available_outlined,
                            color: Colors.white,
                          ),
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
                            if (currentRoute == '/manager-menu') {
                              Navigator.pushNamed(context, '/leave-management');
                            } else {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/leave-management');
                            }
                          },
                        ),

                        // 6. Notifications (Manager)
                        ListTile(
                          leading: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                          ),
                          title: Text(
                            localizations.translate('notifications'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () async {
                            final currentRoute =
                                ModalRoute.of(context)?.settings.name;
                            if (currentRoute == '/manager-menu') {
                              await Navigator.pushNamed(
                                  context, '/manager-notifications');
                            } else {
                              Navigator.pop(context);
                              await Navigator.pushNamed(
                                  context, '/manager-notifications');
                            }
                          },
                        ),

                        const Divider(color: Colors.white30, thickness: 1),

                        // 7. Paie & avantages
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
                                Navigator.pop(context);
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
                                if (currentRoute == '/manager-menu') {
                                  Navigator.pushNamed(
                                      context, '/expense-reports');
                                } else {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(
                                      context, '/expense-reports');
                                }
                              },
                            ),
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('credit_request'),
                              onTap: () {
                                final currentRoute =
                                    ModalRoute.of(context)?.settings.name;
                                if (currentRoute == '/manager-menu') {
                                  Navigator.pushNamed(
                                      context, '/credit-request');
                                } else {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(
                                      context, '/credit-request');
                                }
                              },
                            ),
                          ],
                        ),

                        // Footer - Logout
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Divider(color: Colors.white30),
                              ListTile(
                                leading: const Icon(Icons.logout,
                                    color: Colors.white70),
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildManagerAvatar(UserModel? user) {
    if (user?.profileImage != null && user!.profileImage!.isNotEmpty) {
      try {
        final imageBytes = base64Decode(user.profileImage!);
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.memory(
              imageBytes,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildDefaultAvatar();
              },
            ),
          ),
        );
      } catch (e) {
        print('Manager Avatar - Error decoding image: $e');
      }
    }

    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF000B58), Color(0xFF35BF8C)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 40),
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
