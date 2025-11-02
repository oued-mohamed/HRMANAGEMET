import 'package:flutter/material.dart';
import '../utils/navigation_helpers.dart';
import '../services/odoo_service.dart';
import '../data/models/employee_model.dart';

class EmployeeTasksScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeTasksScreen({
    Key? key,
    required this.employee,
  }) : super(key: key);

  @override
  State<EmployeeTasksScreen> createState() => _EmployeeTasksScreenState();
}

class _EmployeeTasksScreenState extends State<EmployeeTasksScreen> {
  final OdooService _odooService = OdooService();
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _availableStages = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Load both tasks and available stages
      final results = await Future.wait([
        _odooService.getTasksForEmployee(employeeId: widget.employee.id),
        _odooService.getAvailableTaskStages(),
      ]);

      setState(() {
        _tasks = results[0];
        _availableStages = results[1];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des tâches: $e';
        _isLoading = false;
      });
    }
  }

  // Helper function to strip HTML tags from text
  String _stripHtmlTags(String htmlString) {
    if (htmlString.isEmpty) return '';

    // Remove HTML tags using regex
    RegExp htmlTagRegex = RegExp(r'<[^>]*>');
    String stripped = htmlString.replaceAll(htmlTagRegex, '');

    // Clean up extra whitespace and newlines
    stripped = stripped.replaceAll(RegExp(r'\s+'), ' ').trim();

    return stripped;
  }

  Future<void> _updateTaskStatus(int taskId, String newStatus) async {
    try {
      print('Updating task $taskId with status: $newStatus');
      final success = await _odooService.updateTaskStage(
        taskId: taskId,
        newStage: newStatus,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statut de la tâche mis à jour'),
            backgroundColor: Colors.green,
          ),
        );
        // Reload tasks without cache to get fresh data
        await Future.delayed(Duration(
            milliseconds: 500)); // Small delay to ensure Odoo has updated
        _loadTasks(); // Reload tasks
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Erreur: Le statut "$newStatus" n\'a pas été trouvé ou la mise à jour a échoué'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('Error updating task status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getPriorityText(dynamic priority) {
    if (priority == null) return 'Normal';
    final priorityStr = priority.toString();
    switch (priorityStr) {
      case '1':
        return 'Haute';
      case '0':
        return 'Normal';
      case '-1':
        return 'Basse';
      default:
        return 'Normal';
    }
  }

  Color _getPriorityColor(dynamic priority) {
    if (priority == null) return Colors.blue;
    final priorityStr = priority.toString();
    switch (priorityStr) {
      case '1':
        return Colors.red;
      case '0':
        return Colors.blue;
      case '-1':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Non définie';
    try {
      final dateStr = date.toString();
      if (dateStr.contains('T')) {
        final dateTime = DateTime.parse(dateStr);
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
      return dateStr;
    } catch (e) {
      return 'Format invalide';
    }
  }

  String _getStageName(dynamic stage) {
    if (stage == null || stage == false) return 'Non défini';
    if (stage is List && stage.isNotEmpty) {
      return stage[1].toString(); // Stage name is usually the second element
    }
    if (stage is bool && !stage) return 'Non défini';
    return stage.toString();
  }

  // Get stage name from task, with fallback to stage_id if personal_stage_type_id is invalid
  String _getTaskStageName(Map<String, dynamic> task) {
    final personalStage = task['personal_stage_type_id'];
    final stageId = task['stage_id'];

    // Try personal_stage_type_id first
    if (personalStage != null && personalStage != false) {
      final stageName = _getStageName(personalStage);
      if (stageName != 'Non défini') {
        return stageName;
      }
    }

    // Fallback to stage_id
    if (stageId != null && stageId != false) {
      final stageName = _getStageName(stageId);
      if (stageName != 'Non défini') {
        return stageName;
      }
    }

    return 'Non défini';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavigationHelpers.backToMenu(context),
        ),
        title: Text(
          'Mes Tâches',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFF2E7D32),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTasks,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Chargement des tâches...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: TextStyle(
                          color: Colors.red[600],
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadTasks,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.task_alt,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Aucune tâche assignée',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Vous n\'avez pas encore de tâches assignées',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadTasks,
                      color: Color(0xFF2E7D32),
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _tasks.length,
                        itemBuilder: (context, index) {
                          final task = _tasks[index];
                          return Card(
                            margin: EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Task title and priority
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          task['name'] ?? 'Tâche sans titre',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getPriorityColor(
                                                  task['priority'])
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _getPriorityColor(
                                                    task['priority'])
                                                .withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          _getPriorityText(task['priority']),
                                          style: TextStyle(
                                            color: _getPriorityColor(
                                                task['priority']),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),

                                  // Task description
                                  if (task['description'] != null &&
                                      task['description'].toString().isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        _stripHtmlTags(
                                            task['description'].toString()),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),

                                  // Task details
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: Colors.grey[500],
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Échéance: ${_formatDate(task['date_deadline'])}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.flag,
                                        size: 16,
                                        color: Colors.grey[500],
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Statut: ${_getTaskStageName(task)}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),

                                  // Action buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              _showTaskDetails(task),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(
                                                color: Color(0xFF2E7D32)),
                                            foregroundColor: Color(0xFF2E7D32),
                                          ),
                                          child: Text('Détails'),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _showStatusUpdateDialog(task),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(0xFF2E7D32),
                                            foregroundColor: Colors.white,
                                          ),
                                          child: Text('Mettre à jour'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  void _showTaskDetails(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task['name'] ?? 'Détails de la tâche'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (task['description'] != null &&
                  task['description'].toString().isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    _stripHtmlTags(task['description'].toString()),
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              _buildDetailRow('Priorité', _getPriorityText(task['priority'])),
              _buildDetailRow('Échéance', _formatDate(task['date_deadline'])),
              _buildDetailRow('Statut', _getTaskStageName(task)),
              _buildDetailRow('Créée le', _formatDate(task['create_date'])),
              if (task['write_date'] != null)
                _buildDetailRow('Modifiée le', _formatDate(task['write_date'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  void _showStatusUpdateDialog(Map<String, dynamic> task) {
    // Filter stages to show only "In Progress" and "Done"
    final filteredStages = _availableStages.where((stage) {
      final stageName = stage['name'].toString().toLowerCase();
      return stageName.contains('in progress') ||
          stageName.contains('done') ||
          stageName.contains('en cours') ||
          stageName.contains('terminé');
    }).toList();

    String? selectedStage =
        filteredStages.isNotEmpty ? filteredStages[0]['name'] : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Mettre à jour le statut'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tâche: ${task['name']}'),
              SizedBox(height: 16),
              Text('Nouveau statut:'),
              SizedBox(height: 8),
              if (_availableStages.isEmpty)
                Text('Chargement des statuts...',
                    style: TextStyle(color: Colors.grey))
              else if (filteredStages.isEmpty)
                Text('Aucun statut disponible',
                    style: TextStyle(color: Colors.grey))
              else
                DropdownButtonFormField<String>(
                  value: selectedStage,
                  items: filteredStages.map((stage) {
                    return DropdownMenuItem<String>(
                      value: stage['name'],
                      child: Text(stage['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedStage = value;
                    });
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: selectedStage != null
                  ? () {
                      Navigator.pop(context);
                      _updateTaskStatus(task['id'], selectedStage!);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              child: Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }
}
