import 'package:flutter/material.dart';
import '../utils/navigation_helpers.dart';
import '../services/odoo_service.dart';
import '../utils/app_localizations.dart';
import '../services/user_service.dart';
import '../data/models/user_model.dart';
import 'package:intl/intl.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final OdooService _odooService = OdooService();
  List<Map<String, dynamic>> _attendanceList = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAttendanceHistory();
  }

  Future<void> _loadAttendanceHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final history = await _odooService.getAttendanceHistory();
      setState(() {
        _attendanceList = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      print('Error loading attendance history: $e');
    }
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null || dateTime == false) {
      return '-';
    }
    try {
      final dt = DateTime.parse(dateTime);
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(dt);
    } catch (e) {
      return dateTime.toString();
    }
  }

  String _formatTime(double? hours) {
    if (hours == null || hours == 0) {
      return '00:00';
    }
    final h = hours.truncate();
    final m = ((hours - h) * 60).truncate();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

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
        title: Text(localizations.translate('attendance_history')),
        backgroundColor: const Color(0xFF000B58),
        foregroundColor: Colors.white,
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
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadAttendanceHistory,
                            child: Text(localizations.translate('retry')),
                          ),
                        ],
                      ),
                    ),
                  )
                : _attendanceList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.history,
                              color: Colors.white70,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              localizations.translate('no_attendance_records'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAttendanceHistory,
                        color: Colors.white,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _attendanceList.length,
                          itemBuilder: (context, index) {
                            final attendance = _attendanceList[index];
                            final hasCheckOut =
                                attendance['check_out'] != null &&
                                    attendance['check_out'] != false;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Date header
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              hasCheckOut
                                                  ? Icons.check_circle
                                                  : Icons.radio_button_checked,
                                              color: hasCheckOut
                                                  ? Colors.green
                                                  : Colors.orange,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatDateTime(
                                                  attendance['check_in']),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: hasCheckOut
                                                ? Colors.green.shade100
                                                : Colors.orange.shade100,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            hasCheckOut
                                                ? localizations
                                                    .translate('completed')
                                                : localizations
                                                    .translate('in_progress'),
                                            style: TextStyle(
                                              color: hasCheckOut
                                                  ? Colors.green.shade900
                                                  : Colors.orange.shade900,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Check-in
                                    _buildInfoRow(
                                      Icons.login,
                                      localizations.translate('check_in'),
                                      _formatDateTime(attendance['check_in']),
                                      Colors.green,
                                    ),

                                    // Check-out
                                    _buildInfoRow(
                                      Icons.logout,
                                      localizations.translate('check_out'),
                                      _formatDateTime(attendance['check_out']),
                                      Colors.red,
                                    ),

                                    // Worked hours
                                    if (hasCheckOut &&
                                        attendance['worked_hours'] != null)
                                      _buildInfoRow(
                                        Icons.access_time,
                                        localizations.translate('worked_hours'),
                                        _formatTime(attendance['worked_hours']),
                                        Colors.blue,
                                      ),

                                    // Location info
                                    if (attendance['in_latitude'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on,
                                              size: 16,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${attendance['in_latitude']?.toStringAsFixed(4)}, ${attendance['in_longitude']?.toStringAsFixed(4)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        ),
                      ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
