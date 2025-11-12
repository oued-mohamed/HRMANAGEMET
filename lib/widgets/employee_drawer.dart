import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/app_localizations.dart';
import '../services/user_service.dart';
import '../data/models/user_model.dart';
import '../services/notification_service.dart';
import '../services/odoo_service.dart';

class EmployeeDrawer extends StatefulWidget {
  const EmployeeDrawer({super.key});

  @override
  State<EmployeeDrawer> createState() => _EmployeeDrawerState();
}

class _EmployeeDrawerState extends State<EmployeeDrawer> {
  int _uncompletedTasksCount = 0;

  @override
  void initState() {
    super.initState();
    // Initialiser le service si nécessaire
    UserService.instance.initialize();
    _loadUncompletedTasksCount();
  }

  @override
  void didUpdateWidget(EmployeeDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh count when widget updates
    _loadUncompletedTasksCount();
  }

  Future<void> _loadUncompletedTasksCount() async {
    try {
      // Get current employee ID
      final employeeId = await OdooService().getCurrentEmployeeId();

      // Get all tasks (getTasksForEmployee filters some, but we need extra filtering)
      final tasks =
          await OdooService().getTasksForEmployee(employeeId: employeeId);
      print('📊 Total tasks fetched before filtering: ${tasks.length}');

      // Additional filtering: check both stage_id and personal_stage_type_id
      final uncompletedTasks = tasks.where((task) {
        // Helper function to extract stage name
        String getStageName(dynamic stage) {
          if (stage == null || stage == false) return '';
          if (stage is List && stage.length > 1) {
            return stage[1].toString().toLowerCase();
          }
          return stage.toString().toLowerCase();
        }

        // Check personal_stage_type_id first (used for task updates)
        final personalStage = task['personal_stage_type_id'];
        final personalStageName = getStageName(personalStage);

        // Check stage_id as fallback
        final stageId = task['stage_id'];
        final stageName = getStageName(stageId);

        // Determine which stage name to use
        final effectiveStageName =
            personalStageName.isNotEmpty ? personalStageName : stageName;

        // Check if task is completed or cancelled
        final isCompleted = effectiveStageName.contains('done') ||
            effectiveStageName.contains('fait') ||
            effectiveStageName.contains('terminé') ||
            effectiveStageName.contains('completed') ||
            effectiveStageName.contains('cancelled') ||
            effectiveStageName.contains('annulé');

        if (isCompleted) {
          print(
              '⏭️ Excluding completed task: "${task['name']}" (Stage: $effectiveStageName)');
        }

        return !isCompleted;
      }).toList();

      print(
          '📋 Uncompleted tasks count after filtering: ${uncompletedTasks.length}');

      if (mounted) {
        setState(() {
          _uncompletedTasksCount = uncompletedTasks.length;
          print('🎯 Updated drawer badge count to: $_uncompletedTasksCount');
        });
      }
    } catch (e) {
      print('❌ Error loading tasks count: $e');
      if (mounted) {
        setState(() {
          _uncompletedTasksCount = 0;
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
                            final currentRoute =
                                ModalRoute.of(context)?.settings.name;
                            if (currentRoute == '/employee-menu') {
                              Navigator.pushReplacementNamed(
                                  context, '/employee-dashboard');
                            } else {
                              Navigator.pop(context);
                              Future.microtask(() =>
                                  Navigator.pushReplacementNamed(
                                      context, '/employee-dashboard'));
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
                            // 3) Calendrier des congés (last)
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('calendar'),
                              onTap: () {
                                final currentRoute =
                                    ModalRoute.of(context)?.settings.name;
                                if (currentRoute == '/employee-menu') {
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
                          title: localizations.translate('working_time'),
                          children: [
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('working_time'),
                              onTap: () {
                                final currentRoute =
                                    ModalRoute.of(context)?.settings.name;
                                if (currentRoute == '/employee-menu') {
                                  Navigator.pushNamed(
                                      context, '/work-time-statistics');
                                } else {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(
                                      context, '/work-time-statistics');
                                }
                              },
                            ),
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('time_tracking'),
                              onTap: () {
                                final currentRoute =
                                    ModalRoute.of(context)?.settings.name;
                                if (currentRoute == '/employee-menu') {
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
                              title: localizations
                                  .translate('time_tracking_history'),
                              onTap: () {
                                final currentRoute =
                                    ModalRoute.of(context)?.settings.name;
                                if (currentRoute == '/employee-menu') {
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
                                final currentRoute =
                                    ModalRoute.of(context)?.settings.name;
                                if (currentRoute != '/employee-menu') {
                                  Navigator.pop(context);
                                }
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
                                final currentRoute =
                                    ModalRoute.of(context)?.settings.name;
                                if (currentRoute != '/employee-menu') {
                                  Navigator.pop(context);
                                }
                                _showSnackBar(context,
                                    localizations.translate('my_benefits'));
                              },
                            ),
                            _buildSubMenuItem(
                              context: context,
                              localizations: localizations,
                              title: localizations.translate('expense_report'),
                              onTap: () {
                                final currentRoute =
                                    ModalRoute.of(context)?.settings.name;
                                if (currentRoute == '/employee-menu') {
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
                                if (currentRoute == '/employee-menu') {
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

                        // 6. Mes Tâches
                        ListTile(
                          leading: const Icon(
                            Icons.task_alt,
                            color: Colors.white,
                          ),
                          title: Text(
                            'Mes Tâches',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: _uncompletedTasksCount > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$_uncompletedTasksCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () async {
                            Navigator.pop(context);
                            await Navigator.pushNamed(
                                context, '/employee-tasks');
                            // Refresh count when returning from tasks screen
                            _loadUncompletedTasksCount();
                          },
                        ),

                        const Divider(color: Colors.white30, thickness: 1),

                        // 7. Notifications
                        _buildNotificationTile(localizations),
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
      leading: Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: Icon(
          Icons.circle,
          size: 9,
          color: Colors.white.withOpacity(0.6),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.85),
          fontSize: 14,
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
    return ListTile(
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
        Navigator.pop(context);
        await Navigator.pushNamed(context, '/employee-notifications');
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