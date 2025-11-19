import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../widgets/employee_drawer.dart';
import '../widgets/last_notification_widget.dart';
import '../presentation/providers/leave_provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../utils/app_localizations.dart';
import '../utils/responsive_helper.dart';
import '../services/user_service.dart';
import '../services/odoo_service.dart';
import '../services/notification_service.dart';
import '../data/models/user_model.dart';
import '../widgets/dashboard_header.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final OdooService _odooService = OdooService();
  final NotificationService _notificationService = NotificationService();

  int _unreadCount = 0;
  bool _isLoadingNotifications = true;
  Map<String, dynamic>? _lastNotification;
  bool _isLoadingLastNotification = true;
  double _weeklyHours = 0.0;
  bool _isLoadingWeeklyHours = true;
  int _pendingLeaveRequestsCount = 0;
  bool _isLoadingLeaveRequests = true;

  // Get current week (Monday to Saturday)
  DateTime get _weekStart {
    final now = DateTime.now();
    final weekday = now.weekday; // 1 = Monday, 7 = Sunday
    // Go back to Monday
    return now.subtract(Duration(days: weekday - 1));
  }

  DateTime get _weekEnd {
    final now = DateTime.now();
    final weekday = now.weekday;
    // Go forward to Saturday (add 5 days from Monday)
    return now.add(Duration(days: 7 - weekday));
  }

  @override
  void initState() {
    super.initState();
    // Initialiser le service utilisateur
    UserService.instance.initialize();
    _notificationService.addListener(_onNotificationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // If a caller requests to open the menu, route to overlay menu
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['openDrawer'] == true) {
        Navigator.pushReplacementNamed(context, '/employee-menu');
      }
      _loadLeaveBalance();
      _loadNotifications();
      _loadWeeklyHours();
      _loadPendingLeaveRequestsCount();
    });
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationChanged);
    super.dispose();
  }

  void _onNotificationChanged() {
    _loadNotifications();
  }

  Future<void> _loadLeaveBalance() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated) {
      final restored = await authProvider.verifyAuthentication();
      if (!restored) {
        return;
      }
    }

    final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
    await leaveProvider.loadLeaveBalance();
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _isLoadingLastNotification = true;
      });

      final notifications = await _odooService.getUnreadNotifications();
      print('Loaded ${notifications.length} notifications');

      // Sort notifications by date (most recent first)
      List<Map<String, dynamic>> sortedNotifications = List.from(notifications);
      sortedNotifications.sort((a, b) {
        final dateA = a['create_date']?.toString() ?? '';
        final dateB = b['create_date']?.toString() ?? '';
        try {
          final parsedA = DateTime.parse(dateA.split('.')[0]);
          final parsedB = DateTime.parse(dateB.split('.')[0]);
          return parsedB.compareTo(parsedA);
        } catch (e) {
          return dateB.compareTo(dateA);
        }
      });

      setState(() {
        _unreadCount = notifications.where((n) => n['is_read'] == false).length;
        _isLoadingNotifications = false;
        _lastNotification =
            sortedNotifications.isNotEmpty ? sortedNotifications.first : null;
        _isLoadingLastNotification = false;
        print('Last notification set: ${_lastNotification != null}');
      });
    } catch (e) {
      print('Error loading notifications for dashboard: $e');
      setState(() {
        _isLoadingNotifications = false;
        _isLoadingLastNotification = false;
        _lastNotification = null;
      });
    }
  }

  // Get weekly hours for the current employee
  Future<void> _loadWeeklyHours() async {
    setState(() => _isLoadingWeeklyHours = true);
    try {
      final employeeId = await _odooService.getCurrentEmployeeId();
      final attendanceRecords =
          await _odooService.getEmployeeAttendance(employeeId, useCache: true);

      double totalHours = 0.0;

      for (var record in attendanceRecords) {
        final checkIn = record['check_in'];
        if (checkIn != null) {
          try {
            final checkInDate = DateTime.parse(checkIn.toString());
            // Check if this record is within the current week (Monday to Saturday)
            if (checkInDate
                    .isAfter(_weekStart.subtract(const Duration(days: 1))) &&
                checkInDate.isBefore(_weekEnd.add(const Duration(days: 1)))) {
              final workedHours = record['worked_hours'];
              if (workedHours != null) {
                double hours = 0.0;
                if (workedHours is double) {
                  hours = workedHours;
                } else if (workedHours is num) {
                  hours = workedHours.toDouble();
                } else if (workedHours is String) {
                  hours = double.tryParse(workedHours) ?? 0.0;
                }
                if (hours > 0) {
                  totalHours += hours;
                }
              }
            }
          } catch (e) {
            // Skip invalid dates
            print('Error parsing date in weekly hours: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _weeklyHours = totalHours;
          _isLoadingWeeklyHours = false;
        });
      }
    } catch (e) {
      print('Error loading weekly hours: $e');
      if (mounted) {
        setState(() {
          _weeklyHours = 0.0;
          _isLoadingWeeklyHours = false;
        });
      }
    }
  }

  // Load pending leave requests count
  Future<void> _loadPendingLeaveRequestsCount() async {
    setState(() => _isLoadingLeaveRequests = true);
    try {
      final requests = await _odooService.getLeaveRequests();

      // Count requests that are in pending states (draft, confirm, validate1)
      final pendingStates = ['draft', 'confirm', 'validate1'];
      final pendingCount = requests.where((request) {
        final state = request['state']?.toString().toLowerCase() ?? '';
        return pendingStates.contains(state);
      }).length;

      if (mounted) {
        setState(() {
          _pendingLeaveRequestsCount = pendingCount;
          _isLoadingLeaveRequests = false;
        });
      }
    } catch (e) {
      print('Error loading pending leave requests count: $e');
      if (mounted) {
        setState(() {
          _isLoadingLeaveRequests = false;
        });
      }
    }
  }

  String _formatHours(double hours) {
    if (hours == 0) return '0h';

    final wholeHours = hours.toInt();
    final minutes = ((hours - wholeHours) * 60).round();

    if (minutes == 0) {
      return '${wholeHours}h';
    } else {
      return '${wholeHours}h ${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      key: _scaffoldKey,
      drawer: const EmployeeDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF000B58), // Deep navy blue
              Color(0xFF35BF8C), // Teal green
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              DashboardHeader(
                menuRoute: '/employee-menu',
                buildProfileAvatar: (user) => Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFf5576c).withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _buildEmployeeProfileAvatar(user),
                  ),
                ),
              ),

              // Last Notification Widget
              LastNotificationWidget(
                notification: _lastNotification,
                isLoading: _isLoadingLastNotification,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              const SizedBox(height: 16),

              // Metrics Cards Grid
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = ResponsiveHelper.isTablet(context);
                    final isDesktop = ResponsiveHelper.isDesktop(context);
                    final crossAxisCount = ResponsiveHelper.gridColumns(context);

                    // Use GridView for tablets/desktop, Row-based layout for mobile
                    if (isTablet || isDesktop) {
                      return SingleChildScrollView(
                        padding: ResponsiveHelper.responsivePadding(context),
                        child: Consumer<LeaveProvider>(
                          builder: (context, leaveProvider, child) {
                            // Calculate total remaining days from balance
                            String totalDays = '-';
                            if (leaveProvider.leaveBalance != null &&
                                leaveProvider.leaveBalance!.isNotEmpty) {
                              double total = 0;
                              leaveProvider.leaveBalance!.forEach((key, value) {
                                if (value is num) {
                                  total += value.toDouble();
                                }
                              });
                              totalDays = total.toStringAsFixed(0);
                            }

                            return GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: ResponsiveHelper.responsiveSpacing(context, mobile: 12),
                              mainAxisSpacing: ResponsiveHelper.responsiveSpacing(context, mobile: 12),
                              childAspectRatio: 0.85,
                              children: [
                                _buildMetricCard(
                                  title: localizations.translate('leave_balance_remaining'),
                                  value: totalDays,
                                  subtitle: localizations.translate('days_available'),
                                  color: const Color(0xFF35BF8C),
                                  chart: _buildBarChart(),
                                  onTap: () {
                                    Navigator.pushNamed(context, '/leave-balance');
                                  },
                                ),
                                _buildMetricCard(
                                  title: localizations.translate('requests_status'),
                                  subtitle: localizations.translate('in_progress'),
                                  value: _isLoadingLeaveRequests
                                      ? '...'
                                      : _pendingLeaveRequestsCount.toString(),
                                  color: const Color(0xFF8B5CF6),
                                  chart: _pendingLeaveRequestsCount > 0
                                      ? _buildCircularProgress(
                                          _pendingLeaveRequestsCount > 10
                                              ? 1.0
                                              : _pendingLeaveRequestsCount / 10)
                                      : _buildCircularProgress(0.0),
                                  onTap: () {
                                    Navigator.pushNamed(context, '/employee-leave-requests');
                                  },
                                ),
                                _buildNotificationCard(
                                  title: localizations.translate('hr_notifications'),
                                  value: _isLoadingNotifications
                                      ? '-'
                                      : _unreadCount.toString(),
                                  subtitle: localizations.translate('unread'),
                                  color: const Color(0xFF000B58),
                                  onTap: () {
                                    Navigator.pushNamed(context, '/employee-notifications');
                                  },
                                ),
                                _buildMetricCard(
                                  title: localizations.translate('working_period'),
                                  value: _isLoadingWeeklyHours
                                      ? '...'
                                      : _formatHours(_weeklyHours),
                                  subtitle: localizations.translate('approved_this_week'),
                                  color: Colors.white,
                                  textColor: Colors.black87,
                                  chart: _buildLineChart(),
                                  onTap: () {
                                    Navigator.pushNamed(context, '/work-time-statistics');
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    } else {
                      // Mobile layout - keep existing Row-based layout
                      return SingleChildScrollView(
                        padding: ResponsiveHelper.responsivePadding(context),
                        child: Column(
                          children: [
                            // Top Row Cards
                            Row(
                              children: [
                                Expanded(
                                  child: Consumer<LeaveProvider>(
                                    builder: (context, leaveProvider, child) {
                                      // Calculate total remaining days from balance
                                      String totalDays = '-';
                                      if (leaveProvider.leaveBalance != null &&
                                          leaveProvider.leaveBalance!.isNotEmpty) {
                                        double total = 0;
                                        leaveProvider.leaveBalance!
                                            .forEach((key, value) {
                                          if (value is num) {
                                            total += value.toDouble();
                                          }
                                        });
                                        totalDays = total.toStringAsFixed(0);
                                      }

                                      return _buildMetricCard(
                                        title: localizations
                                            .translate('leave_balance_remaining'),
                                        value: totalDays,
                                        subtitle:
                                            localizations.translate('days_available'),
                                        color: const Color(0xFF35BF8C),
                                        chart: _buildBarChart(),
                                        onTap: () {
                                          Navigator.pushNamed(
                                              context, '/leave-balance');
                                        },
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 12)),
                                Expanded(
                                  child: _buildMetricCard(
                                    title: localizations.translate('requests_status'),
                                    subtitle: localizations.translate('in_progress'),
                                    value: _isLoadingLeaveRequests
                                        ? '...'
                                        : _pendingLeaveRequestsCount.toString(),
                                    color: const Color(0xFF8B5CF6),
                                    chart: _pendingLeaveRequestsCount > 0
                                        ? _buildCircularProgress(
                                            _pendingLeaveRequestsCount > 10
                                                ? 1.0
                                                : _pendingLeaveRequestsCount / 10)
                                        : _buildCircularProgress(0.0),
                                    onTap: () {
                                      Navigator.pushNamed(
                                          context, '/employee-leave-requests');
                                    },
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 12)),

                            // Bottom Row Cards
                            Row(
                              children: [
                                Expanded(
                                  child: _buildNotificationCard(
                                    title:
                                        localizations.translate('hr_notifications'),
                                    value: _isLoadingNotifications
                                        ? '-'
                                        : _unreadCount.toString(),
                                    subtitle: localizations.translate('unread'),
                                    color: const Color(0xFF000B58),
                                    onTap: () {
                                      Navigator.pushNamed(
                                          context, '/employee-notifications');
                                    },
                                  ),
                                ),
                                SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 12)),
                                Expanded(
                                  child: _buildMetricCard(
                                    title: localizations.translate('working_period'),
                                    value: _isLoadingWeeklyHours
                                        ? '...'
                                        : _formatHours(_weeklyHours),
                                    subtitle:
                                        localizations.translate('approved_this_week'),
                                    color: Colors.white,
                                    textColor: Colors.black87,
                                    chart: _buildLineChart(),
                                    onTap: () {
                                      Navigator.pushNamed(
                                          context, '/work-time-statistics');
                                    },
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 24)),

                            // Team Statistics Section
                            Container(
                              padding: ResponsiveHelper.responsivePadding(context),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  ResponsiveHelper.responsiveBorderRadius(context, mobile: 16.0, tablet: 20.0),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        localizations.translate('team_statistics'),
                                        style: TextStyle(
                                          fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 20.0, tablet: 24.0),
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        '< ${localizations.translate('filter')}',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 16.0, tablet: 18.0),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 16)),
                                  // Team members placeholder
                                  Container(
                                    height: ResponsiveHelper.responsiveValue(context, mobile: 120.0, tablet: 160.0),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.responsiveBorderRadius(context, mobile: 12.0, tablet: 16.0),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        localizations.translate('team_statistics_data'),
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 16.0, tablet: 18.0),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 20)),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    String? value,
    String? subtitle,
    required Color color,
    required Widget chart,
    Color textColor = Colors.white,
    VoidCallback? onTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = ResponsiveHelper.isTablet(context);
        final isDesktop = ResponsiveHelper.isDesktop(context);
        
        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: isTablet || isDesktop ? null : 180,
            padding: EdgeInsets.all(
              ResponsiveHelper.responsiveValue(context, mobile: 14.0, tablet: 20.0, desktop: 24.0),
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.responsiveBorderRadius(context, mobile: 16.0, tablet: 20.0, desktop: 24.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 15.0, tablet: 18.0, desktop: 20.0),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: ResponsiveHelper.responsiveValue(context, mobile: 6.0, tablet: 8.0)),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textColor.withOpacity(0.8),
                      fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 12.0, tablet: 14.0, desktop: 16.0),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                SizedBox(height: ResponsiveHelper.responsiveValue(context, mobile: 6.0, tablet: 8.0)),
                if (value != null)
                  Text(
                    value,
                    style: TextStyle(
                      color: textColor,
                      fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 28.0, tablet: 36.0, desktop: 44.0),
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const Spacer(),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: ResponsiveHelper.responsiveValue(context, mobile: 45.0, tablet: 60.0),
                    child: chart,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBarChart() {
    return CustomPaint(
      painter: BarChartPainter(),
      size: const Size(double.infinity, 60),
    );
  }

  Widget _buildCircularProgress(double progress) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    return CustomPaint(
      painter: LineChartPainter(),
      size: const Size(double.infinity, 60),
    );
  }

  Widget _buildNotificationCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = ResponsiveHelper.isTablet(context);
        final isDesktop = ResponsiveHelper.isDesktop(context);
        
        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: isTablet || isDesktop ? null : 180,
            padding: EdgeInsets.all(
              ResponsiveHelper.responsiveValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0),
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.responsiveBorderRadius(context, mobile: 16.0, tablet: 20.0, desktop: 24.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Text content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 16.0, tablet: 18.0, desktop: 20.0),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: ResponsiveHelper.responsiveValue(context, mobile: 8.0, tablet: 10.0)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 12.0, tablet: 14.0, desktop: 16.0),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: ResponsiveHelper.responsiveValue(context, mobile: 8.0, tablet: 10.0)),
                    Text(
                      value,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 28.0, tablet: 36.0, desktop: 44.0),
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                // Icon in top end (adapts to LTR/RTL)
                PositionedDirectional(
                  top: 0,
                  end: 0,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.notifications_active,
                        size: ResponsiveHelper.responsiveIconSize(context, mobile: 32.0, tablet: 40.0, desktop: 48.0),
                        color: Colors.white.withOpacity(0.9),
                      ),
                      // Notification badge indicator
                      if (value != '0' && value != '-')
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: ResponsiveHelper.responsiveValue(context, mobile: 8.0, tablet: 10.0),
                            height: ResponsiveHelper.responsiveValue(context, mobile: 8.0, tablet: 10.0),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
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
    );
  }

  Widget _buildEmployeeProfileAvatar(UserModel? user) {
    if (user?.profileImage != null && user!.profileImage!.isNotEmpty) {
      try {
        final imageBytes = base64Decode(user.profileImage!);
        return Image.memory(
          imageBytes,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildEmployeeDefaultAvatar();
          },
        );
      } catch (e) {
        print('Employee Avatar - Error decoding image: $e');
      }
    }

    return _buildEmployeeDefaultAvatar();
  }

  Widget _buildEmployeeDefaultAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 28),
    );
  }
}

// Custom Painters for Charts
class BarChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final barWidth = size.width / 6;
    final barHeights = [0.4, 0.6, 0.3, 0.8, 0.5, 0.7];

    for (int i = 0; i < barHeights.length; i++) {
      final rect = Rect.fromLTWH(
        i * barWidth + 4,
        size.height * (1 - barHeights[i]),
        barWidth - 8,
        size.height * barHeights[i],
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final points = [
      Offset(0, size.height * 0.7),
      Offset(size.width * 0.2, size.height * 0.5),
      Offset(size.width * 0.4, size.height * 0.8),
      Offset(size.width * 0.6, size.height * 0.4),
      Offset(size.width * 0.8, size.height * 0.6),
      Offset(size.width, size.height * 0.3),
    ];

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);

    // Draw bars in background
    final barPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 5; i++) {
      final barHeight = [0.3, 0.5, 0.2, 0.7, 0.4][i];
      final rect = Rect.fromLTWH(
        i * (size.width / 5) + 5,
        size.height * (1 - barHeight),
        (size.width / 5) - 10,
        size.height * barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
