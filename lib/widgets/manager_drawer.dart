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
                            Navigator.pop(context);
                            Navigator.pushReplacementNamed(
                                context, '/manager-dashboard');
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
                              title:
                                  localizations.translate('profile_settings'),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(
                                    context, '/profile-settings');
                              },
                            ),
                          ],
                        ),

                        const Divider(color: Colors.white30, thickness: 1),

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
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/leave-request');
                              },
                            ),
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('leave_balance'),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/leave-balance');
                              },
                            ),
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title:
                                  localizations.translate('unexpected_absence'),
                              onTap: () {
                                Navigator.pop(context);
                                _showSnackBar(
                                    context,
                                    localizations
                                        .translate('unexpected_absence'));
                              },
                            ),
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

                        const Divider(color: Colors.white30, thickness: 1),

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
                                Navigator.pop(context);
                                _showSnackBar(context,
                                    localizations.translate('punch_in_out'));
                              },
                            ),
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('punch_history'),
                              onTap: () {
                                Navigator.pop(context);
                                _showSnackBar(context,
                                    localizations.translate('punch_history'));
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
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/manager-employees');
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
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/leave-management');
                          },
                        ),

                        const Divider(color: Colors.white30, thickness: 1),

                        // Déconnexion
                        ListTile(
                          leading: const Icon(
                            Icons.logout,
                            color: Colors.red,
                          ),
                          title: Text(
                            localizations.translate('logout'),
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushReplacementNamed(context, '/login');
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
