import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../widgets/hr_drawer.dart';
import '../presentation/providers/leave_provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../utils/app_localizations.dart';
import '../services/user_service.dart';
import '../services/odoo_service.dart';
import '../services/notification_service.dart';
import '../data/models/user_model.dart';

class HRDashboardNew extends StatefulWidget {
  const HRDashboardNew({super.key});

  @override
  State<HRDashboardNew> createState() => _HRDashboardNewState();
}

class _HRDashboardNewState extends State<HRDashboardNew> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final OdooService _odooService = OdooService();
  final NotificationService _notificationService = NotificationService();

  int _unreadCount = 0;
  bool _isLoadingNotifications = true;
  int _pendingLeavesCount = 0;
  bool _isLoadingPendingLeaves = true;

  int _totalEmployeesCount = 0;
  bool _isLoadingEmployeesCount = true;

  @override
  void initState() {
    super.initState();
    // Initialiser le service utilisateur
    UserService.instance.initialize();
    _notificationService.addListener(_onNotificationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLeaveBalance();
      _loadNotifications();
      _loadPendingLeavesCount();
      _loadEmployeesCount();
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
      final notifications = await _odooService.getUnreadNotifications();

      setState(() {
        _unreadCount = notifications.where((n) => n['is_read'] == false).length;
        _isLoadingNotifications = false;
      });
    } catch (e) {
      print('Error loading notifications for dashboard: $e');
      setState(() {
        _isLoadingNotifications = false;
      });
    }
  }

  Future<void> _loadPendingLeavesCount() async {
    try {
      final pendingLeaves =
          await _odooService.getAllLeaveRequests(state: 'confirm');

      setState(() {
        _pendingLeavesCount = pendingLeaves.length;
        _isLoadingPendingLeaves = false;
      });
      print('Loaded ${pendingLeaves.length} pending leaves');
    } catch (e) {
      print('Error loading pending leaves count: $e');
      setState(() {
        _isLoadingPendingLeaves = false;
      });
    }
  }

  Future<void> _loadEmployeesCount() async {
    try {
      setState(() => _isLoadingEmployeesCount = true);

      // Get direct reports first (same logic as employee management screen)
      final directReports = await _odooService.getDirectReports();

      // If no direct reports, use fallback method (all employees under management)
      if (directReports.isEmpty) {
        print('🔄 No direct reports found, trying fallback method...');
        final fallbackEmployees =
            await _odooService.getAllEmployeesUnderManagement();
        setState(() {
          _totalEmployeesCount = fallbackEmployees.length;
          _isLoadingEmployeesCount = false;
        });
        print('Loaded ${fallbackEmployees.length} employees (fallback)');
      } else {
        setState(() {
          _totalEmployeesCount = directReports.length;
          _isLoadingEmployeesCount = false;
        });
        print('Loaded ${directReports.length} direct reports');
      }
    } catch (e) {
      print('Error loading employees count: $e');
      setState(() {
        _isLoadingEmployeesCount = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

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
              // Header Section
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                padding: const EdgeInsets.fromLTRB(8, 16, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Hamburger Menu
                    IconButton(
                      onPressed: () {
                        print('Hamburger button pressed'); // Debug
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      icon: const Icon(
                        Icons.menu,
                        color: Colors.black87,
                        size: 24,
                      ),
                    ),
                    // Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.translate('hr_dashboard'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'DBC Company',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Profile Picture (navigates to personal info)
                    InkWell(
                      onTap: () =>
                          Navigator.pushNamed(context, '/personal-info'),
                      borderRadius: BorderRadius.circular(20),
                      child: StreamBuilder<UserModel?>(
                        stream: UserService.instance.userStream,
                        initialData: UserService.instance.currentUser,
                        builder: (context, snapshot) {
                          return _buildProfileAvatar(snapshot.data);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText:
                        localizations.translate('search_employees_reports'),
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Metrics Cards Grid
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Top Row Cards
                      Row(
                        children: [
                          Expanded(
                            child: Consumer<LeaveProvider>(
                              builder: (context, leaveProvider, child) {
                                return _buildMetricCard(
                                  title: localizations
                                      .translate('total_employees'),
                                  value: _isLoadingEmployeesCount
                                      ? '-'
                                      : _totalEmployeesCount.toString(),
                                  subtitle:
                                      localizations.translate('active_staff'),
                                  color: const Color(0xFF35BF8C),
                                  chart: _buildBarChart(),
                                  onTap: () {
                                    Navigator.pushNamed(
                                        context, '/hr-employees');
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title:
                                  localizations.translate('pending_approvals'),
                              subtitle:
                                  localizations.translate('awaiting_review'),
                              value: _isLoadingPendingLeaves
                                  ? '-'
                                  : _pendingLeavesCount.toString(),
                              color: const Color(0xFF8B5CF6),
                              chart: _buildCircularProgress(0.6),
                              onTap: () {
                                Navigator.pushNamed(
                                    context, '/leave-management');
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

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
                              subtitle:
                                  localizations.translate('unread_messages'),
                              color: const Color(0xFF000B58),
                              onTap: () {
                                Navigator.pushNamed(
                                    context, '/hr-notifications');
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: localizations.translate('reports'),
                              value: '12',
                              subtitle: localizations.translate('this_month'),
                              color: Colors.white,
                              textColor: Colors.black87,
                              chart: _buildLineChart(),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Team Statistics Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
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
                                  localizations
                                      .translate('statistics_overview'),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  '< ${localizations.translate('filter')}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Team members placeholder
                            Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  localizations
                                      .translate('team_performance_data'),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Colors.black87,
            unselectedItemColor: Colors.grey,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: '',
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
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
          children: [
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 8),
            if (value != null)
              Text(
                value,
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const Spacer(),
            Expanded(
              flex: 2,
              child: chart,
            ),
          ],
        ),
      ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
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
                    size: 32,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  // Notification badge indicator
                  if (value != '0' && value != '-')
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
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
  }

  Widget _buildProfileAvatar(UserModel? user) {
    print(
        'HR Dashboard Avatar - User: ${user?.name}, Has image: ${user?.profileImage != null}');

    if (user?.profileImage != null && user!.profileImage!.isNotEmpty) {
      try {
        final imageBytes = base64Decode(user.profileImage!);
        print(
            'HR Dashboard Avatar - Image decoded successfully, size: ${imageBytes.length} bytes');
        return Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: ClipOval(
            child: Image.memory(
              imageBytes,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
        );
      } catch (e) {
        print('HR Dashboard Avatar - Error decoding image: $e');
        // Erreur de décodage, utiliser l'icône par défaut
      }
    } else {
      print('HR Dashboard Avatar - No image data available');
    }

    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF000B58), Color(0xFF35BF8C)],
        ),
      ),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 24,
      ),
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
