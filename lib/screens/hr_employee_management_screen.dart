import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/odoo_service.dart';
import '../utils/app_localizations.dart';
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

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  // Get current week (Monday to Saturday)
  DateTime get _weekStart {
    final now = DateTime.now();
    final weekday = now.weekday; // 1 = Monday, 7 = Sunday
    // Go back to Monday
    return now.subtract(Duration(days: weekday - 1));
  }

  DateTime get _weekEnd {
    final now = DateTime.now();
    final weekday = now.weekday;
    // Go forward to Saturday (add 5 days from Monday)
    return now.add(Duration(days: 7 - weekday));
  }

  // Get weekly hours for a specific employee
  Future<double> _getWeeklyHours(int employeeId) async {
    try {
      final attendanceRecords =
          await _odooService.getEmployeeAttendance(employeeId);

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

  Future<void> _loadEmployees() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // First, get direct reports to track which employees can receive tasks
      final directReports = await OdooService().getDirectReports();
      _directReportIds = directReports.map((e) => e['id'] as int).toSet();

      print('📊 Direct reports found: ${directReports.length}');
      print('🔑 Direct report IDs: $_directReportIds');

      List<Map<String, dynamic>> employeesList;

      if (widget.showAllEmployees) {
        // Manager mode: Get all employees under management (direct + indirect)
        final allEmployees =
            await OdooService().getAllEmployeesUnderManagement();
        print('📊 All employees under management: ${allEmployees.length}');
        employeesList = allEmployees;
      } else {
        // HR mode: Only show direct reports
        print('📊 Showing only direct reports: ${directReports.length}');
        employeesList = directReports;
      }

      // Load weekly hours for each employee
      final Map<int, double> weeklyHours = {};
      for (var emp in employeesList) {
        final empId = emp['id'] as int;
        final hours = await _getWeeklyHours(empId);
        weeklyHours[empId] = hours;
      }

      if (mounted) {
        setState(() {
          _employees = employeesList;
          _weeklyHours = weeklyHours;
          _isLoading = false;
        });
      }
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
                            : SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(20, 0, 20,
                                    100), // Extra bottom padding for FAB
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
                // Bottom section with weekly hours
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                        child: Text(
                          _formatHours(
                              _weeklyHours[employee['id'] as int] ?? 0.0),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF000B58),
                          ),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
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
