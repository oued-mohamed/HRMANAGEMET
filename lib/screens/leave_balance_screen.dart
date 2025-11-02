import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/navigation_helpers.dart';
import '../presentation/providers/leave_provider.dart';
import '../presentation/providers/auth_provider.dart';

class LeaveBalanceScreen extends StatefulWidget {
  const LeaveBalanceScreen({super.key});

  @override
  State<LeaveBalanceScreen> createState() => _LeaveBalanceScreenState();
}

class _LeaveBalanceScreenState extends State<LeaveBalanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLeaveBalance();
    });
  }

  Future<void> _loadLeaveBalance() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated) {
      final restored = await authProvider.verifyAuthentication();
      if (!restored && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expirée. Veuillez vous reconnecter.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
    await Future.wait([
      leaveProvider.loadLeaveBalance(),
      leaveProvider.loadLeaveRequests(), // Also load individual requests
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 900;

    // Responsive values
    final horizontalPadding =
        isSmallScreen ? 16.0 : (isMediumScreen ? 32.0 : 64.0);
    final cardPadding = isSmallScreen ? 16.0 : 20.0;
    final headerIconSize = isSmallScreen ? 40.0 : 48.0;
    final headerTitleSize = isSmallScreen ? 20.0 : 24.0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavigationHelpers.backToPrevious(context),
        ),
        title: const Text('Solde de mes congés'),
        backgroundColor: const Color(0xFF000B58),
        foregroundColor: Colors.white,
        elevation: 0,
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
        child: SafeArea(
          child: Consumer<LeaveProvider>(
            builder: (context, leaveProvider, child) {
              if (leaveProvider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                );
              }

              if (leaveProvider.error != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          leaveProvider.error!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadLeaveBalance,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF000B58),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final balance = leaveProvider.leaveBalance;

              if (balance == null || balance.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.white.withOpacity(0.8),
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun solde de congés disponible',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Veuillez contacter les RH',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _loadLeaveBalance,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 16,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 800, // Max width for large screens
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header Card
                          Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              padding: EdgeInsets.all(cardPadding),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF000B58).withOpacity(0.1),
                                    const Color(0xFF35BF8C).withOpacity(0.1),
                                  ],
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: headerIconSize,
                                    color: const Color(0xFF000B58),
                                  ),
                                  SizedBox(height: isSmallScreen ? 8 : 12),
                                  Text(
                                    'Votre solde de congés',
                                    style: TextStyle(
                                      fontSize: headerTitleSize,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF000B58),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: isSmallScreen ? 6 : 8),
                                  Text(
                                    'Mis à jour: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 16 : 24),

                          // Balance Grid - 4 items per row
                          _buildBalanceGrid(balance, isSmallScreen, context),

                          SizedBox(height: isSmallScreen ? 16 : 24),

                          // Leave Requests Section
                          _buildLeaveRequestsSection(
                              context, leaveProvider, isSmallScreen),

                          SizedBox(height: isSmallScreen ? 16 : 24),

                          // Info Card
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue[700],
                                    size: isSmallScreen ? 20 : 24,
                                  ),
                                  SizedBox(width: isSmallScreen ? 8 : 12),
                                  Expanded(
                                    child: Text(
                                      'Tirez vers le bas pour actualiser le solde',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 12 : 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceGrid(
      Map<String, dynamic> balance, bool isSmallScreen, BuildContext context) {
    final entries = balance.entries.toList();

    // Split entries into rows of 3
    List<List<MapEntry<String, dynamic>>> rows = [];
    for (int i = 0; i < entries.length; i += 3) {
      rows.add(
          entries.sublist(i, i + 3 > entries.length ? entries.length : i + 3));
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: rows.asMap().entries.map((rowEntry) {
            final rowIndex = rowEntry.key;
            final row = rowEntry.value;
            final isLastRow = rowIndex == rows.length - 1;

            return Column(
              children: [
                Row(
                  children: List.generate(3, (colIndex) {
                    final hasItem = colIndex < row.length;
                    final isLastCol = colIndex == 2;

                    if (hasItem) {
                      final entry = row[colIndex];
                      final leaveType = entry.key;
                      final days = entry.value;

                      return Expanded(
                        child: Container(
                          height: isSmallScreen
                              ? 110
                              : 125, // Reduced height after removing icons
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: isLastCol
                                    ? Colors.transparent
                                    : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: _buildLeaveTypeCard(
                              context, leaveType, days, isSmallScreen, false),
                        ),
                      );
                    } else {
                      // Empty cell
                      return Expanded(
                        child: Container(
                          height: isSmallScreen ? 110 : 125,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: isLastCol
                                    ? Colors.transparent
                                    : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  }),
                ),
                if (!isLastRow)
                  Container(
                    height: 1,
                    color: Colors.grey[300],
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLeaveTypeCard(BuildContext context, String leaveType,
      dynamic days, bool isSmallScreen, bool showCard) {
    return InkWell(
      onTap: () {
        _showLeaveTypeDetails(context, leaveType, days, isSmallScreen);
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 8 : 12,
          vertical: 0, // No vertical padding - we'll add spacing in Column
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top spacing - reduced after removing icon
            SizedBox(height: isSmallScreen ? 8 : 10),
            // Leave Type Name - centered
            Expanded(
              child: Center(
                child: Text(
                  leaveType,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Bottom spacing before badge
            SizedBox(height: isSmallScreen ? 4 : 6),
            // Days Count Badge at bottom
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 6 : 8,
                vertical: isSmallScreen ? 3 : 4,
              ),
              decoration: BoxDecoration(
                color: _getColorForDays(days).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _getColorForDays(days).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    days.toStringAsFixed(days % 1 == 0 ? 0 : 1),
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: _getColorForDays(days),
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'jours',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 8 : 9,
                      fontWeight: FontWeight.w600,
                      color: _getColorForDays(days),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom spacing - reduced after removing icon
            SizedBox(height: isSmallScreen ? 6 : 8),
          ],
        ),
      ),
    );
  }

  IconData _getIconForLeaveType(String leaveType) {
    final lowerType = leaveType.toLowerCase();
    if (lowerType.contains('payé')) {
      return Icons.beach_access;
    } else if (lowerType.contains('maladie')) {
      return Icons.medical_services;
    } else if (lowerType.contains('parental') ||
        lowerType.contains('maternité') ||
        lowerType.contains('paternité')) {
      return Icons.family_restroom;
    } else if (lowerType.contains('compensation')) {
      return Icons.compare_arrows;
    } else if (lowerType.contains('supplémentaire')) {
      return Icons.access_time;
    } else if (lowerType.contains('éducation') ||
        lowerType.contains('formation')) {
      return Icons.school;
    } else {
      return Icons.event_available;
    }
  }

  Color _getColorForDays(dynamic days) {
    final daysNum = days is num ? days.toDouble() : 0.0;
    if (daysNum <= 0) {
      return Colors.red;
    } else if (daysNum <= 5) {
      return Colors.orange;
    } else {
      return const Color(0xFF35BF8C);
    }
  }

  void _showLeaveTypeDetails(BuildContext context, String leaveType,
      dynamic days, bool isSmallScreen) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              _getIconForLeaveType(leaveType),
              color: const Color(0xFF000B58),
              size: isSmallScreen ? 20 : 24,
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Expanded(
              child: Text(
                leaveType,
                style: TextStyle(
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Solde disponible', '$days jours'),
            const Divider(height: 24),
            _buildDetailRow('Type', leaveType),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Consultez votre RH pour plus de détails',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/leave-request');
            },
            icon: const Icon(Icons.add),
            label: const Text('Faire une demande'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF000B58),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveRequestsSection(
      BuildContext context, LeaveProvider leaveProvider, bool isSmallScreen) {
    final requests = leaveProvider.leaveRequests ?? [];

    if (requests.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.event_note,
                    color: const Color(0xFF000B58),
                    size: isSmallScreen ? 24 : 28,
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Text(
                    'Mes demandes de congés',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF000B58),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Aucune demande de congé',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group requests by leave type
    Map<String, List<Map<String, dynamic>>> groupedByType = {};
    for (var request in requests) {
      final statusId = request['holiday_status_id'];
      String typeName = 'Inconnu';

      if (statusId is List && statusId.length >= 2) {
        typeName = statusId[1].toString();
      } else if (statusId is String) {
        typeName = statusId;
      }

      if (!groupedByType.containsKey(typeName)) {
        groupedByType[typeName] = [];
      }
      groupedByType[typeName]!.add(request);
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_note,
                  color: const Color(0xFF000B58),
                  size: isSmallScreen ? 24 : 28,
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Text(
                  'Mes demandes de congés',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF000B58),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Le solde affiché ci-dessus ne compte que les congés approuvés.',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            // Show requests grouped by type
            ...groupedByType.entries.map((entry) {
              final typeName = entry.key;
              final typeRequests = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(
                          _getIconForLeaveType(typeName),
                          color: const Color(0xFF000B58),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          typeName,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF000B58),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...typeRequests.map((request) {
                    return _buildLeaveRequestCard(request, isSmallScreen);
                  }),
                  SizedBox(height: isSmallScreen ? 16 : 20),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveRequestCard(
      Map<String, dynamic> request, bool isSmallScreen) {
    final state = request['state']?.toString() ?? 'unknown';
    final statusId = request['holiday_status_id'];
    String typeName = 'Inconnu';

    if (statusId is List && statusId.length >= 2) {
      typeName = statusId[1].toString();
    } else if (statusId is String) {
      typeName = statusId;
    }

    // Parse dates
    String formatDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return 'N/A';
      try {
        final date = DateTime.parse(dateStr);
        return '${date.day}/${date.month}/${date.year}';
      } catch (e) {
        return dateStr;
      }
    }

    final dateFrom = formatDate(request['request_date_from']?.toString());
    final dateTo = formatDate(request['request_date_to']?.toString());

    // Calculate days
    double days = 0.0;
    var numDays = request['number_of_days'];
    if (numDays is num) {
      days = numDays.toDouble();
    } else if (numDays is String) {
      days = double.tryParse(numDays) ?? 0.0;
    }

    // Check for half-day
    final isHalfDay = request['request_unit_half'] == true;
    final typeNameLower = typeName.toLowerCase();
    final isHalfDayType =
        typeNameLower.contains('demi') || typeNameLower.contains('half');

    if ((isHalfDay || isHalfDayType) && days == 1.0) {
      days = 0.5;
    }

    // Get status info
    String statusText = _getStatusLabel(state);
    Color statusColor = _getStatusColor(state);
    IconData statusIcon = _getStatusIcon(state);

    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateFrom == dateTo ? dateFrom : '$dateFrom - $dateTo',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 4 : 6),
                    Text(
                      '${days.toStringAsFixed(days % 1 == 0 ? 0 : 1)} jour${days != 1.0 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : 12,
                  vertical: isSmallScreen ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    SizedBox(width: isSmallScreen ? 4 : 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (request['name'] != null && request['name'].toString().isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: isSmallScreen ? 8 : 12),
              child: Text(
                request['name'].toString(),
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getStatusLabel(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return 'Brouillon';
      case 'confirm':
        return 'En attente';
      case 'validate1':
        return 'Approuvé (N1)';
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
        return Colors.orange;
      case 'validate1':
        return Colors.blue;
      case 'validate':
        return const Color(0xFF35BF8C); // Green
      case 'refuse':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return Icons.edit_outlined;
      case 'confirm':
        return Icons.pending_outlined;
      case 'validate1':
        return Icons.check_circle_outline;
      case 'validate':
        return Icons.check_circle;
      case 'refuse':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }
}
