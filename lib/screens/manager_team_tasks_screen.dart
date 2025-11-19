import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/odoo_service.dart';
import '../utils/app_localizations.dart';

class ManagerTeamTasksScreen extends StatefulWidget {
  const ManagerTeamTasksScreen({super.key});

  @override
  State<ManagerTeamTasksScreen> createState() => _ManagerTeamTasksScreenState();
}

class _ManagerTeamTasksScreenState extends State<ManagerTeamTasksScreen> {
  bool _isLoading = true;
  String _searchQuery = '';
  final Map<int, List<Map<String, dynamic>>> _tasksByEmployee = {};
  List<Map<String, dynamic>> _directReports = [];
  final Set<int> _expandedEmployees =
      {}; // Track which employee cards are expanded

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) return;

    if (!forceRefresh) {
      setState(() => _isLoading = true);
    }

    try {
      final reports = await OdooService().getDirectReports(
        useCache: !forceRefresh,
      );

      final employeeIds =
          reports.map((report) => report['id']).whereType<int>().toList();

      final Map<int, List<Map<String, dynamic>>> groupedTasks = {
        for (final id in employeeIds) id: [],
      };

      if (employeeIds.isNotEmpty) {
        final taskResults = await Future.wait(
          employeeIds.map((employeeId) async {
            try {
              final tasks = await OdooService()
                  .getTasksForEmployee(employeeId: employeeId);
              return MapEntry(employeeId, tasks);
            } catch (e) {
              print('Error loading tasks for employee $employeeId: $e');
              return MapEntry(employeeId, <Map<String, dynamic>>[]);
            }
          }),
        );

        for (final entry in taskResults) {
          groupedTasks[entry.key] = entry.value;
        }
      }

      if (!mounted) return;
      setState(() {
        _directReports = reports;
        _tasksByEmployee
          ..clear()
          ..addAll(groupedTasks);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des tâches: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    if (_searchQuery.isEmpty) return _directReports;
    final query = _searchQuery.toLowerCase();
    return _directReports.where((employee) {
      final name = employee['name']?.toString().toLowerCase() ?? '';
      final jobTitle = employee['job_id'] is List
          ? employee['job_id'][1].toString().toLowerCase()
          : '';
      final tasks = _tasksByEmployee[employee['id']] ?? [];
      final hasTaskMatch = tasks.any((task) =>
          (task['name']?.toString().toLowerCase() ?? '').contains(query));
      return name.contains(query) || jobTitle.contains(query) || hasTaskMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tâches de mon équipe',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF000B58),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF000B58),
              Color(0xFF35BF8C),
            ],
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : RefreshIndicator(
                onRefresh: () => _loadData(forceRefresh: true),
                color: const Color(0xFF000B58),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildSearchBar(localizations),
                    const SizedBox(height: 20),
                    if (_filteredEmployees.isEmpty)
                      _buildEmptyState(localizations)
                    else
                      ..._filteredEmployees
                          .map((employee) => _buildEmployeeTaskCard(
                                employee,
                                localizations,
                              ))
                          .toList(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations localizations) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Rechercher un employé ou une tâche...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations localizations) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.task_outlined,
              size: 72, color: Colors.white.withOpacity(0.7)),
          const SizedBox(height: 16),
          Text(
            'Aucune tâche à afficher',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Assignez des tâches à vos collaborateurs pour les voir ici.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeTaskCard(
      Map<String, dynamic> employee, AppLocalizations localizations) {
    final tasks = _tasksByEmployee[employee['id']] ?? [];
    final employeeId = employee['id'] as int;
    final isExpanded = _expandedEmployees.contains(employeeId);
    final employeeName = employee['name']?.toString() ?? 'Employé';
    final jobTitle = employee['job_id'] is List
        ? employee['job_id'][1].toString()
        : localizations.translate('no_position');
    final department = employee['department_id'] is List
        ? employee['department_id'][1].toString()
        : localizations.translate('no_department');

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedEmployees.remove(employeeId);
                } else {
                  _expandedEmployees.add(employeeId);
                }
              });
            },
            child: Row(
              children: [
                _buildEmployeeAvatar(employee),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employeeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        jobTitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      Text(
                        department,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildTaskCountBadge(tasks.length),
                const SizedBox(width: 8),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white,
                  size: 28,
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 16),
            if (tasks.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(
                  'Aucune tâche assignée',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              )
            else
              Column(
                children: tasks
                    .map((task) => _buildTaskItem(task, localizations))
                    .toList(),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskCountBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(
        '$count tâche${count > 1 ? 's' : ''}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task, AppLocalizations locals) {
    final taskName = task['name']?.toString() ?? 'Tâche sans titre';
    final description = task['description']?.toString();
    final dueDate = task['date_deadline']?.toString();

    // Debug: Print raw task data to see what we're receiving (only for first few tasks to avoid spam)
    if (task['name']?.toString().contains('lsjnkx') == true ||
        task['name']?.toString().contains('sawb') == true ||
        task['name']?.toString().contains('othm') == true) {
      print('📋 Task "$taskName" raw data:');
      print('   stage_id: ${task['stage_id']}');
      print('   personal_stage_id: ${task['personal_stage_id']}');
      print('   personal_stage_type_id: ${task['personal_stage_type_id']}');
    }

    final stage = _getTaskStageName(task);
    final priority = task['priority'];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  taskName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF000B58),
                  ),
                ),
              ),
              _buildPriorityChip(priority),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _stripHtmlTags(description),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF4F4F4F),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today,
                  size: 16, color: Colors.grey.withOpacity(0.8)),
              const SizedBox(width: 6),
              Text(
                dueDate != null
                    ? 'Échéance: ${_formatDate(dueDate)}'
                    : 'Pas de date limite',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              _buildStatusChip(stage),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(dynamic priority) {
    final priorityValue = priority?.toString() ?? '0';
    Color chipColor;
    String label;

    switch (priorityValue) {
      case '2':
      case '3':
      case 'High':
        chipColor = Colors.redAccent;
        label = 'Haute';
        break;
      case '1':
      case 'Normal':
        chipColor = Colors.orangeAccent;
        label = 'Moyenne';
        break;
      default:
        chipColor = Colors.green;
        label = 'Basse';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: chipColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String stage) {
    // Handle empty or "Non défini" stage
    if (stage.isEmpty || stage == 'Non défini') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Non défini',
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    }

    final lowerStage = stage.toLowerCase();
    Color bgColor = const Color(0xFF000B58);
    String displayStage = stage;

    // Check for completed/done status
    if (lowerStage.contains('fait') ||
        lowerStage.contains('done') ||
        lowerStage.contains('terminé') ||
        lowerStage.contains('terminée') ||
        lowerStage.contains('complété') ||
        lowerStage.contains('complétée')) {
      bgColor = const Color(0xFF35BF8C);
    }
    // Check for in progress status
    else if (lowerStage.contains('en cours') ||
        lowerStage.contains('in progress') ||
        lowerStage.contains('progress')) {
      bgColor = Colors.blue;
    }
    // Check for waiting/pending status
    else if (lowerStage.contains('en attente') ||
        lowerStage.contains('waiting') ||
        lowerStage.contains('pending') ||
        lowerStage.contains('à faire') ||
        lowerStage.contains('to do')) {
      bgColor = Colors.orangeAccent;
    }
    // Check for new status
    else if (lowerStage.contains('nouveau') ||
        lowerStage.contains('new') ||
        lowerStage.contains('nouvelle')) {
      bgColor = Colors.purple;
    }
    // Default: in progress/active
    else {
      bgColor = const Color(0xFF000B58);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayStage,
        style: TextStyle(
          color: bgColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildEmployeeAvatar(Map<String, dynamic> employee) {
    final imageData = employee['image_1920'];
    if (imageData != null && imageData.toString().isNotEmpty) {
      try {
        final bytes = base64Decode(
          imageData
              .toString()
              .replaceFirst(RegExp(r'^data:image/[^;]+;base64,'), ''),
        );
        return CircleAvatar(
          radius: 28,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }

    return const CircleAvatar(
      radius: 28,
      backgroundColor: Colors.white24,
      child: Icon(Icons.person, color: Colors.white),
    );
  }

  String _getTaskStageName(Map<String, dynamic> task) {
    // Use EXACTLY the same logic as employee screen - copy-paste from employee_tasks_screen.dart
    final personalStage = task['personal_stage_type_id'];
    final stageId = task['stage_id'];

    String _getStageName(dynamic stage) {
      if (stage == null || stage == false) return 'Non défini';
      if (stage is List && stage.isNotEmpty) {
        return stage[1].toString(); // Stage name is usually the second element
      }
      if (stage is bool && !stage) return 'Non défini';
      return stage.toString();
    }

    String? stageName;

    // Try personal_stage_type_id first (EXACTLY like employee screen)
    if (personalStage != null && personalStage != false) {
      stageName = _getStageName(personalStage);
      if (stageName != 'Non défini') {
        return _normalizeStageName(stageName);
      }
    }

    // Fallback to stage_id (EXACTLY like employee screen)
    if (stageId != null && stageId != false) {
      stageName = _getStageName(stageId);
      if (stageName != 'Non défini') {
        return _normalizeStageName(stageName);
      }
    }

    return 'Non défini';
  }

  // Normalize stage name: replace system stages with user-friendly names
  String _normalizeStageName(String stageName) {
    final lowerStageName = stageName.toLowerCase();

    // Replace "Boîte de réception" / "Inbox" with "À faire" (To Do)
    if (lowerStageName.contains('boîte de réception') ||
        lowerStageName.contains('boite de reception') ||
        lowerStageName.contains('inbox')) {
      return 'À faire';
    }

    // Return original stage name if no replacement needed
    return stageName;
  }

  String _stripHtmlTags(String htmlString) {
    final regex = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);
    return htmlString.replaceAll(regex, '');
  }

  String _formatDate(String date) {
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {
      return date;
    }
  }
}
