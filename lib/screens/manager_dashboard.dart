import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/manager_drawer.dart';
import '../services/odoo_service.dart';
import '../utils/app_localizations.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/providers/dashboard_provider.dart';
import '../services/user_service.dart';
import '../data/models/user_model.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // Load data only if not already cached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadTeamData();
    });
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
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Hamburger Menu with modern design
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(
                                  context, '/manager-menu');
                            },
                            icon: const Icon(
                              Icons.menu,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Title
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localizations.translate('manager_dashboard'),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                authProvider.user?.name ?? 'Manager',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Profile Picture with glow effect
                        StreamBuilder<UserModel?>(
                          stream: UserService.instance.userStream,
                          initialData: UserService.instance.currentUser,
                          builder: (context, snapshot) {
                            return InkWell(
                              onTap: () => Navigator.pushNamed(
                                  context, '/personal-info'),
                              borderRadius: BorderRadius.circular(25),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFf093fb),
                                      Color(0xFFf5576c)
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFf5576c)
                                          .withOpacity(0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child:
                                      _buildManagerProfileAvatar(snapshot.data),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

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
                            onRefresh: () => dashboardProvider.refreshData(),
                            color: const Color(0xFF667eea),
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Section Title
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Row(
                                      children: [
                                        Text(
                                          localizations
                                              .translate('team_management'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
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
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: 1.0,
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
                                        const Color(0xFFF59E0B),
                                        const Color(0xFFD97706),
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

                                  const SizedBox(height: 24),

                                  // Team Activity Section with modern card
                                  _buildModernActivityCard(
                                      localizations, dashboardProvider),

                                  const SizedBox(height: 20),

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

                                  const SizedBox(height: 20),
                                ],
                              ),
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
    // Detect screen size for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [startColor, endColor],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: startColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon at the top-left
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: isSmallScreen ? 20 : 26,
                  ),
                ),
                // Flexible spacing
                SizedBox(height: isSmallScreen ? 8 : 12),
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
                            fontSize: isSmallScreen ? 24 : 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 4 : 6),
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 12,
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
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  localizations.translate('team_activity'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2d3436),
                  ),
                ),
              ),
              if (pendingRequests.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
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
          const SizedBox(height: 20),
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
            const Color(0xFFF59E0B).withOpacity(0.1),
            const Color(0xFFD97706).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.2),
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
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
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
                    colors: [Color(0xFF000B58), Color(0xFF000B58)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.groups,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  localizations.translate('team_members'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2d3436),
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
          const SizedBox(height: 20),
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
