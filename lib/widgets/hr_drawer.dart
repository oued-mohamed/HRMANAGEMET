import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/app_localizations.dart';
import '../services/user_service.dart';
import '../data/models/user_model.dart';

class HRDrawer extends StatefulWidget {
  const HRDrawer({super.key});

  @override
  State<HRDrawer> createState() => _HRDrawerState();
}

class _HRDrawerState extends State<HRDrawer> {
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
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/hr-employees');
                          },
                        ),

                        // Demander un congé
                        ListTile(
                          leading: const Icon(Icons.add_circle_outline,
                              color: Colors.white),
                          title: Text(
                            localizations.translate('request_leave'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/leave-request');
                          },
                        ),

                        // Gestion des congés
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
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/leave-management');
                          },
                        ),

                        // Présence & temps
                        ListTile(
                          leading: const Icon(Icons.access_time,
                              color: Colors.white),
                          title: Text(
                            localizations.translate('attendance_time'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _showSnackBar(context,
                                localizations.translate('attendance_time'));
                          },
                        ),

                        // Paie
                        ListTile(
                          leading: const Icon(Icons.account_balance_wallet,
                              color: Colors.white),
                          title: Text(
                            localizations.translate('payroll'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _showSnackBar(
                                context, localizations.translate('payroll'));
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
