import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../widgets/employee_drawer.dart';
import '../presentation/providers/leave_provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../utils/app_localizations.dart';
import '../services/user_service.dart';
import '../services/odoo_service.dart';
import '../services/notification_service.dart';
import '../data/models/user_model.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final OdooService _odooService = OdooService();
  final NotificationService _notificationService = NotificationService();

  int _unreadCount = 0;
  bool _isLoadingNotifications = true;

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
                    // Hamburger Menu -> open overlay Employee Menu
                    IconButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                            context, '/employee-menu');
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
                            localizations.translate('high_performance'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            localizations.translate('hr_management'),
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: localizations.translate('requests_status'),
                              subtitle: localizations.translate('in_progress'),
                              value: '3',
                              color: const Color(0xFF8B5CF6),
                              chart: _buildCircularProgress(0.6),
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
                              subtitle: localizations.translate('unread'),
                              color: const Color(0xFF000B58),
                              onTap: () {
                                Navigator.pushNamed(
                                    context, '/employee-notifications');
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: localizations.translate('working_period'),
                              value: '8h',
                              subtitle: localizations.translate('today'),
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
                                  localizations.translate('team_statistics'),
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
                                      .translate('team_statistics_data'),
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
                icon: Icon(Icons.circle_outlined),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.folder_outlined),
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
        padding: const EdgeInsets.all(14),
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
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 6),
            if (value != null)
              Text(
                value,
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const Spacer(),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 45,
                child: chart,
              ),
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
        'Employee Dashboard Avatar - User: ${user?.name}, Has image: ${user?.profileImage != null}');

    if (user?.profileImage != null && user!.profileImage!.isNotEmpty) {
      try {
        final imageBytes = base64Decode(user.profileImage!);
        print(
            'Employee Dashboard Avatar - Image decoded successfully, size: ${imageBytes.length} bytes');
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
        print('Employee Dashboard Avatar - Error decoding image: $e');
        // Erreur de décodage, utiliser l'icône par défaut
      }
    } else {
      print('Employee Dashboard Avatar - No image data available');
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
