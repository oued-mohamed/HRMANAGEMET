import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../widgets/manager_drawer.dart';
import '../widgets/last_notification_widget.dart';
import '../services/odoo_service.dart';
import '../utils/app_localizations.dart';
import '../utils/responsive_helper.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/providers/dashboard_provider.dart';
import '../data/models/user_model.dart';
import '../widgets/dashboard_header.dart';
import 'dart:convert';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final OdooService _odooService = OdooService();

  Map<String, dynamic>? _lastNotification;
  bool _isLoadingLastNotification = true;

  static Map<String, dynamic>? _cachedNotification;
  static DateTime? _cachedNotificationAt;
  static const Duration _notificationCacheDuration = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    // Load data only if not already cached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadTeamData();
      _loadNotifications();
    });
  }

  Future<void> _loadNotifications({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedNotification != null &&
        _cachedNotificationAt != null &&
        DateTime.now().difference(_cachedNotificationAt!) <
            _notificationCacheDuration) {
      if (!mounted) return;
      setState(() {
        _lastNotification = _cachedNotification;
        _isLoadingLastNotification = false;
      });
      return;
    }

    final bool showLoader = _lastNotification == null;
    if (showLoader && mounted) {
      setState(() {
        _isLoadingLastNotification = true;
      });
    }

    try {
      final notifications = await _odooService.getUnreadNotifications();
      print('Manager - Loaded ${notifications.length} notifications');

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

      final latestNotification =
          sortedNotifications.isNotEmpty ? sortedNotifications.first : null;

      _cachedNotification = latestNotification != null
          ? Map<String, dynamic>.from(latestNotification)
          : null;
      _cachedNotificationAt = DateTime.now();

      if (!mounted) return;
      setState(() {
        _lastNotification = latestNotification;
        _isLoadingLastNotification = false;
      });
    } catch (e) {
      print('Error loading notifications for manager dashboard: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingLastNotification = false;
        if (forceRefresh) {
          _lastNotification = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      key: _scaffoldKey,
      drawer: const ManagerDrawer(),
      body: Consumer<DashboardProvider>(
        builder: (context, dashboardProvider, child) {
          return Container(
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
                  // Modern Header Section
                  DashboardHeader(
                    menuRoute: '/manager-menu',
                    fallbackName: authProvider.user?.name ?? 'Manager',
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
                        child: _buildManagerProfileAvatar(user),
                      ),
                    ),
                  ),

                  // Last Notification Widget
                  LastNotificationWidget(
                    notification: _lastNotification,
                    isLoading: _isLoadingLastNotification,
                    notificationsRoute: '/manager-notifications',
                    margin: EdgeInsets.symmetric(
                      horizontal: ResponsiveHelper.responsiveValue(context, mobile: 16.0, tablet: 24.0),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 16)),

                  // Content
                  Expanded(
                    child: dashboardProvider.isLoading
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                  strokeWidth: 3,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  localizations.translate('loading'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              await Future.wait([
                                dashboardProvider.refreshData(),
                                _loadNotifications(forceRefresh: true),
                              ]);
                            },
                            color: const Color(0xFF667eea),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final crossAxisCount = ResponsiveHelper.responsiveValue(
                                  context,
                                  mobile: 2,
                                  tablet: 3,
                                  desktop: 4,
                                );
                                final childAspectRatio = ResponsiveHelper.responsiveValue(
                                  context,
                                  mobile: 1.0,
                                  tablet: 1.1,
                                  desktop: 1.2,
                                );

                                return SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: ResponsiveHelper.responsivePadding(context),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: ResponsiveHelper.responsiveValue(
                                        context,
                                        mobile: double.infinity,
                                        tablet: 1200.0,
                                        desktop: 1400.0,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Section Title
                                        Padding(
                                          padding: EdgeInsets.only(
                                            bottom: ResponsiveHelper.responsiveSpacing(context, mobile: 16),
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                localizations.translate('team_management'),
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: ResponsiveHelper.responsiveFontSize(
                                                    context,
                                                    mobile: 24.0,
                                                    tablet: 28.0,
                                                    desktop: 32.0,
                                                  ),
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Stats Grid with improved design
                                        GridView.count(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          crossAxisCount: crossAxisCount,
                                          mainAxisSpacing: ResponsiveHelper.responsiveSpacing(context, mobile: 16),
                                          crossAxisSpacing: ResponsiveHelper.responsiveSpacing(context, mobile: 16),
                                          childAspectRatio: childAspectRatio,
                                    children: [
                                      _buildModernStatCard(
                                        localizations.translate('team_size'),
                                        '${dashboardProvider.teamStats?['team_size'] ?? 0}',
                                        Icons.people,
                                        const Color(0xFF000B58),
                                        const Color(0xFF000B58),
                                        localizations,
                                        onTap: () {
                                          Navigator.pushNamed(
                                              context, '/manager-employees');
                                        },
                                      ),
                                      _buildModernStatCard(
                                        localizations
                                            .translate('pending_approvals'),
                                        '${dashboardProvider.teamStats?['pending_approvals'] ?? 0}',
                                        Icons.pending_actions,
                                        const Color(0xFF30cfd0),
                                        const Color(0xFF22a3a4),
                                        localizations,
                                        onTap: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/leave-management',
                                            arguments: {
                                              'initialFilter': 'pending',
                                            },
                                          );
                                        },
                                      ),
                                      _buildModernStatCard(
                                        localizations
                                            .translate('approved_this_week'),
                                        '${dashboardProvider.teamStats?['approved_this_week'] ?? 0}',
                                        Icons.check_circle,
                                        const Color(0xFF35BF8C),
                                        const Color(0xFF059669),
                                        localizations,
                                      ),
                                      _buildModernStatCard(
                                        localizations
                                            .translate('team_productivity'),
                                        '${dashboardProvider.teamStats?['team_productivity'] ?? 0}%',
                                        Icons.trending_up,
                                        const Color(0xFF8B5CF6),
                                        const Color(0xFF7C3AED),
                                        localizations,
                                      ),
                                        ],
                                      ),

                                      SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 24)),

                                      // Team Activity Section with modern card
                                      _buildModernActivityCard(
                                          localizations, dashboardProvider),

                                      SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 20)),

                                      // Team Members Section
                                      if (dashboardProvider
                                                  .teamStats?['team_members'] !=
                                              null &&
                                          (dashboardProvider
                                                      .teamStats!['team_members']
                                                  as List)
                                              .isNotEmpty)
                                        _buildModernTeamMembersCard(
                                            localizations, dashboardProvider),

                                      SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 20)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernStatCard(
    String title,
    String value,
    IconData icon,
    Color startColor,
    Color endColor,
    AppLocalizations localizations, {
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [startColor, endColor],
        ),
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.responsiveBorderRadius(context, mobile: 20.0, tablet: 24.0, desktop: 28.0),
        ),
        boxShadow: [
          BoxShadow(
            color: startColor.withOpacity(0.3),
            blurRadius: ResponsiveHelper.responsiveValue(context, mobile: 15.0, tablet: 20.0),
            offset: Offset(0, ResponsiveHelper.responsiveValue(context, mobile: 8.0, tablet: 10.0)),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(
            ResponsiveHelper.responsiveBorderRadius(context, mobile: 20.0, tablet: 24.0, desktop: 28.0),
          ),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(
              ResponsiveHelper.responsiveValue(context, mobile: 12.0, tablet: 16.0, desktop: 20.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon at the top-left
                Container(
                  padding: EdgeInsets.all(
                    ResponsiveHelper.responsiveValue(context, mobile: 6.0, tablet: 8.0, desktop: 10.0),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(
                      ResponsiveHelper.responsiveValue(context, mobile: 10.0, tablet: 12.0),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: ResponsiveHelper.responsiveIconSize(context, mobile: 20.0, tablet: 24.0, desktop: 28.0),
                  ),
                ),
                // Flexible spacing
                SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 8)),
                // Value and title - use Expanded to prevent overflow
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.responsiveFontSize(
                              context,
                              mobile: 24.0,
                              tablet: 28.0,
                              desktop: 32.0,
                            ),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.responsiveValue(context, mobile: 4.0, tablet: 6.0)),
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.responsiveFontSize(
                              context,
                              mobile: 10.0,
                              tablet: 12.0,
                              desktop: 14.0,
                            ),
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
  }

  Widget _buildModernActivityCard(
      AppLocalizations localizations, DashboardProvider dashboardProvider) {
    // Safely extract pending requests
    final rawRequests = dashboardProvider.teamStats?['pending_requests'];
    final List<Map<String, dynamic>> pendingRequests = [];

    if (rawRequests is List) {
      for (var item in rawRequests) {
        if (item is Map<String, dynamic>) {
          pendingRequests.add(item);
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF30cfd0), Color(0xFF22a3a4)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.notifications_active,
                  color: Colors.white,
                  size: ResponsiveHelper.responsiveIconSize(context, mobile: 24.0, tablet: 28.0),
                ),
              ),
              SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 12)),
              Expanded(
                child: Text(
                  localizations.translate('team_activity'),
                  style: TextStyle(
                    fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 20.0, tablet: 24.0, desktop: 28.0),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2d3436),
                  ),
                ),
              ),
              if (pendingRequests.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF30cfd0), Color(0xFF22a3a4)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${pendingRequests.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 20)),
          if (pendingRequests.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No pending approvals',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...pendingRequests.take(5).map((request) =>
                _buildModernLeaveRequestItem(request, localizations)),
        ],
      ),
    );
  }

  Widget _buildModernLeaveRequestItem(
      Map<String, dynamic> request, AppLocalizations localizations) {
    final employeeName = request['employee_id'] is List
        ? request['employee_id'][1].toString()
        : 'Employee';
    final leaveType = request['holiday_status_id'] is List
        ? request['holiday_status_id'][1].toString()
        : 'Leave';
    final days = request['number_of_days']?.toString() ?? '0';
    final dateFrom = request['request_date_from']?.toString() ?? '';
    final dateTo = request['request_date_to']?.toString() ?? '';

    String dateRange = '';
    if (dateFrom.isNotEmpty && dateTo.isNotEmpty) {
      try {
        final from = DateTime.parse(dateFrom.split(' ')[0]);
        final to = DateTime.parse(dateTo.split(' ')[0]);
        dateRange =
            '${DateFormat('MMM dd').format(from)} - ${DateFormat('MMM dd').format(to)}';
      } catch (e) {
        dateRange = dateFrom.split(' ')[0];
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF30cfd0).withOpacity(0.1),
            const Color(0xFF22a3a4).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF30cfd0).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF30cfd0), Color(0xFF22a3a4)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2d3436),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$leaveType - $days ${localizations.translate('days')}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (dateRange.isNotEmpty)
                      Text(
                        dateRange,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approveRequest(request['id']),
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: Text(localizations.translate('approve')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF30cfd0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _rejectRequest(request['id']),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  label: Text(localizations.translate('reject')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444), width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernTeamMembersCard(
      AppLocalizations localizations, DashboardProvider dashboardProvider) {
    // Safely extract team members
    final rawMembers = dashboardProvider.teamStats?['team_members'];
    final List<Map<String, dynamic>> teamMembers = [];

    if (rawMembers is List) {
      for (var item in rawMembers) {
        if (item is Map<String, dynamic>) {
          teamMembers.add(item);
        }
      }
    }

    return Container(
      padding: EdgeInsets.all(
        ResponsiveHelper.responsiveValue(context, mobile: 24.0, tablet: 28.0, desktop: 32.0),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.responsiveBorderRadius(context, mobile: 24.0, tablet: 28.0, desktop: 32.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: ResponsiveHelper.responsiveValue(context, mobile: 20.0, tablet: 24.0),
            offset: Offset(0, ResponsiveHelper.responsiveValue(context, mobile: 10.0, tablet: 12.0)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(
                  ResponsiveHelper.responsiveValue(context, mobile: 10.0, tablet: 12.0),
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF000B58), Color(0xFF000B58)],
                  ),
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.responsiveValue(context, mobile: 12.0, tablet: 14.0),
                  ),
                ),
                child: Icon(
                  Icons.groups,
                  color: Colors.white,
                  size: ResponsiveHelper.responsiveIconSize(context, mobile: 24.0, tablet: 28.0),
                ),
              ),
              SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 12)),
              Expanded(
                child: Text(
                  localizations.translate('team_members'),
                  style: TextStyle(
                    fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 20.0, tablet: 24.0, desktop: 28.0),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2d3436),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF000B58), Color(0xFF000B58)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${teamMembers.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 20)),
          if (teamMembers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No team members',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...teamMembers.map(
                (member) => _buildModernTeamMemberItem(member, localizations)),
        ],
      ),
    );
  }

  Widget _buildModernTeamMemberItem(
      Map<String, dynamic> member, AppLocalizations localizations) {
    final name = member['name']?.toString() ?? 'Employee';
    final jobTitle =
        member['job_id'] is List ? member['job_id'][1].toString() : 'Employee';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF000B58).withOpacity(0.1),
            const Color(0xFF000B58).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF000B58).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF000B58), Color(0xFF000B58)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2d3436),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  jobTitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF30cfd0).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF30cfd0),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  localizations.translate('online'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF30cfd0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveRequest(int leaveId) async {
    try {
      final success = await OdooService().approveLeaveRequest(leaveId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context).translate('approved')),
              ],
            ),
            backgroundColor: const Color(0xFF30cfd0),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        // Update data after approval
        context.read<DashboardProvider>().updateAfterAction();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Text('Error: $e'),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(int leaveId) async {
    try {
      final success = await OdooService().refuseLeaveRequest(leaveId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cancel, color: Colors.white),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context).translate('reject')),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        // Update data after rejection
        context.read<DashboardProvider>().updateAfterAction();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Text('Error: $e'),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Widget _buildManagerProfileAvatar(UserModel? user) {
    if (user?.profileImage != null && user!.profileImage!.isNotEmpty) {
      try {
        final imageBytes = base64Decode(user.profileImage!);
        return Image.memory(
          imageBytes,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildManagerDefaultAvatar();
          },
        );
      } catch (e) {
        print('Manager Avatar - Error decoding image: $e');
      }
    }

    return _buildManagerDefaultAvatar();
  }

  Widget _buildManagerDefaultAvatar() {
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
