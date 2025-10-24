import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/company_provider.dart';
import '../services/user_service.dart';
import '../data/models/user_model.dart';
import '../widgets/hr_drawer.dart';

class HRDashboardNew extends StatefulWidget {
  const HRDashboardNew({super.key});

  @override
  State<HRDashboardNew> createState() => _HRDashboardNewState();
}

class _HRDashboardNewState extends State<HRDashboardNew>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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

    // Responsive breakpoints
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final isDesktop = screenWidth >= 900;
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
              Color(0xFF0F3460), // Deep blue
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Responsive App Bar
                SliverAppBar(
                  expandedHeight:
                      isVerySmallScreen ? 100 : (isSmallScreen ? 110 : 120),
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: _buildMenuButton(isMobile),
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildHeader(isMobile, isTablet, isDesktop,
                        isSmallScreen, isVerySmallScreen),
                  ),
                ),

                // Content
                SliverPadding(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Welcome Card
                      _buildWelcomeCard(
                          isMobile, isTablet, isDesktop, isSmallScreen),
                      SizedBox(height: isSmallScreen ? 16 : 24),

                      // Quick Actions
                      _buildSectionTitle(
                          'Quick Actions', isMobile, isTablet, isDesktop),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      _buildQuickActionsGrid(
                          isMobile, isTablet, isDesktop, isSmallScreen),
                      SizedBox(height: isSmallScreen ? 20 : 32),

                      // Statistics Overview
                      _buildSectionTitle(
                          'Statistics Overview', isMobile, isTablet, isDesktop),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      _buildStatisticsGrid(
                          isMobile, isTablet, isDesktop, isSmallScreen),
                      SizedBox(height: isSmallScreen ? 20 : 32),

                      // Recent Activity
                      _buildSectionTitle(
                          'Recent Activity', isMobile, isTablet, isDesktop),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      _buildRecentActivity(
                          isMobile, isTablet, isDesktop, isSmallScreen),
                      SizedBox(height: isSmallScreen ? 16 : 24),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(bool isMobile) {
    return Container(
      margin: EdgeInsets.all(isMobile ? 6 : 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        icon: Icon(
          Icons.menu_rounded,
          color: Colors.white,
          size: isMobile ? 20 : 24,
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile, bool isTablet, bool isDesktop,
      bool isSmallScreen, bool isVerySmallScreen) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 20,
          isVerySmallScreen ? 50 : (isSmallScreen ? 55 : 60),
          isMobile ? 16 : 20,
          isSmallScreen ? 16 : 20),
      child: Row(
        children: [
          Expanded(
            child: Consumer<CompanyProvider>(
              builder: (context, companyProvider, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'HR Dashboard',
                      style: TextStyle(
                        fontSize: isVerySmallScreen
                            ? 20
                            : (isSmallScreen ? 24 : (isDesktop ? 32 : 28)),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: isVerySmallScreen ? 2 : 4),
                    Text(
                      companyProvider.currentCompany?.name ?? 'Company',
                      style: TextStyle(
                        fontSize: isVerySmallScreen
                            ? 12
                            : (isSmallScreen ? 13 : (isDesktop ? 16 : 14)),
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
              final avatarSize = isVerySmallScreen
                  ? 40
                  : (isSmallScreen ? 45 : (isDesktop ? 60 : 50));
              return GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/personal-info'),
                child: Container(
                  width: avatarSize.toDouble(),
                  height: avatarSize.toDouble(),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
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
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: avatarSize * 0.5,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(
      bool isMobile, bool isTablet, bool isDesktop, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back! 👋',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 20 : (isDesktop ? 28 : 24),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 6 : 8),
                Text(
                  'Manage your team efficiently with our HR tools',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : (isDesktop ? 16 : 14),
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
            ),
            child: Icon(
              Icons.dashboard_rounded,
              color: Colors.white,
              size: isSmallScreen ? 24 : (isDesktop ? 36 : 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
      String title, bool isMobile, bool isTablet, bool isDesktop) {
    return Text(
      title,
      style: TextStyle(
        fontSize: isMobile ? 18 : (isDesktop ? 24 : 20),
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildQuickActionsGrid(
      bool isMobile, bool isTablet, bool isDesktop, bool isSmallScreen) {
    final crossAxisCount = isDesktop ? 4 : 2;
    final childAspectRatio = isSmallScreen ? 1.4 : (isDesktop ? 1.1 : 1.2);
    final spacing = isSmallScreen ? 12 : (isMobile ? 12 : 16);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: spacing.toDouble(),
      crossAxisSpacing: spacing.toDouble(),
      childAspectRatio: childAspectRatio,
      children: [
        _buildActionCard(
          'Pending Approvals',
          Icons.approval_rounded,
          const Color(0xFFFF6B6B),
          '5',
          () => _showSnackBar('Pending Approvals'),
          isMobile,
          isSmallScreen,
        ),
        _buildActionCard(
          'Manage Employees',
          Icons.people_rounded,
          const Color(0xFF4ECDC4),
          '24',
          () => Navigator.pushNamed(context, '/hr-employees'),
          isMobile,
          isSmallScreen,
        ),
        _buildActionCard(
          'Reports',
          Icons.bar_chart_rounded,
          const Color(0xFF45B7D1),
          '',
          () => _showSnackBar('Reports'),
          isMobile,
          isSmallScreen,
        ),
        _buildActionCard(
          'Settings',
          Icons.settings_rounded,
          const Color(0xFF96CEB4),
          '',
          () => Navigator.pushNamed(context, '/profile-settings'),
          isMobile,
          isSmallScreen,
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
    bool isMobile,
    bool isSmallScreen,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 12 : (isMobile ? 16 : 20)),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
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
                    width: isSmallScreen ? 40 : (isMobile ? 45 : 50),
                    height: isSmallScreen ? 40 : (isMobile ? 45 : 50),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: isSmallScreen ? 20 : (isMobile ? 22 : 24),
                    ),
                  ),
                  if (count.isNotEmpty)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: EdgeInsets.all(isSmallScreen ? 3 : 4),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius:
                              BorderRadius.circular(isSmallScreen ? 8 : 10),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints: BoxConstraints(
                          minWidth: isSmallScreen ? 16 : 20,
                          minHeight: isSmallScreen ? 16 : 20,
                        ),
                        child: Text(
                          count,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 8 : 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: isSmallScreen ? 8 : 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : (isMobile ? 13 : 14),
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

  Widget _buildStatisticsGrid(
      bool isMobile, bool isTablet, bool isDesktop, bool isSmallScreen) {
    final crossAxisCount = isDesktop ? 4 : 2;
    final childAspectRatio = isSmallScreen ? 1.6 : (isDesktop ? 1.2 : 1.3);
    final spacing = isSmallScreen ? 12 : (isMobile ? 12 : 16);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: spacing.toDouble(),
      crossAxisSpacing: spacing.toDouble(),
      childAspectRatio: childAspectRatio,
      children: [
        _buildStatCard(
          'Total Employees',
          '24',
          Icons.people_rounded,
          const Color(0xFF4ECDC4),
          '+12%',
          isMobile,
          isSmallScreen,
        ),
        _buildStatCard(
          'Pending Leaves',
          '8',
          Icons.event_available_rounded,
          const Color(0xFFFF6B6B),
          '-3%',
          isMobile,
          isSmallScreen,
        ),
        _buildStatCard(
          'Approved This Month',
          '15',
          Icons.check_circle_rounded,
          const Color(0xFF96CEB4),
          '+8%',
          isMobile,
          isSmallScreen,
        ),
        _buildStatCard(
          'Rejected This Month',
          '2',
          Icons.cancel_rounded,
          const Color(0xFFFFB6C1),
          '-1%',
          isMobile,
          isSmallScreen,
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
    bool isMobile,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : (isMobile ? 16 : 20)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: isSmallScreen ? 32 : (isMobile ? 36 : 40),
                height: isSmallScreen ? 32 : (isMobile ? 36 : 40),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: isSmallScreen ? 16 : (isMobile ? 18 : 20),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 6 : 8,
                    vertical: isSmallScreen ? 2 : 4),
                decoration: BoxDecoration(
                  color: trend.startsWith('+')
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(isSmallScreen ? 4 : 6),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 8 : 10,
                    fontWeight: FontWeight.bold,
                    color: trend.startsWith('+') ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 20 : (isMobile ? 22 : 24),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: isSmallScreen ? 4 : 6),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallScreen ? 10 : (isMobile ? 11 : 12),
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

  Widget _buildRecentActivity(
      bool isMobile, bool isTablet, bool isDesktop, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : (isMobile ? 18 : 20)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : (isDesktop ? 20 : 18),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: isSmallScreen ? 12 : 16),
          _buildActivityItem(
            'New employee registered',
            'John Doe joined the team',
            Icons.person_add_rounded,
            const Color(0xFF4ECDC4),
            isMobile,
            isSmallScreen,
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          _buildActivityItem(
            'Leave request approved',
            'Sarah Wilson\'s vacation approved',
            Icons.check_circle_rounded,
            const Color(0xFF96CEB4),
            isMobile,
            isSmallScreen,
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          _buildActivityItem(
            'Payroll processed',
            'Monthly payroll completed',
            Icons.account_balance_wallet_rounded,
            const Color(0xFF45B7D1),
            isMobile,
            isSmallScreen,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool isMobile,
    bool isSmallScreen,
  ) {
    return Row(
      children: [
        Container(
          width: isSmallScreen ? 32 : (isMobile ? 36 : 40),
          height: isSmallScreen ? 32 : (isMobile ? 36 : 40),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
          ),
          child: Icon(
            icon,
            color: color,
            size: isSmallScreen ? 16 : (isMobile ? 18 : 20),
          ),
        ),
        SizedBox(width: isSmallScreen ? 8 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : (isMobile ? 13 : 14),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: isSmallScreen ? 1 : 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: isSmallScreen ? 10 : (isMobile ? 11 : 12),
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF35BF8C),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
