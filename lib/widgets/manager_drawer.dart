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

                        // Gestion des employés
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
                            Navigator.pushNamed(context, '/hr-employees');
                          },
                        ),

                        // Gestion des congés
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

                        // Mon profil
                        ListTile(
                          leading: const Icon(
                            Icons.person_outline,
                            color: Colors.white,
                          ),
                          title: Text(
                            localizations.translate('my_profile'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/personal-info');
                          },
                        ),

                        // Paramètres
                        ListTile(
                          leading: const Icon(
                            Icons.settings_outlined,
                            color: Colors.white,
                          ),
                          title: Text(
                            localizations.translate('settings'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/profile-settings');
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
}
