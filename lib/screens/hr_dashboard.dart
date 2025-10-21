import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/company_provider.dart';
import '../widgets/hr_drawer.dart';
import '../services/user_service.dart';
import '../data/models/user_model.dart';
import 'dart:convert';

class HRDashboard extends StatefulWidget {
  const HRDashboard({super.key});

  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const HRDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E), // Dark navy
              Color(0xFF16213E), // Darker blue
              Color(0xFF0F3460), // Medium blue
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Modern App Bar
                  SliverAppBar(
                    expandedHeight: 120,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                        icon: const Icon(
                          Icons.menu_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Consumer<CompanyProvider>(
                                builder: (context, companyProvider, child) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        'HR Dashboard',
                                        style: TextStyle(
                                          fontSize: isDesktop ? 32 : 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                          shadows: [
                                            Shadow(
                                              color:
                                                  Colors.black.withOpacity(0.3),
                                              offset: const Offset(0, 2),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        companyProvider.currentCompany?.name ??
                                            'Company',
                                        style: TextStyle(
                                          fontSize: isDesktop ? 16 : 14,
                                          color: Colors.white.withOpacity(0.8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            StreamBuilder<UserModel?>(
                              stream: UserService.instance.userStream,
                              initialData: UserService.instance.currentUser,
                              builder: (context, snapshot) {
                                return GestureDetector(
                                  onTap: () => Navigator.pushNamed(
                                      context, '/personal-info'),
                                  child: Container(
                                    width: isDesktop ? 60 : 50,
                                    height: isDesktop ? 60 : 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF667eea),
                                          Color(0xFF764ba2)
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 15,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: _buildProfileAvatar(snapshot.data),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Content
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 24 : 16,
                      vertical: 16,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Welcome Card
                        _buildWelcomeCard(isDesktop),

                        const SizedBox(height: 24),

                        // Quick Actions
                        _buildQuickActionsSection(isTablet, isDesktop),

                        const SizedBox(height: 32),

                        // Statistics Cards
                        _buildStatisticsSection(isTablet, isDesktop),

                        const SizedBox(height: 32),

                        // Recent Activity
                        _buildActivitySection(isDesktop),

                        const SizedBox(height: 24),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 28 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back! 👋',
                  style: TextStyle(
                    fontSize: isDesktop ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage your team efficiently with our HR tools',
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.dashboard_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(bool isTablet, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: isDesktop ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isDesktop ? 4 : (isTablet ? 3 : 2),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: isDesktop ? 1.1 : 1.0,
          children: [
            _buildActionCard(
              'Pending Approvals',
              Icons.approval_rounded,
              const Color(0xFFFF6B6B),
              '5',
              () => _navigateToApprovals(context),
              isDesktop,
            ),
            _buildActionCard(
              'Manage Employees',
              Icons.people_rounded,
              const Color(0xFF4ECDC4),
              '24',
              () => _navigateToEmployees(context),
              isDesktop,
            ),
            _buildActionCard(
              'Reports',
              Icons.analytics_rounded,
              const Color(0xFF45B7D1),
              '',
              () => _navigateToReports(context),
              isDesktop,
            ),
            _buildActionCard(
              'Settings',
              Icons.settings_rounded,
              const Color(0xFF96CEB4),
              '',
              () => _navigateToSettings(context),
              isDesktop,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    String count,
    VoidCallback onTap,
    bool isDesktop,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(isDesktop ? 20 : 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Container(
                    width: isDesktop ? 50 : 40,
                    height: isDesktop ? 50 : 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: isDesktop ? 24 : 20,
                    ),
                  ),
                  if (count.isNotEmpty)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          count,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: isDesktop ? 12 : 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: isDesktop ? 14 : 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(bool isTablet, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistics Overview',
          style: TextStyle(
            fontSize: isDesktop ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 2),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: isDesktop ? 1.2 : 1.1,
          children: [
            _buildStatCard(
              'Total Employees',
              '24',
              Icons.people_rounded,
              const Color(0xFF4ECDC4),
              '+12%',
              isDesktop,
            ),
            _buildStatCard(
              'Pending Leaves',
              '8',
              Icons.event_available_rounded,
              const Color(0xFFFF6B6B),
              '-3%',
              isDesktop,
            ),
            _buildStatCard(
              'Approved This Month',
              '15',
              Icons.check_circle_rounded,
              const Color(0xFF96CEB4),
              '+8%',
              isDesktop,
            ),
            _buildStatCard(
              'Rejected This Month',
              '2',
              Icons.cancel_rounded,
              const Color(0xFFFFB6C1),
              '-1%',
              isDesktop,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String trend,
    bool isDesktop,
  ) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: isDesktop ? 50 : 40,
                height: isDesktop ? 50 : 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: isDesktop ? 24 : 20,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: trend.startsWith('+')
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    fontSize: isDesktop ? 12 : 10,
                    fontWeight: FontWeight.bold,
                    color: trend.startsWith('+') ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          Text(
            value,
            style: TextStyle(
              fontSize: isDesktop ? 32 : 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: isDesktop ? 8 : 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isDesktop ? 14 : 12,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: isDesktop ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(isDesktop ? 24 : 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildActivityItem(
                'Leave request from John Doe',
                'Annual leave for Dec 20-25',
                Icons.event_available_rounded,
                const Color(0xFFFF6B6B),
                '2 hours ago',
                'Pending',
                isDesktop,
              ),
              const SizedBox(height: 16),
              _buildActivityItem(
                'Leave approved for Sarah',
                'Sick leave for Nov 15',
                Icons.check_circle_rounded,
                const Color(0xFF96CEB4),
                '1 day ago',
                'Approved',
                isDesktop,
              ),
              const SizedBox(height: 16),
              _buildActivityItem(
                'New employee added',
                'Mike Johnson - Developer',
                Icons.person_add_rounded,
                const Color(0xFF4ECDC4),
                '2 days ago',
                'Completed',
                isDesktop,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String time,
    String status,
    bool isDesktop,
  ) {
    return Row(
      children: [
        Container(
          width: isDesktop ? 50 : 40,
          height: isDesktop ? 50 : 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: isDesktop ? 24 : 20,
          ),
        ),
        SizedBox(width: isDesktop ? 16 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: isDesktop ? 14 : 12,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: TextStyle(
                fontSize: isDesktop ? 14 : 12,
                color: Colors.white.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 10 : 8,
                vertical: isDesktop ? 4 : 2,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: isDesktop ? 12 : 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileAvatar(UserModel? user) {
    if (user?.profileImage != null && user!.profileImage!.isNotEmpty) {
      try {
        final imageBytes = base64Decode(user.profileImage!);
        return Image.memory(
          imageBytes,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultAvatar();
          },
        );
      } catch (e) {
        print('HR Dashboard Avatar - Error decoding image: $e');
      }
    }

    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 28),
    );
  }

  void _navigateToApprovals(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Leave approvals screen - Coming soon'),
        backgroundColor: const Color(0xFF667eea),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _navigateToEmployees(BuildContext context) {
    Navigator.pushNamed(context, '/hr-employees');
  }

  void _navigateToReports(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Reports screen - Coming soon'),
        backgroundColor: const Color(0xFF667eea),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _navigateToSettings(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Settings screen - Coming soon'),
        backgroundColor: const Color(0xFF667eea),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
