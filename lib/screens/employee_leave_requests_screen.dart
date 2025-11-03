import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/navigation_helpers.dart';
import '../services/odoo_service.dart';
import '../presentation/providers/auth_provider.dart';

class EmployeeLeaveRequestsScreen extends StatefulWidget {
  const EmployeeLeaveRequestsScreen({super.key});

  @override
  State<EmployeeLeaveRequestsScreen> createState() =>
      _EmployeeLeaveRequestsScreenState();
}

class _EmployeeLeaveRequestsScreenState
    extends State<EmployeeLeaveRequestsScreen> {
  final OdooService _odooService = OdooService();
  List<Map<String, dynamic>> _leaveRequests = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadLeaveRequests();
  }

  Future<void> _loadLeaveRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (!authProvider.isAuthenticated) {
        final restored = await authProvider.verifyAuthentication();
        if (!restored) {
          setState(() {
            _errorMessage = 'Session expirée. Veuillez vous reconnecter.';
            _isLoading = false;
          });
          return;
        }
      }

      // Get current employee ID to filter requests
      final currentEmployeeId = await _odooService.getCurrentEmployeeId();
      print('🔍 Current employee ID: $currentEmployeeId');

      final requests = await _odooService.getLeaveRequests();
      print('📋 Fetched ${requests.length} leave requests from Odoo');

      // Double-check: Filter to ensure only current employee's requests are shown
      final filteredRequests = <Map<String, dynamic>>[];
      for (var request in requests) {
        final requestEmployeeId = request['employee_id'];
        int? employeeIdFromRequest;

        // Extract employee ID from the request (can be a List [id, name] or int)
        if (requestEmployeeId is List && requestEmployeeId.isNotEmpty) {
          employeeIdFromRequest = requestEmployeeId[0] is int
              ? requestEmployeeId[0] as int
              : int.tryParse(requestEmployeeId[0].toString());
        } else if (requestEmployeeId is int) {
          employeeIdFromRequest = requestEmployeeId;
        } else if (requestEmployeeId is String) {
          employeeIdFromRequest = int.tryParse(requestEmployeeId);
        }

        // Only include if employee ID matches
        if (employeeIdFromRequest == currentEmployeeId) {
          filteredRequests.add(request);
          print(
              '✅ Included request ${request['id']} for employee $currentEmployeeId');
        } else {
          print(
              '⏭️ Skipping request ${request['id']} - belongs to employee $employeeIdFromRequest (not $currentEmployeeId)');
        }
      }

      print(
          '📊 Filtered to ${filteredRequests.length} requests for current employee');

      setState(() {
        _leaveRequests = filteredRequests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des demandes: $e';
        _isLoading = false;
      });
    }
  }

  String _getStatusLabel(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return 'Brouillon';
      case 'confirm':
        return 'En attente';
      case 'validate1':
        return 'En attente de validation';
      case 'validate':
        return 'Approuvé';
      case 'refuse':
        return 'Refusé';
      default:
        return state;
    }
  }

  Color _getStatusColor(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return Colors.grey;
      case 'confirm':
      case 'validate1':
        return Colors.orange;
      case 'validate':
        return Colors.green;
      case 'refuse':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateStr = date.toString();
      final dateTime = DateTime.parse(dateStr.split(' ')[0]);
      return DateFormat('dd/MM/yyyy').format(dateTime);
    } catch (e) {
      return date.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF000B58),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => NavigationHelpers.backToPrevious(context),
        ),
        title: const Text(
          'Mes Demandes de Congé',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadLeaveRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadLeaveRequests,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _leaveRequests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune demande de congé',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadLeaveRequests,
                      child: ListView.builder(
                        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                        itemCount: _leaveRequests.length,
                        itemBuilder: (context, index) {
                          final request = _leaveRequests[index];
                          return _buildLeaveRequestCard(request, isSmallScreen);
                        },
                      ),
                    ),
    );
  }

  Widget _buildLeaveRequestCard(
      Map<String, dynamic> request, bool isSmallScreen) {
    final state = request['state']?.toString() ?? 'unknown';
    final statusLabel = _getStatusLabel(state);
    final statusColor = _getStatusColor(state);

    // Get leave type name
    String typeName = 'Inconnu';
    final statusId = request['holiday_status_id'];
    if (statusId is List && statusId.length >= 2) {
      typeName = statusId[1].toString();
    } else if (statusId is String) {
      typeName = statusId;
    }

    // Get dates
    final dateFrom =
        _formatDate(request['request_date_from'] ?? request['date_from']);
    final dateTo =
        _formatDate(request['request_date_to'] ?? request['date_to']);

    // Get number of days
    final days = request['number_of_days']?.toString() ?? '0';
    final isHalfDay = request['request_unit_half'] == true;

    // Get reason
    final reason = request['name']?.toString() ?? 'Aucune raison spécifiée';

    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Type and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          typeName,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isHalfDay)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Demi-journée',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Dates
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '$dateFrom - $dateTo',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 15,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '$days jour${days != '1' ? 's' : ''}',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 15,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Reason
            if (reason.isNotEmpty && reason != 'Aucune raison spécifiée')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Raison:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reason,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 13 : 14,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
