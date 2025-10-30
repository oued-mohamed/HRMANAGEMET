import 'package:flutter/material.dart';
import '../services/odoo_service.dart';
import 'package:intl/intl.dart';
import '../utils/navigation_helpers.dart';

class LeaveManagementScreen extends StatefulWidget {
  const LeaveManagementScreen({super.key});

  @override
  State<LeaveManagementScreen> createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen> {
  List<Map<String, dynamic>> _allLeaves = [];
  List<Map<String, dynamic>> _filteredLeaves = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  bool _initialArgsApplied = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLeaveData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialArgsApplied) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['initialFilter'] is String) {
      _selectedFilter = args['initialFilter'];
      _filterLeaves();
    }
    _initialArgsApplied = true;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaveData() async {
    try {
      setState(() => _isLoading = true);

      // Get all leave requests
      final leaves = await OdooService().getAllLeaveRequests();

      setState(() {
        _allLeaves = leaves;
        _filteredLeaves = leaves;
        _isLoading = false;
      });

      print('📊 Loaded ${leaves.length} leave requests');
    } catch (e) {
      print('❌ Error loading leave data: $e');
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des données: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _filterLeaves() {
    setState(() {
      _filteredLeaves = _allLeaves.where((leave) {
        // Apply status filter
        bool statusMatch = true;
        if (_selectedFilter == 'pending') {
          statusMatch = leave['state'] == 'confirm';
        } else if (_selectedFilter == 'approved') {
          statusMatch = leave['state'] == 'validate';
        } else if (_selectedFilter == 'refused') {
          statusMatch = leave['state'] == 'refuse';
        }

        // Apply search filter
        bool searchMatch = true;
        if (_searchQuery.isNotEmpty) {
          final employeeName = leave['employee_id'] is List
              ? leave['employee_id'][1]
              : leave['employee_id'].toString();
          final leaveType = leave['holiday_status_id'] is List
              ? leave['holiday_status_id'][1]
              : leave['holiday_status_id'].toString();

          searchMatch =
              employeeName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  leaveType.toLowerCase().contains(_searchQuery.toLowerCase());
        }

        return statusMatch && searchMatch;
      }).toList();
    });
  }

  Future<void> _approveLeave(int leaveId) async {
    try {
      final success = await OdooService().approveLeaveRequest(leaveId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Congé approuvé avec succès'),
            backgroundColor: Color(0xFF35BF8C),
          ),
        );
        _loadLeaveData(); // Refresh data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'approbation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refuseLeave(int leaveId) async {
    try {
      final success = await OdooService().refuseLeaveRequest(leaveId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Congé refusé avec succès'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadLeaveData(); // Refresh data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du refus'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getStatusText(String state) {
    switch (state) {
      case 'confirm':
        return 'En attente';
      case 'validate':
        return 'Approuvé';
      case 'refuse':
        return 'Refusé';
      case 'draft':
        return 'Brouillon';
      default:
        return state;
    }
  }

  Color _getStatusColor(String state) {
    switch (state) {
      case 'confirm':
        return Colors.orange;
      case 'validate':
        return const Color(0xFF35BF8C);
      case 'refuse':
        return Colors.red;
      case 'draft':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDateRange(dynamic dateFrom, dynamic dateTo) {
    try {
      String fromStr = dateFrom.toString().split(' ')[0];
      String toStr = dateTo.toString().split(' ')[0];

      DateTime from = DateTime.parse(fromStr);
      DateTime to = DateTime.parse(toStr);

      return '${DateFormat('dd/MM/yyyy').format(from)} - ${DateFormat('dd/MM/yyyy').format(to)}';
    } catch (e) {
      return 'Date invalide';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              NavigationHelpers.backToMenu(context);
            }
          },
        ),
        title: const Text('Gestion des congés'),
        backgroundColor: const Color(0xFF000B58),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLeaveData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher par employé ou type de congé...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _filterLeaves();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    _filterLeaves();
                  },
                ),
                const SizedBox(height: 12),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Tous', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('En attente', 'pending'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Approuvés', 'approved'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Refusés', 'refused'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Results Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredLeaves.length} congé(s) trouvé(s)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // Leave List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLeaves.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredLeaves.length,
                        itemBuilder: (context, index) {
                          final leave = _filteredLeaves[index];
                          return _buildLeaveCard(leave);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedFilter = value);
        _filterLeaves();
      },
      selectedColor: const Color(0xFF000B58).withOpacity(0.2),
      checkmarkColor: const Color(0xFF000B58),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF000B58) : Colors.grey[300]!,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun congé trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aucun congé ne correspond à vos critères de recherche',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave) {
    final employeeName = leave['employee_id'] is List
        ? leave['employee_id'][1]
        : leave['employee_id'].toString();
    final leaveType = leave['holiday_status_id'] is List
        ? leave['holiday_status_id'][1]
        : leave['holiday_status_id'].toString();
    final status = leave['state'];
    final days = leave['number_of_days']?.toString() ?? '0';
    final reason = leave['name']?.toString() ?? 'Aucune raison spécifiée';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with employee name and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    employeeName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(status).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Leave details
            Row(
              children: [
                Icon(
                  Icons.event,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    leaveType,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDateRange(
                      leave['request_date_from'], leave['request_date_to']),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  '$days jour(s)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),

            if (reason.isNotEmpty &&
                reason != 'Aucune raison spécifiée' &&
                reason != 'false') ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.note,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Action buttons for pending requests
            if (status == 'confirm') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _refuseLeave(leave['id']),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Refuser'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red[700],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.red[200]!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveLeave(leave['id']),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approuver'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF35BF8C).withOpacity(0.1),
                        foregroundColor: const Color(0xFF35BF8C),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: const Color(0xFF35BF8C).withOpacity(0.3)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
