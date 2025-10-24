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
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 900;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;

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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // Modern App Bar
                      SliverAppBar(
                        expandedHeight:
                            isVerySmallScreen ? 80 : (isSmallScreen ? 90 : 100),
                        floating: false,
                        pinned: true,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        leading: Container(
                          margin: EdgeInsets.all(isVerySmallScreen ? 4 : 6),
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
                            icon: Icon(
                              Icons.menu_rounded,
                              color: Colors.white,
                              size: isVerySmallScreen ? 18 : 22,
                            ),
                          ),
                        ),
                        flexibleSpace: FlexibleSpaceBar(
                          background: Container(
                            padding: EdgeInsets.fromLTRB(
                                20,
                                isVerySmallScreen
                                    ? 35
                                    : (isSmallScreen ? 40 : 45),
                                20,
                                isVerySmallScreen ? 8 : 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Consumer<CompanyProvider>(
                                    builder: (context, companyProvider, child) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            'HR Dashboard',
                                            style: TextStyle(
                                              fontSize: isVerySmallScreen
                                                  ? 16
                                                  : (isSmallScreen
                                                      ? 20
                                                      : (isDesktop ? 28 : 24)),
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black
                                                      .withOpacity(0.3),
                                                  offset: const Offset(0, 2),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                              height:
                                                  isVerySmallScreen ? 1 : 2),
                                          Text(
                                            companyProvider
                                                    .currentCompany?.name ??
                                                'Company',
                                            style: TextStyle(
                                              fontSize: isVerySmallScreen
                                                  ? 10
                                                  : (isSmallScreen
                                                      ? 11
                                                      : (isDesktop ? 14 : 12)),
                                              color:
                                                  Colors.white.withOpacity(0.8),
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
                                        width: isVerySmallScreen
                                            ? 32
                                            : (isSmallScreen
                                                ? 36
                                                : (isDesktop ? 50 : 40)),
                                        height: isVerySmallScreen
                                            ? 32
                                            : (isSmallScreen
                                                ? 36
                                                : (isDesktop ? 50 : 40)),
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
                                              color:
                                                  Colors.black.withOpacity(0.3),
                                              blurRadius: 15,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                          border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.3),
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: _buildProfileAvatar(
                                              snapshot.data),
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
                          vertical:
                              isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8),
                        ),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // Welcome Card
                            _buildWelcomeCard(isDesktop),

                            SizedBox(
                                height: isVerySmallScreen
                                    ? 8
                                    : (isSmallScreen ? 12 : 16)),

                            // Quick Actions
                            _buildQuickActionsSection(isTablet, isDesktop),

                            SizedBox(
                                height: isVerySmallScreen
                                    ? 12
                                    : (isSmallScreen ? 16 : 20)),

                            // Statistics Cards
                            _buildStatisticsSection(isTablet, isDesktop),

                            SizedBox(
                                height: isVerySmallScreen
                                    ? 12
                                    : (isSmallScreen ? 16 : 20)),

                            // Recent Activity
                            _buildActivitySection(isDesktop),

                            // Add bottom padding to prevent overflow
                            SizedBox(
                                height: MediaQuery.of(context).padding.bottom +
                                    (isVerySmallScreen
                                        ? 20
                                        : (isSmallScreen ? 30 : 40))),
                          ]),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(bool isDesktop) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;

    return Container(
      padding: EdgeInsets.all(isVerySmallScreen
          ? 12
          : (isSmallScreen ? 16 : (isDesktop ? 20 : 18))),
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
                    fontSize: isVerySmallScreen
                        ? 18
                        : (isSmallScreen ? 22 : (isDesktop ? 28 : 24)),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(
                    height: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
                Text(
                  'Manage your team efficiently with our HR tools',
                  style: TextStyle(
                    fontSize: isVerySmallScreen
                        ? 12
                        : (isSmallScreen ? 13 : (isDesktop ? 16 : 14)),
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(
                isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.dashboard_rounded,
              color: Colors.white,
              size: isVerySmallScreen
                  ? 20
                  : (isSmallScreen ? 24 : (isDesktop ? 32 : 28)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(bool isTablet, bool isDesktop) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: isVerySmallScreen
                ? 18
                : (isSmallScreen ? 20 : (isDesktop ? 24 : 20)),
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12)),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isDesktop ? 4 : (isTablet ? 3 : 2),
          mainAxisSpacing: isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12),
          crossAxisSpacing: isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12),
          childAspectRatio: isDesktop
              ? 1.4
              : (isVerySmallScreen ? 1.6 : (isSmallScreen ? 1.5 : 1.3)),
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
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(isDesktop
              ? 14
              : (isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12))),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Container(
                    width: isDesktop
                        ? 40
                        : (isVerySmallScreen ? 28 : (isSmallScreen ? 32 : 36)),
                    height: isDesktop
                        ? 40
                        : (isVerySmallScreen ? 28 : (isSmallScreen ? 32 : 36)),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: isDesktop
                          ? 20
                          : (isVerySmallScreen
                              ? 14
                              : (isSmallScreen ? 16 : 18)),
                    ),
                  ),
                  if (count.isNotEmpty)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: EdgeInsets.all(
                            isVerySmallScreen ? 1 : (isSmallScreen ? 2 : 3)),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: BoxConstraints(
                          minWidth: isVerySmallScreen
                              ? 14
                              : (isSmallScreen ? 16 : 18),
                          minHeight: isVerySmallScreen
                              ? 14
                              : (isSmallScreen ? 16 : 18),
                        ),
                        child: Text(
                          count,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize:
                                isVerySmallScreen ? 7 : (isSmallScreen ? 8 : 9),
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(
                  height: isDesktop
                      ? 8
                      : (isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 7))),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isDesktop
                        ? 12
                        : (isVerySmallScreen ? 9 : (isSmallScreen ? 10 : 11)),
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(bool isTablet, bool isDesktop) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistics Overview',
          style: TextStyle(
            fontSize: isVerySmallScreen
                ? 18
                : (isSmallScreen ? 20 : (isDesktop ? 24 : 20)),
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12)),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 2),
          mainAxisSpacing: isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12),
          crossAxisSpacing: isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12),
          childAspectRatio: isDesktop
              ? 1.6
              : (isVerySmallScreen ? 1.8 : (isSmallScreen ? 1.7 : 1.5)),
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
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;

    return Container(
      padding: EdgeInsets.all(
          isDesktop ? 16 : (isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12))),
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
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: isDesktop
                    ? 40
                    : (isVerySmallScreen ? 28 : (isSmallScreen ? 32 : 36)),
                height: isDesktop
                    ? 40
                    : (isVerySmallScreen ? 28 : (isSmallScreen ? 32 : 36)),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: isDesktop
                      ? 20
                      : (isVerySmallScreen ? 14 : (isSmallScreen ? 16 : 18)),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8),
                    vertical: isVerySmallScreen ? 1 : (isSmallScreen ? 2 : 4)),
                decoration: BoxDecoration(
                  color: trend.startsWith('+')
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    fontSize: isDesktop
                        ? 10
                        : (isVerySmallScreen ? 7 : (isSmallScreen ? 8 : 9)),
                    fontWeight: FontWeight.bold,
                    color: trend.startsWith('+') ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
              height: isDesktop
                  ? 12
                  : (isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 10))),
          Text(
            value,
            style: TextStyle(
              fontSize: isDesktop
                  ? 24
                  : (isVerySmallScreen ? 18 : (isSmallScreen ? 20 : 22)),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(
              height: isDesktop
                  ? 6
                  : (isVerySmallScreen ? 3 : (isSmallScreen ? 4 : 5))),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: isDesktop
                    ? 12
                    : (isVerySmallScreen ? 9 : (isSmallScreen ? 10 : 11)),
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(bool isDesktop) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: isVerySmallScreen
                ? 18
                : (isSmallScreen ? 20 : (isDesktop ? 24 : 20)),
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12)),
        Container(
          padding: EdgeInsets.all(isVerySmallScreen
              ? 12
              : (isSmallScreen ? 14 : (isDesktop ? 20 : 16))),
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
              const SizedBox(height: 12),
              _buildActivityItem(
                'Leave approved for Sarah',
                'Sick leave for Nov 15',
                Icons.check_circle_rounded,
                const Color(0xFF96CEB4),
                '1 day ago',
                'Approved',
                isDesktop,
              ),
              const SizedBox(height: 12),
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
