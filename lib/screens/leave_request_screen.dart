import 'package:flutter/material.dart';
import '../utils/navigation_helpers.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../services/sync_service.dart';

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedLeaveType;
  int? _selectedLeaveTypeId;
  DateTime? _startDate;
  DateTime? _endDate;
  String _reason = '';
  bool _isLoading = false;
  bool _isLoadingLeaveTypes = true;

  List<Map<String, dynamic>> _leaveTypes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  Future<void> _initializeScreen() async {
    try {
      await _verifyAuth();
      await _loadLeaveTypes();
    } catch (e) {
      print('Error initializing leave request screen: $e');
      if (mounted) {
        setState(() {
          _isLoadingLeaveTypes = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'initialisation: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _verifyAuth() async {
    try {
      if (!mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (!authProvider.isAuthenticated ||
          !authProvider.odooService.isAuthenticated) {
        final restored = await authProvider.verifyAuthentication();

        if (!restored) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Session expirée. Veuillez vous reconnecter.'),
                backgroundColor: Colors.red,
              ),
            );
            Navigator.of(context).pushReplacementNamed('/login');
          }
        }
      }
    } catch (e) {
      print('Error verifying authentication: $e');
      // Don't crash the app, just log the error
      // The leave types loading will handle offline mode
    }
  }

  Future<void> _loadLeaveTypes() async {
    if (!mounted) return;

    setState(() {
      _isLoadingLeaveTypes = true;
    });

    try {
      if (!mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final leaveTypes = await authProvider.odooService.getLeaveTypes();

      print('Loaded ${leaveTypes.length} leave types from Odoo:');
      for (var type in leaveTypes) {
        print('  - ID: ${type['id']}, Name: ${type['name']}');
      }

      if (mounted) {
        setState(() {
          _leaveTypes = leaveTypes;
          _isLoadingLeaveTypes = false;

          if (_leaveTypes.isNotEmpty) {
            _selectedLeaveType = _leaveTypes.first['name'];
            _selectedLeaveTypeId = _leaveTypes.first['id'];
          }
        });

        // Show message if offline and no cached types available
        if (leaveTypes.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Mode hors ligne: Aucun type de congé disponible. Veuillez vous connecter pour charger les types de congés.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading leave types: $e');
      if (mounted) {
        setState(() {
          _isLoadingLeaveTypes = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des types de congés: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 900;

    // Responsive padding
    final horizontalPadding =
        isSmallScreen ? 16.0 : (isMediumScreen ? 32.0 : 64.0);
    final cardPadding = isSmallScreen ? 16.0 : 24.0;

    // Responsive font sizes
    final titleFontSize = isSmallScreen ? 20.0 : 24.0;
    final labelFontSize = isSmallScreen ? 14.0 : 16.0;
    final buttonFontSize = isSmallScreen ? 16.0 : 18.0;

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        // Handle Android back button - same functionality as AppBar back button
        await NavigationHelpers.backToMenu(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => NavigationHelpers.backToMenu(context),
          ),
          title: const Text('Demande de congé'),
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
            child: _isLoadingLeaveTypes
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  )
                : Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 16,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 800, // Max width for large screens
                        ),
                        child: Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(cardPadding),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Nouvelle demande de congé',
                                    style: TextStyle(
                                      fontSize: titleFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF000B58),
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 16 : 24),

                                  // Leave Type Selection
                                  Text(
                                    'Type de congé',
                                    style: TextStyle(
                                      fontSize: labelFontSize,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_leaveTypes.isEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border:
                                            Border.all(color: Colors.orange),
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.orange[50],
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.warning,
                                              color: Colors.orange),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Aucun type de congé disponible',
                                              style: TextStyle(
                                                color: Colors.orange[900],
                                                fontSize: labelFontSize - 2,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    DropdownButtonFormField<String>(
                                      initialValue: _selectedLeaveType,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                        prefixIcon:
                                            const Icon(Icons.event_available),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: isSmallScreen ? 12 : 16,
                                        ),
                                      ),
                                      style: TextStyle(
                                        fontSize: labelFontSize,
                                        color: Colors.black87,
                                      ),
                                      items: _leaveTypes.map((type) {
                                        return DropdownMenuItem<String>(
                                          value: type['name'],
                                          child: Text(type['name']),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          _selectedLeaveType = newValue;
                                          _selectedLeaveTypeId =
                                              _leaveTypes.firstWhere((type) =>
                                                  type['name'] ==
                                                  newValue)['id'];
                                          print(
                                              'Selected: $_selectedLeaveType (ID: $_selectedLeaveTypeId)');
                                        });
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Veuillez sélectionner un type de congé';
                                        }
                                        return null;
                                      },
                                    ),
                                  SizedBox(height: isSmallScreen ? 16 : 20),

                                  // Date Range Selection - Responsive layout
                                  isSmallScreen
                                      ? Column(
                                          children: [
                                            _buildDateField(
                                              label: 'Date de début',
                                              date: _startDate,
                                              onTap: () =>
                                                  _selectStartDate(context),
                                              labelFontSize: labelFontSize,
                                            ),
                                            const SizedBox(height: 16),
                                            _buildDateField(
                                              label: 'Date de fin',
                                              date: _endDate,
                                              onTap: () =>
                                                  _selectEndDate(context),
                                              labelFontSize: labelFontSize,
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Expanded(
                                              child: _buildDateField(
                                                label: 'Date de début',
                                                date: _startDate,
                                                onTap: () =>
                                                    _selectStartDate(context),
                                                labelFontSize: labelFontSize,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: _buildDateField(
                                                label: 'Date de fin',
                                                date: _endDate,
                                                onTap: () =>
                                                    _selectEndDate(context),
                                                labelFontSize: labelFontSize,
                                              ),
                                            ),
                                          ],
                                        ),
                                  SizedBox(height: isSmallScreen ? 16 : 20),

                                  // Reason Text Field
                                  Text(
                                    'Raison (optionnel)',
                                    style: TextStyle(
                                      fontSize: labelFontSize,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    maxLines: isSmallScreen ? 3 : 4,
                                    style: TextStyle(fontSize: labelFontSize),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Décrivez la raison de votre demande de congé...',
                                      hintStyle: TextStyle(
                                          fontSize: labelFontSize - 2),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                      prefixIcon: const Icon(Icons.note),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: isSmallScreen ? 12 : 16,
                                      ),
                                    ),
                                    onChanged: (value) {
                                      _reason = value;
                                    },
                                  ),
                                  SizedBox(height: isSmallScreen ? 24 : 32),

                                  // Submit Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: isSmallScreen ? 48 : 56,
                                    child: ElevatedButton(
                                      onPressed:
                                          (_isLoading || _leaveTypes.isEmpty)
                                              ? null
                                              : _submitLeaveRequest,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF35BF8C),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        elevation: 4,
                                      ),
                                      child: _isLoading
                                          ? SizedBox(
                                              height: isSmallScreen ? 18 : 20,
                                              width: isSmallScreen ? 18 : 20,
                                              child:
                                                  const CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              'Soumettre la demande',
                                              style: TextStyle(
                                                fontSize: buttonFontSize,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required double labelFontSize,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: labelFontSize,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[50],
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    date != null
                        ? '${date.day}/${date.month}/${date.year}'
                        : 'Sélectionner une date',
                    style: TextStyle(
                      color: date != null ? Colors.black87 : Colors.grey[600],
                      fontSize: labelFontSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    if (!mounted) return;

    try {
      final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (date != null && mounted) {
        setState(() {
          _startDate = date;
        });
      }
    } catch (e) {
      print('Error selecting start date: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection de la date: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    if (!mounted) return;

    try {
      final date = await showDatePicker(
        context: context,
        initialDate: _startDate ?? DateTime.now(),
        firstDate: _startDate ?? DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (date != null && mounted) {
        setState(() {
          _endDate = date;
        });
      }
    } catch (e) {
      print('Error selecting end date: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection de la date: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitLeaveRequest() async {
    if (!mounted) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDate == null || _endDate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner les dates de début et de fin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La date de fin doit être après la date de début'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedLeaveType == null || _selectedLeaveTypeId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un type de congé'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      if (!mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Only check authentication if both AuthProvider and OdooService indicate not authenticated
      // This prevents unnecessary re-authentication attempts
      if (!authProvider.isAuthenticated ||
          !authProvider.odooService.isAuthenticated) {
        print(
            'Authentication check: AuthProvider=${authProvider.isAuthenticated}, OdooService=${authProvider.odooService.isAuthenticated}');
        print('Attempting to restore authentication...');

        try {
          final restored = await authProvider.verifyAuthentication();

          if (!restored) {
            print('Authentication restoration failed');
            // Only navigate to login if we truly can't authenticate
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Session expirée. Veuillez vous reconnecter.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
              // Wait a bit before navigating to allow user to see the message
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            }
            return;
          }
          print('Authentication restored successfully');
        } catch (authError) {
          print('Error during authentication verification: $authError');
          // If verification itself fails, don't immediately logout
          // The RPC call will fail if auth is truly invalid
          print('Continuing with submission attempt...');
        }
      }

      print('Submitting leave request...');
      print('Leave type: $_selectedLeaveType (ID: $_selectedLeaveTypeId)');
      print('Start date: $_startDate');
      print('End date: $_endDate');
      print('Reason: $_reason');

      // Check if offline before submitting
      final syncService = SyncService();
      final isOffline = !syncService.isConnected;

      final leaveId = await authProvider.odooService.createLeaveRequest(
        leaveTypeId: _selectedLeaveTypeId!,
        dateFrom: _startDate!,
        dateTo: _endDate!,
        reason: _reason.isNotEmpty ? _reason : null,
      );

      print('Leave request created with ID: $leaveId (offline: $isOffline)');

      if (leaveId > 0) {
        if (mounted) {
          if (isOffline) {
            // Show offline message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Demande de congé enregistrée en mode hors ligne. Elle sera envoyée automatiquement lorsque vous serez connecté.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          } else {
            // Show success message for online submission
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Demande de congé soumise avec succès!'),
                backgroundColor: Color(0xFF35BF8C),
              ),
            );
          }

          // Navigate back safely using NavigationHelpers which handles the navigation properly
          // This ensures we go back to the previous screen (e.g., employee dashboard)
          // instead of accidentally going to welcome page
          await NavigationHelpers.backToPrevious(context);
        }
      } else {
        throw Exception('Échec de la soumission de la demande');
      }
    } catch (e) {
      print('Error submitting leave request: $e');
      print('Error type: ${e.runtimeType}');

      // Check if error is related to network/connectivity
      final errorString = e.toString().toLowerCase();
      final isNetworkError = errorString.contains('socket') ||
          errorString.contains('network') ||
          errorString.contains('connection') ||
          errorString.contains('timeout') ||
          errorString.contains('failed host lookup') ||
          errorString.contains('no internet');

      // Check if error is related to authentication
      final isAuthError = errorString.contains('session') ||
          errorString.contains('expir') ||
          errorString.contains('authentic') ||
          errorString.contains('access denied') ||
          errorString.contains('unauthorized') ||
          errorString.contains('not authenticated');

      if (mounted) {
        if (isNetworkError) {
          // For network errors, show offline message and try to queue
          print('Network error detected, attempting to queue operation');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Mode hors ligne détecté. La demande sera enregistrée et envoyée automatiquement lorsque vous serez connecté.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
          // Don't navigate away, let user try again or wait for connection
        } else if (isAuthError) {
          // For authentication errors, show message and navigate to login
          print('Authentication error detected, navigating to login');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expirée. Veuillez vous reconnecter.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          // Wait a bit before navigating to allow user to see the message
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        } else {
          // For other errors, just show the error message without logging out
          print('Non-authentication error, showing error message only');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
