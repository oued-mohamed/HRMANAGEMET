import 'package:flutter/material.dart';
import '../utils/navigation_helpers.dart';
import '../utils/responsive_helper.dart';
import '../services/odoo_service.dart';
import '../utils/app_localizations.dart';

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
                    final isTablet = ResponsiveHelper.isTablet(context);
                    final isDesktop = ResponsiveHelper.isDesktop(context);

                    // Use GridView for tablets/desktop, ListView for mobile
                    if (isTablet || isDesktop) {
                      return Padding(
                        padding: ResponsiveHelper.responsivePadding(context),
                        child: GridView.count(
                          crossAxisCount: ResponsiveHelper.gridColumns(context),
                          crossAxisSpacing: ResponsiveHelper.responsiveSpacing(context, mobile: 16),
                          mainAxisSpacing: ResponsiveHelper.responsiveSpacing(context, mobile: 16),
                          childAspectRatio: 1.1,
                          children: [
                            _buildStatCard(
                              context,
                              'Total Hours',
                              _formatHours(stats['total_hours'] ?? 0.0),
                              Icons.access_time,
                              Colors.blue,
                            ),
                            _buildStatCard(
                              context,
                              'Work Days',
                              stats['work_days']?.toString() ?? '0',
                              Icons.calendar_today,
                              Colors.green,
                            ),
                            _buildStatCard(
                              context,
                              'Average per Day',
                              _formatHours(stats['avg_hours'] ?? 0.0),
                              Icons.trending_up,
                              Colors.orange,
                            ),
                          ],
                        ),
                      );
                    } else {
                      return ListView(
                        padding: ResponsiveHelper.responsivePadding(context),
                        children: [
                          _buildStatCard(
                            context,
                            'Total Hours',
                            _formatHours(stats['total_hours'] ?? 0.0),
                            Icons.access_time,
                            Colors.blue,
                          ),
                          SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 16)),
                          _buildStatCard(
                            context,
                            'Work Days',
                            stats['work_days']?.toString() ?? '0',
                            Icons.calendar_today,
                            Colors.green,
                          ),
                          SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 16)),
                          _buildStatCard(
                            context,
                            'Average per Day',
                            _formatHours(stats['avg_hours'] ?? 0.0),
                            Icons.trending_up,
                            Colors.orange,
                          ),
                        ],
                      );
                    }
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
      margin: ResponsiveHelper.responsivePadding(context),
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveHelper.responsiveValue(context, mobile: 4.0, tablet: 8.0),
        vertical: ResponsiveHelper.responsiveValue(context, mobile: 4.0, tablet: 6.0),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.responsiveBorderRadius(context, mobile: 12.0, tablet: 16.0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPeriodButton(context, 'day', 'Day'),
          ),
          Expanded(
            child: _buildPeriodButton(context, 'week', 'Week'),
          ),
          Expanded(
            child: _buildPeriodButton(context, 'month', 'Month'),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(BuildContext context, String period, String label) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: ResponsiveHelper.responsiveValue(context, mobile: 12.0, tablet: 16.0),
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(
            ResponsiveHelper.responsiveValue(context, mobile: 8.0, tablet: 12.0),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? const Color(0xFF000B58) : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 14.0, tablet: 16.0),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
    final isTablet = ResponsiveHelper.isTablet(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final useVerticalLayout = isTablet || isDesktop;

    return Container(
      padding: EdgeInsets.all(
        ResponsiveHelper.responsiveValue(context, mobile: 20.0, tablet: 28.0, desktop: 32.0),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.responsiveBorderRadius(context, mobile: 16.0, tablet: 20.0, desktop: 24.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: useVerticalLayout
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(
                    ResponsiveHelper.responsiveValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0),
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: ResponsiveHelper.responsiveIconSize(context, mobile: 32.0, tablet: 48.0, desktop: 56.0),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 16)),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 14.0, tablet: 16.0, desktop: 18.0),
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ResponsiveHelper.responsiveValue(context, mobile: 4.0, tablet: 8.0)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 24.0, tablet: 32.0, desktop: 40.0),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: EdgeInsets.all(
                    ResponsiveHelper.responsiveValue(context, mobile: 16.0, tablet: 20.0),
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: ResponsiveHelper.responsiveIconSize(context, mobile: 32.0, tablet: 40.0),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 14.0, tablet: 16.0),
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.responsiveValue(context, mobile: 4.0, tablet: 8.0)),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 24.0, tablet: 28.0),
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
