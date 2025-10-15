import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/auth_provider.dart';

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
    await _verifyAuth();
    await _loadLeaveTypes();
  }

  Future<void> _verifyAuth() async {
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
  }

  Future<void> _loadLeaveTypes() async {
    setState(() {
      _isLoadingLeaveTypes = true;
    });

    try {
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

    return Scaffold(
      appBar: AppBar(
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
                                      border: Border.all(color: Colors.orange),
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
                                        borderRadius: BorderRadius.circular(12),
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
                                                type['name'] == newValue)['id'];
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
                                    hintStyle:
                                        TextStyle(fontSize: labelFontSize - 2),
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
                                      backgroundColor: const Color(0xFF35BF8C),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
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
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _endDate = date;
      });
    }
  }

  Future<void> _submitLeaveRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner les dates de début et de fin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La date de fin doit être après la date de début'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedLeaveType == null || _selectedLeaveTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un type de congé'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (!authProvider.odooService.isAuthenticated) {
        print('Not authenticated, attempting to restore...');
        final restored = await authProvider.verifyAuthentication();

        if (!restored) {
          throw Exception('Session expirée. Veuillez vous reconnecter.');
        }
      }

      print('Submitting leave request...');
      print('Leave type: $_selectedLeaveType (ID: $_selectedLeaveTypeId)');
      print('Start date: $_startDate');
      print('End date: $_endDate');
      print('Reason: $_reason');

      final leaveId = await authProvider.odooService.createLeaveRequest(
        leaveTypeId: _selectedLeaveTypeId!,
        dateFrom: _startDate!,
        dateTo: _endDate!,
        reason: _reason.isNotEmpty ? _reason : null,
      );

      print('Leave request created with ID: $leaveId');

      if (leaveId > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demande de congé soumise avec succès!'),
              backgroundColor: Color(0xFF35BF8C),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('Échec de la soumission de la demande');
      }
    } catch (e) {
      print('Error submitting leave request: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
