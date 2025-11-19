import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/odoo_service.dart';
import '../utils/app_localizations.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../data/models/user_model.dart';

class HREmployeeManagementScreen extends StatefulWidget {
  final bool
      showAllEmployees; // Show all employees under management (manager mode)

  const HREmployeeManagementScreen({
    super.key,
    this.showAllEmployees = false, // Default: only direct reports
  });

  @override
  State<HREmployeeManagementScreen> createState() =>
      _HREmployeeManagementScreenState();
}

class _HREmployeeManagementScreenState
    extends State<HREmployeeManagementScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final OdooService _odooService = OdooService();
  List<Map<String, dynamic>> _employees = [];
  Set<int> _directReportIds = {}; // Track IDs of direct reports
  Map<int, double> _weeklyHours = {}; // Store weekly hours for each employee
  bool _isLoading = true;
  String _searchQuery = '';
  DateTime? _cachedWeekStart;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  // Get current week (Monday to Saturday)
  DateTime get _weekStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekday = today.weekday; // 1 = Monday, 7 = Sunday
    return today.subtract(Duration(days: weekday - 1));
  }

  DateTime get _weekEnd {
    final start = _weekStart;
    return start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  }

  // Get weekly hours for a specific employee
  Future<double> _getWeeklyHours(int employeeId, {bool useCache = true}) async {
    try {
      final weekStart = _weekStart;
      final weekEnd = _weekEnd;
      final attendanceRecords = await _odooService.getEmployeeAttendance(
        employeeId,
        useCache: useCache,
        dateFrom: weekStart,
        dateTo: weekEnd,
      );

      double totalHours = 0.0;

      for (var record in attendanceRecords) {
        final checkIn = record['check_in'];
        if (checkIn != null) {
          try {
            final checkInDate = DateTime.parse(checkIn.toString());
            // Check if this record is within the current week (Monday to Saturday)
            if (checkInDate
                    .isAfter(_weekStart.subtract(const Duration(days: 1))) &&
                checkInDate.isBefore(_weekEnd.add(const Duration(days: 1)))) {
              final workedHours = record['worked_hours'];
              if (workedHours != null &&
                  workedHours is double &&
                  workedHours > 0) {
                totalHours += workedHours;
              }
            }
          } catch (e) {
            // Skip invalid dates
          }
        }
      }

      return totalHours;
    } catch (e) {
      print('Error getting weekly hours for employee $employeeId: $e');
      return 0.0;
    }
  }

  void _resetWeeklyHoursIfNeeded() {
    final currentWeekStart = _weekStart;
    if (_cachedWeekStart == null ||
        !_isSameDay(_cachedWeekStart!, currentWeekStart)) {
      _weeklyHours.clear();
      _cachedWeekStart = currentWeekStart;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _prefetchWeeklyHours(List<int> employeeIds,
      {bool forceRefresh = false}) async {
    final idsToFetch = forceRefresh
        ? employeeIds
        : employeeIds.where((id) => !_weeklyHours.containsKey(id)).toList();

    if (idsToFetch.isEmpty) return;

    final results = await Future.wait(
      idsToFetch.map((id) async {
        final hours =
            await _getWeeklyHours(id, useCache: !forceRefresh);
        return MapEntry(id, hours);
      }),
    );

    if (!mounted || results.isEmpty) return;

    setState(() {
      for (final entry in results) {
        _weeklyHours[entry.key] = entry.value;
      }
    });
  }

  Future<void> _loadEmployees({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    if (forceRefresh) {
      _weeklyHours.clear();
    } else {
      _resetWeeklyHoursIfNeeded();
    }
    try {
      // First, get direct reports to track which employees can receive tasks
      final directReports =
          await OdooService().getDirectReports(useCache: !forceRefresh);
      _directReportIds = directReports.map((e) => e['id'] as int).toSet();

      print('📊 Direct reports found: ${directReports.length}');
      print('🔑 Direct report IDs: $_directReportIds');

      List<Map<String, dynamic>> employeesList;

      if (widget.showAllEmployees) {
        // Manager mode: Get all employees under management (direct + indirect)
        final allEmployees = await OdooService()
            .getAllEmployeesUnderManagement(useCache: !forceRefresh);
        print('📊 All employees under management: ${allEmployees.length}');
        employeesList = allEmployees;
      } else {
        // HR mode: Only show direct reports
        print('📊 Showing only direct reports: ${directReports.length}');
        employeesList = directReports;
      }

      if (mounted) {
        setState(() {
          _employees = employeesList;
          _isLoading = false;
          final employeeIds =
              employeesList.map((e) => e['id'] as int).toSet();
          _weeklyHours.removeWhere((key, value) => !employeeIds.contains(key));
        });
      }

      final ids = employeesList.map((e) => e['id'] as int).toList();
      await _prefetchWeeklyHours(ids, forceRefresh: forceRefresh);
    } catch (e) {
      print('Error loading employees: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded,
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
                            widget.showAllEmployees
                                ? '${_employees.length} ${localizations.translate('employees')}'
                                : '${_employees.length} ${localizations.translate('my_direct_reports')}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    StreamBuilder<UserModel?>(
                      stream: UserService.instance.userStream,
                      initialData: UserService.instance.currentUser,
                      builder: (context, snapshot) {
                        return InkWell(
                          onTap: () =>
                              Navigator.pushNamed(context, '/personal-info'),
                          borderRadius: BorderRadius.circular(25),
                          child: Container(
                            width: 50,
                            height: 50,
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
                              child: _buildHeaderProfileAvatar(snapshot.data),
                            ),
                          ),
                        );
                      },
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
                        onRefresh: () => _loadEmployees(forceRefresh: true),
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
                            : SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 20),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final availableWidth = constraints.maxWidth;
                                    final cardWidth = (availableWidth - 16) /
                                        (isTablet ? 3 : 2);

                                    return Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      children:
                                          _filteredEmployees.map((employee) {
                                        return SizedBox(
                                          width: cardWidth,
                                          child: _buildEmployeeCard(
                                              employee, localizations),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                              ),
                      ),
              ),
            ],
          ),
        ),
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

    // Check if this employee is a direct report (can receive tasks)
    final isDirectReport = _directReportIds.contains(employee['id']);
    final isManagerView = widget.showAllEmployees || isDirectReport;

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
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top section with avatar and text
                Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF000B58).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _buildProfileImage(employee),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2d3436),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      jobTitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF000B58).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        department,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF000B58),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Bottom section: Show assign task button for managers, weekly hours for HR
                isManagerView && isDirectReport
                    ? SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _showAssignTaskDialog(employee, localizations),
                          icon: const Icon(Icons.assignment,
                              size: 14, color: Colors.white),
                          label: Text(
                            localizations.translate('assign_task'),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF35BF8C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF000B58).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF000B58).withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Color(0xFF000B58),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      'Cette semaine',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _buildWeeklyHoursWidget(
                                  employee['id'] as int,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyHoursWidget(int employeeId) {
    final hours = _weeklyHours[employeeId];
    if (hours == null) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF000B58)),
        ),
      );
    }

    return Text(
      _formatHours(hours),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Color(0xFF000B58),
      ),
      textAlign: TextAlign.end,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatHours(double hours) {
    if (hours == 0) return '0h';

    final wholeHours = hours.toInt();
    final minutes = ((hours - wholeHours) * 60).round();

    if (minutes == 0) {
      return '${wholeHours}h';
    } else {
      return '${wholeHours}h ${minutes}m';
    }
  }

  Widget _buildProfileImage(Map<String, dynamic> employee) {
    final imageData = employee['image_1920'];

    if (imageData != null && imageData.toString().isNotEmpty) {
      try {
        // If imageData is a base64 string, decode it
        if (imageData.toString().startsWith('/9j/') ||
            imageData.toString().startsWith('iVBORw0KGgo') ||
            imageData.toString().startsWith('data:image')) {
          return Image.memory(
            base64Decode(imageData
                .toString()
                .replaceFirst(RegExp(r'^data:image/[^;]+;base64,'), '')),
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultAvatar();
            },
          );
        }
        // If it's a URL or path, use Image.network
        else if (imageData.toString().startsWith('http')) {
          return Image.network(
            imageData.toString(),
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultAvatar();
            },
          );
        }
      } catch (e) {
        print('Error loading profile image: $e');
      }
    }

    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF000B58), Color(0xFF000B58)],
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 30),
    );
  }

  Widget _buildHeaderProfileAvatar(UserModel? user) {
    if (user?.profileImage != null && user!.profileImage!.isNotEmpty) {
      try {
        final imageBytes = base64Decode(user.profileImage!);
        return Image.memory(
          imageBytes,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildHeaderDefaultAvatar();
          },
        );
      } catch (e) {
        print('Header Avatar - Error decoding image: $e');
      }
    }

    return _buildHeaderDefaultAvatar();
  }

  Widget _buildHeaderDefaultAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF000B58), Color(0xFF35BF8C)],
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 28),
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
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Assignation de la tâche...'),
            ],
          ),
          backgroundColor: Color(0xFF000B58),
        ),
      );

      final success = await OdooService().createTaskAndNotify(
        employeeId: employee['id'],
        title: title,
        description: description,
        priority: priority,
        dueDate: dueDate,
        assignedByName: 'Manager', // TODO: Get actual manager name
      );

      // Add local notification as well for immediate feedback
      NotificationService().addNotification(
        title: title,
        description: description,
        priority: priority,
        dueDate: dueDate,
        assignedByName: 'Manager', // TODO: Get actual manager name
        assignedToName: employee['name']?.toString() ?? 'Unknown',
        type: 'task',
      );

      ScaffoldMessenger.of(context).clearSnackBars();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                    '${localizations.translate('task_assigned_successfully')} - ${employee['name']}'),
              ],
            ),
            backgroundColor: const Color(0xFF35BF8C),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 8),
                Text('Erreur lors de la création de la tâche dans Odoo'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'assignation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
