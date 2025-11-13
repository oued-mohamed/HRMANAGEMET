import 'package:flutter/material.dart';
import '../utils/navigation_helpers.dart';
import '../services/odoo_service.dart';
import '../utils/app_localizations.dart';
import '../services/user_service.dart';
import '../data/models/user_model.dart';

class WorkTimeStatisticsScreen extends StatefulWidget {
  const WorkTimeStatisticsScreen({super.key});

  @override
  State<WorkTimeStatisticsScreen> createState() =>
      _WorkTimeStatisticsScreenState();
}

class _WorkTimeStatisticsScreenState extends State<WorkTimeStatisticsScreen> {
  final OdooService _odooService = OdooService();
  String _selectedPeriod = 'day'; // day, week, month

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        // Handle Android back button - same functionality as AppBar back button
        await NavigationHelpers.backToPrevious(context);
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavigationHelpers.backToPrevious(context),
        ),
        title: Text(localizations.translate('working_time')),
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
        child: SafeArea(
          child: Column(
            children: [
              // Period selector
              _buildPeriodSelector(context),

              // Statistics cards
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getWorkTimeStatistics(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
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
                                'Error: ${snapshot.error}',
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final statistics = snapshot.data ?? [];

                    if (statistics.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Colors.white70,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No data available',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final stats = statistics.isNotEmpty ? statistics[0] : {};

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildStatCard(
                          context,
                          'Total Hours',
                          _formatHours(stats['total_hours'] ?? 0.0),
                          Icons.access_time,
                          Colors.blue,
                        ),
                        const SizedBox(height: 16),
                        _buildStatCard(
                          context,
                          'Work Days',
                          stats['work_days']?.toString() ?? '0',
                          Icons.calendar_today,
                          Colors.green,
                        ),
                        const SizedBox(height: 16),
                        _buildStatCard(
                          context,
                          'Average per Day',
                          _formatHours(stats['avg_hours'] ?? 0.0),
                          Icons.trending_up,
                          Colors.orange,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPeriodButton('day', 'Day'),
          ),
          Expanded(
            child: _buildPeriodButton('week', 'Week'),
          ),
          Expanded(
            child: _buildPeriodButton('month', 'Month'),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String period, String label) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? const Color(0xFF000B58) : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getWorkTimeStatistics() async {
    try {
      final attendanceRecords = await _odooService.getAttendanceHistory();

      DateTime startDate;
      final endDate = DateTime.now();

      switch (_selectedPeriod) {
        case 'day':
          startDate = DateTime.now().subtract(const Duration(days: 1));
          break;
        case 'week':
          startDate = DateTime.now().subtract(const Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime.now().subtract(const Duration(days: 30));
          break;
        default:
          startDate = DateTime.now().subtract(const Duration(days: 7));
      }

      // Filter records by date range
      final filteredRecords = attendanceRecords.where((record) {
        final checkIn = record['check_in'];
        if (checkIn == null || checkIn == false) return false;

        try {
          final checkInDate = DateTime.parse(checkIn.toString());
          return checkInDate.isAfter(startDate) &&
              checkInDate.isBefore(endDate);
        } catch (e) {
          return false;
        }
      }).toList();

      // Group records by date to count unique work days
      final Map<String, List<Map<String, dynamic>>> recordsByDate = {};

      for (var record in filteredRecords) {
        final checkIn = record['check_in'];
        if (checkIn != null) {
          try {
            final checkInDate = DateTime.parse(checkIn.toString());
            final dateKey =
                '${checkInDate.year}-${checkInDate.month}-${checkInDate.day}';

            if (!recordsByDate.containsKey(dateKey)) {
              recordsByDate[dateKey] = [];
            }
            recordsByDate[dateKey]!.add(record);
          } catch (e) {
            // Skip invalid dates
          }
        }
      }

      // Calculate statistics
      double totalHours = 0.0;
      int completedDays = 0;

      // Process each unique day
      for (var dayRecords in recordsByDate.values) {
        double dayHours = 0.0;
        bool hasCompletedDay = false;

        for (var record in dayRecords) {
          final workedHours = record['worked_hours'];
          if (workedHours != null && workedHours is double && workedHours > 0) {
            dayHours += workedHours;
            hasCompletedDay = true;
          }
        }

        if (hasCompletedDay) {
          totalHours += dayHours;
          completedDays++;
        }
      }

      final avgHours = completedDays > 0 ? totalHours / completedDays : 0.0;

      return [
        {
          'total_hours': totalHours,
          'avg_hours': avgHours,
          'work_days': completedDays,
        }
      ];
    } catch (e) {
      print('Error getting work time statistics: $e');
      return [];
    }
  }

  String _formatHours(double hours) {
    final h = hours.truncate();
    final m = ((hours - h) * 60).truncate();
    return '${h}h ${m}m';
  }
}
