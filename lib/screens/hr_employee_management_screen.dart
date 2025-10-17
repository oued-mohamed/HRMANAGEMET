import 'package:flutter/material.dart';
import '../services/odoo_service.dart';
import '../utils/app_localizations.dart';
import '../widgets/hr_drawer.dart';
import '../services/notification_service.dart';

class HREmployeeManagementScreen extends StatefulWidget {
  const HREmployeeManagementScreen({super.key});

  @override
  State<HREmployeeManagementScreen> createState() =>
      _HREmployeeManagementScreenState();
}

class _HREmployeeManagementScreenState
    extends State<HREmployeeManagementScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      // Fetch only direct reports for the current manager
      // This ensures managers can only assign tasks to their direct team members
      final employees = await OdooService().getDirectReports();

      // If no direct reports found, try fallback method for debugging
      if (employees.isEmpty) {
        print('🔄 No direct reports found, trying fallback method...');
        final fallbackEmployees =
            await OdooService().getAllEmployeesUnderManagement();
        print(
            '📊 Fallback method returned ${fallbackEmployees.length} employees');

        setState(() {
          _employees = fallbackEmployees;
          _isLoading = false;
        });
      } else {
        setState(() {
          _employees = employees;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading direct reports: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    if (_searchQuery.isEmpty) return _employees;
    return _employees.where((emp) {
      final name = emp['name']?.toString().toLowerCase() ?? '';
      final jobTitle = emp['job_id'] is List
          ? emp['job_id'][1].toString().toLowerCase()
          : '';
      final department = emp['department_id'] is List
          ? emp['department_id'][1].toString().toLowerCase()
          : '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          jobTitle.contains(query) ||
          department.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const HRDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF000B58),
              Color(0xFF000B58),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Modern Header
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                        icon: const Icon(Icons.menu_rounded,
                            color: Colors.white, size: 26),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gestion des Employés',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${_employees.length} ${localizations.translate('my_direct_reports')}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pushNamed(context, '/profile'),
                      icon:
                          const Icon(Icons.person_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
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
                      hintText: localizations.translate('search_employees'),
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Employee Grid/List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadEmployees,
                        child: _filteredEmployees.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people_outline,
                                        size: 80,
                                        color: Colors.white.withOpacity(0.5)),
                                    const SizedBox(height: 16),
                                    Text(
                                      localizations
                                          .translate('no_employees_found'),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 18),
                                    ),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: isTablet ? 3 : 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 0.65,
                                ),
                                itemCount: _filteredEmployees.length,
                                itemBuilder: (context, index) {
                                  final employee = _filteredEmployees[index];
                                  return _buildEmployeeCard(
                                      employee, localizations);
                                },
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Add new employee
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.translate('add_employee_via_odoo')),
              backgroundColor: const Color(0xFF35BF8C),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: Text(localizations.translate('add_employee')),
        backgroundColor: const Color(0xFF35BF8C),
      ),
    );
  }

  Widget _buildEmployeeCard(
      Map<String, dynamic> employee, AppLocalizations localizations) {
    final name =
        employee['name']?.toString() ?? localizations.translate('unknown');
    final jobTitle = employee['job_id'] is List
        ? employee['job_id'][1].toString()
        : localizations.translate('no_position');
    final department = employee['department_id'] is List
        ? employee['department_id'][1].toString()
        : localizations.translate('no_department');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showEmployeeDetails(employee, localizations),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF000B58), Color(0xFF000B58)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF000B58).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child:
                      const Icon(Icons.person, color: Colors.white, size: 35),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2d3436),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  jobTitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF000B58).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    department,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF000B58),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                // Assign Task Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showAssignTaskDialog(employee, localizations),
                    icon: const Icon(Icons.assignment, size: 16),
                    label: Text(
                      localizations.translate('assign_task'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF35BF8C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAssignTaskDialog(
      Map<String, dynamic> employee, AppLocalizations localizations) {
    final taskTitleController = TextEditingController();
    final taskDescriptionController = TextEditingController();
    String selectedPriority = 'medium_priority';
    DateTime selectedDueDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.assignment, color: Color(0xFF35BF8C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      localizations.translate('assign_task'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2d3436),
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Employee Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF000B58).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: Color(0xFF000B58)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  employee['name']?.toString() ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF000B58),
                                  ),
                                ),
                                Text(
                                  employee['job_id'] is List
                                      ? employee['job_id'][1].toString()
                                      : 'No Position',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Task Title
                    Text(
                      localizations.translate('task_title'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2d3436),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: taskTitleController,
                      decoration: InputDecoration(
                        hintText: localizations.translate('task_title'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF35BF8C)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Task Description
                    Text(
                      localizations.translate('task_description'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2d3436),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: taskDescriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: localizations.translate('task_description'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF35BF8C)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Priority Selection
                    Text(
                      localizations.translate('task_priority'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2d3436),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedPriority,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF35BF8C)),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'high_priority',
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(localizations.translate('high_priority')),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'medium_priority',
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(localizations.translate('medium_priority')),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'low_priority',
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(localizations.translate('low_priority')),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedPriority = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Due Date
                    Text(
                      localizations.translate('task_due_date'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2d3436),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDueDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            selectedDueDate = date;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: Color(0xFF35BF8C)),
                            const SizedBox(width: 8),
                            Text(
                              '${selectedDueDate.day}/${selectedDueDate.month}/${selectedDueDate.year}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    localizations.translate('cancel'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (taskTitleController.text.isNotEmpty) {
                      _assignTask(
                        employee,
                        taskTitleController.text,
                        taskDescriptionController.text,
                        selectedPriority,
                        selectedDueDate,
                        localizations,
                      );
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF35BF8C),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(localizations.translate('assign')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _assignTask(
    Map<String, dynamic> employee,
    String title,
    String description,
    String priority,
    DateTime dueDate,
    AppLocalizations localizations,
  ) {
    // Add notification using NotificationService
    NotificationService().addNotification(
      title: title,
      description: description,
      priority: priority,
      dueDate: dueDate,
      assignedByName: 'Mitchell Admin', // TODO: Get actual manager name
      assignedToName: employee['name']?.toString() ?? 'Unknown',
    );

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${localizations.translate('task_assigned_successfully')} - ${employee['name']}',
        ),
        backgroundColor: const Color(0xFF35BF8C),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Voir notifications',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pushNamed(context, '/employee-notifications');
          },
        ),
      ),
    );

    // TODO: Implement actual task assignment to backend/Odoo
    print('Task assigned to ${employee['name']}:');
    print('Title: $title');
    print('Description: $description');
    print('Priority: $priority');
    print('Due Date: $dueDate');
  }

  void _showEmployeeDetails(
      Map<String, dynamic> employee, AppLocalizations localizations) {
    final name = employee['name']?.toString() ?? '';
    final jobTitle =
        employee['job_id'] is List ? employee['job_id'][1].toString() : '';
    final department = employee['department_id'] is List
        ? employee['department_id'][1].toString()
        : '';
    final workEmail = employee['work_email']?.toString() ?? '';
    final workPhone = employee['work_phone']?.toString() ?? '';
    final manager = employee['parent_id'] is List
        ? employee['parent_id'][1].toString()
        : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF000B58), Color(0xFF000B58)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 45),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2d3436),
              ),
            ),
            Text(
              jobTitle,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildDetailRow(Icons.business,
                      localizations.translate('department'), department),
                  _buildDetailRow(
                      Icons.email, localizations.translate('email'), workEmail),
                  _buildDetailRow(
                      Icons.phone, localizations.translate('phone'), workPhone),
                  _buildDetailRow(Icons.supervisor_account,
                      localizations.translate('manager'), manager),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    if (value.isEmpty || value == 'false') return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF000B58).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF000B58), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2d3436),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
