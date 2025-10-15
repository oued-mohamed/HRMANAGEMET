import 'package:flutter/material.dart';
import '../services/odoo_service.dart';
import '../utils/app_localizations.dart';
import '../widgets/hr_drawer.dart';

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
      // Fetch all employees under Mitchell's management hierarchy (CEO view)
      final employees = await OdooService().getAllEmployeesUnderManagement();
      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading all employees under management: $e');
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
                            '${_employees.length} Employé(s)',
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
                                  childAspectRatio: 0.75,
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
              ],
            ),
          ),
        ),
      ),
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
