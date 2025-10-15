import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    await leaveProvider.loadLeaveBalance();
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
    final cardIconSize = isSmallScreen ? 28.0 : 32.0;
    final cardTitleSize = isSmallScreen ? 16.0 : 18.0;
    final daysNumberSize = isSmallScreen ? 24.0 : 28.0;

    return Scaffold(
      appBar: AppBar(
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

                          // Balance Cards
                          ...balance.entries.map((entry) {
                            final leaveType = entry.key;
                            final days = entry.value;

                            return Padding(
                              padding: EdgeInsets.only(
                                  bottom: isSmallScreen ? 12 : 16),
                              child: Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    _showLeaveTypeDetails(context, leaveType,
                                        days, isSmallScreen);
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.all(cardPadding),
                                    child: Row(
                                      children: [
                                        // Icon
                                        Container(
                                          padding: EdgeInsets.all(
                                              isSmallScreen ? 10 : 12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF000B58)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            _getIconForLeaveType(leaveType),
                                            color: const Color(0xFF000B58),
                                            size: cardIconSize,
                                          ),
                                        ),
                                        SizedBox(
                                            width: isSmallScreen ? 12 : 16),

                                        // Leave Type Name
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                leaveType,
                                                style: TextStyle(
                                                  fontSize: cardTitleSize,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(
                                                  height:
                                                      isSmallScreen ? 2 : 4),
                                              Text(
                                                'Jours disponibles',
                                                style: TextStyle(
                                                  fontSize:
                                                      isSmallScreen ? 12 : 14,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: isSmallScreen ? 8 : 12),

                                        // Days Count
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isSmallScreen ? 12 : 16,
                                            vertical: isSmallScreen ? 6 : 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getColorForDays(days)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _getColorForDays(days)
                                                  .withOpacity(0.3),
                                              width: 2,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                '$days',
                                                style: TextStyle(
                                                  fontSize: daysNumberSize,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getColorForDays(days),
                                                ),
                                              ),
                                              Text(
                                                'jours',
                                                style: TextStyle(
                                                  fontSize:
                                                      isSmallScreen ? 10 : 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: _getColorForDays(days),
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
                          }),

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
}
