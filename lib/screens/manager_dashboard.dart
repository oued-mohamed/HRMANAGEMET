import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/hr_drawer.dart';
import '../services/odoo_service.dart';
import '../utils/app_localizations.dart';
import '../presentation/providers/auth_provider.dart';
import 'package:intl/intl.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? _teamStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }

  Future<void> _loadTeamData() async {
    try {
      setState(() => _isLoading = true);

      // Debug employee hierarchy first
      await OdooService().debugEmployeeHierarchy();

      // Debug Othman configuration specifically
      await OdooService().debugOthmanConfiguration();

      final stats = await OdooService().getTeamStatistics();
      print('Team stats loaded: ${stats.keys}');
      print('Pending requests type: ${stats['pending_requests'].runtimeType}');
      print('Team members type: ${stats['team_members'].runtimeType}');

      // Additional debugging
      if (stats['team_members'] is List) {
        print('Team members count: ${(stats['team_members'] as List).length}');
        for (int i = 0; i < (stats['team_members'] as List).length; i++) {
          final member = (stats['team_members'] as List)[i];
          print('Team member $i: ${member.runtimeType} - $member');
        }
      }

      if (stats['pending_requests'] is List) {
        print(
            'Pending requests count: ${(stats['pending_requests'] as List).length}');
        for (int i = 0; i < (stats['pending_requests'] as List).length; i++) {
          final request = (stats['pending_requests'] as List)[i];
          print('Pending request $i: ${request.runtimeType} - $request');
        }
      }

      setState(() {
        _teamStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading team data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      key: _scaffoldKey,
      drawer: const HRDrawer(),
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
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                        icon: const Icon(
                          Icons.menu_rounded,
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
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            authProvider.user?.name ?? 'Manager',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Profile Picture with glow effect
                    InkWell(
                      onTap: () => Navigator.pushNamed(context, '/profile'),
                      borderRadius: BorderRadius.circular(25),
                      child: Container(
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
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
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
                        onRefresh: _loadTeamData,
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
                                    Container(
                                      width: 4,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      localizations
                                          .translate('team_management'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
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
                                crossAxisCount: 2,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 1.1,
                                children: [
                                  _buildModernStatCard(
                                    localizations.translate('team_size'),
                                    '${_teamStats?['team_size'] ?? 0}',
                                    Icons.people_rounded,
                                    const Color(0xFF000B58),
                                    const Color(0xFF000B58),
                                    localizations,
                                  ),
                                  _buildModernStatCard(
                                    localizations
                                        .translate('pending_approvals'),
                                    '${_teamStats?['pending_approvals'] ?? 0}',
                                    Icons.pending_actions_rounded,
                                    const Color(0xFFF59E0B),
                                    const Color(0xFFD97706),
                                    localizations,
                                  ),
                                  _buildModernStatCard(
                                    localizations
                                        .translate('approved_this_week'),
                                    '${_teamStats?['approved_this_week'] ?? 0}',
                                    Icons.check_circle_rounded,
                                    const Color(0xFF35BF8C),
                                    const Color(0xFF059669),
                                    localizations,
                                  ),
                                  _buildModernStatCard(
                                    localizations
                                        .translate('team_productivity'),
                                    '${_teamStats?['team_productivity'] ?? 0}%',
                                    Icons.trending_up_rounded,
                                    const Color(0xFF8B5CF6),
                                    const Color(0xFF7C3AED),
                                    localizations,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // Team Activity Section with modern card
                              _buildModernActivityCard(localizations),

                              const SizedBox(height: 20),

                              // Team Members Section
                              if (_teamStats?['team_members'] != null &&
                                  (_teamStats!['team_members'] as List)
                                      .isNotEmpty)
                                _buildModernTeamMembersCard(localizations),

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernStatCard(
    String title,
    String value,
    IconData icon,
    Color startColor,
    Color endColor,
    AppLocalizations localizations,
  ) {
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
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernActivityCard(AppLocalizations localizations) {
    // Safely extract pending requests
    final rawRequests = _teamStats?['pending_requests'];
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
                  Icons.notifications_active_rounded,
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
                      Icons.check_circle_outline_rounded,
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

  Widget _buildModernTeamMembersCard(AppLocalizations localizations) {
    // Safely extract team members
    final rawMembers = _teamStats?['team_members'];
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
                  Icons.groups_rounded,
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
                      Icons.people_outline_rounded,
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
        _loadTeamData();
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
        _loadTeamData();
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
}
