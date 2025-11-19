import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/odoo_service.dart';
import '../utils/app_localizations.dart';
import '../widgets/employee_drawer.dart';
import '../utils/navigation_helpers.dart';

class EmployeeNotificationsScreen extends StatefulWidget {
  const EmployeeNotificationsScreen({super.key});

  @override
  State<EmployeeNotificationsScreen> createState() =>
      _EmployeeNotificationsScreenState();
}

class _EmployeeNotificationsScreenState
    extends State<EmployeeNotificationsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final NotificationService _notificationService = NotificationService();
  final OdooService _odooService = OdooService();

  List<Map<String, dynamic>> _odooNotifications = [];
  List<Map<String, dynamic>> _allItems = []; // Cache the combined items
  bool _isLoading = true;
  bool _hasError = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    // Initialize after the first frame is built to avoid build-time state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isInitialized) {
        _isInitialized = true;
        _notificationService.addListener(_onNotificationChanged);
        _notificationService
            .clearAllNotifications(); // Clear any existing mock data
        _updateAllItems(); // Initialize the cached items
        _loadOdooData();
      }
    });
    // Removed mock data - only show real notifications from HR
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationChanged);
    _isInitialized = false;
    super.dispose();
  }

  void _onNotificationChanged() {
    if (mounted) {
      setState(() {
        _updateAllItems();
      });
    }
  }

  Future<void> _loadOdooData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Load only notifications from Odoo (no tasks)
      final notifications = await _odooService.getUnreadNotifications();

      if (mounted) {
        setState(() {
          _odooNotifications = notifications;
          _isLoading = false;
          _updateAllItems();
        });
      }
    } catch (e) {
      print('Error loading Odoo notifications: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _updateAllItems();
        });
      }
    }
  }

  void _updateAllItems() {
    List<Map<String, dynamic>> allItems = [];

    // Add Odoo notifications only (no tasks)
    for (var notification in _odooNotifications) {
      allItems.add({
        ...notification,
        'isOdooNotification': true,
        'type': notification['type'] ?? 'general',
        'title': notification['title'] ?? 'Notification',
        'description': _stripHtmlTags(notification['message'] ?? ''),
        'priority': 'medium_priority',
        'dueDate': _convertToIsoString(notification['create_date']),
        'assignedByName': 'RH',
        'createdAt': _convertToIsoString(notification['create_date']),
        'isRead': notification['is_read'] ?? false,
      });
    }

    // Add local notifications
    for (var notification in _notificationService.notifications) {
      allItems.add({
        ...notification,
        'isLocalNotification': true,
      });
    }

    // Sort by creation date (newest first)
    allItems.sort((a, b) {
      final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
      final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
      return dateB.compareTo(dateA);
    });

    _allItems = allItems;
  }

  Future<void> _markAllAsRead() async {
    try {
      // Mark all unread Odoo notifications as read
      final unreadNotifications =
          _odooNotifications.where((n) => n['is_read'] == false).toList();

      for (var notification in unreadNotifications) {
        final messageId = notification['id'] as int;
        await _odooService.markNotificationAsRead(messageId);
      }

      // Update local state
      setState(() {
        for (var notification in _odooNotifications) {
          notification['is_read'] = true;
        }
        _updateAllItems();
      });

      print('✅ All notifications marked as read');
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // import helper
    // ignore: unused_local_variable
    final localizations = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        // Handle Android back button - same functionality as AppBar back button
        await NavigationHelpers.backToPrevious(context);
      },
      child: Scaffold(
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
                // Header
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
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () => NavigationHelpers.backToPrevious(context),
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 26),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Notifications',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${_allItems.length} notifications',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_allItems
                              .where((item) => item['isRead'] == false)
                              .length >
                          0)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_allItems.where((item) => item['isRead'] == false).length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                onPressed: _markAllAsRead,
                                icon: const Icon(
                                  Icons.done_all,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                tooltip: 'Marquer tout comme lu',
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Notifications List
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : _hasError
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 64,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Erreur de connexion',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Impossible de charger les notifications depuis Odoo',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadOdooData,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Colors.white.withOpacity(0.2),
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Réessayer'),
                                  ),
                                ],
                              ),
                            )
                          : _allItems.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.notifications_none,
                                        size: 80,
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Aucune notification',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Vous recevrez des notifications\nquand le RH vous enverra des messages',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  itemCount: _allItems.length,
                                  itemBuilder: (context, index) {
                                    final item = _allItems[index];
                                    return _buildNotificationCard(
                                        item, localizations);
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

  Widget _buildNotificationCard(
      Map<String, dynamic> notification, AppLocalizations localizations) {
    final isUnread = notification['isRead'] == false;
    final priorityColor = _notificationService.getPriorityColor(
        notification['priority']?.toString() ?? 'medium_priority');
    final notificationType = notification['type'] ?? 'general';
    final typeIcon = _getNotificationTypeIcon(notificationType);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        border: isUnread
            ? Border.all(
                color: priorityColor.withOpacity(0.3),
                width: 2,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showNotificationDetails(notification, localizations),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with type icon, priority and status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        typeIcon,
                        color: priorityColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        notification['title'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              isUnread ? FontWeight.bold : FontWeight.w600,
                          color: const Color(0xFF2d3436),
                        ),
                      ),
                    ),
                    if (isUnread)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF35BF8C).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Nouveau',
                          style: TextStyle(
                            color: Color(0xFF35BF8C),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Description
                Text(
                  notification['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 12),

                // Footer with assigner and due date
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'De ${notification['assignedByName']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(notification['dueDate']),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
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

  IconData _getNotificationTypeIcon(String type) {
    switch (type) {
      case 'meeting':
        return Icons.meeting_room;
      case 'training':
        return Icons.school;
      case 'profile_update':
        return Icons.person_pin;
      case 'evaluation':
        return Icons.assessment;
      case 'task':
        return Icons.assignment;
      default:
        return Icons.notifications;
    }
  }

  void _showNotificationDetails(
      Map<String, dynamic> notification, AppLocalizations localizations) {
    // Mark as read when opened
    final notificationId = notification['id'];

    // If it's an Odoo notification, mark it as read in Odoo
    if (notification['isOdooNotification'] == true && notificationId is int) {
      // Update local state immediately for instant UI feedback
      final index =
          _odooNotifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        setState(() {
          _odooNotifications[index]['is_read'] = true;
          _updateAllItems();
        });
      }

      // Mark as read in Odoo asynchronously (don't await - fire and forget)
      _odooService.markNotificationAsRead(notificationId).then((success) {
        if (success) {
          print('✅ Notification $notificationId marked as read in Odoo');
        } else {
          print(
              '⚠️ Failed to mark notification $notificationId as read in Odoo');
        }
      }).catchError((e) {
        print('❌ Error marking notification as read: $e');
      });
    } else {
      // For local notifications, use the notification service
      _notificationService.markAsRead(notificationId.toString());
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Notification header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    notification['title'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2d3436),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'De ${notification['assignedByName']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Notification details
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildDetailRow(
                    Icons.description,
                    'Message',
                    notification['description'],
                  ),
                  _buildDetailRow(
                    Icons.calendar_today,
                    'Date de réception',
                    _formatDate(notification['createdAt']),
                  ),
                ],
              ),
            ),

            // Action button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF35BF8C),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Fermer',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF000B58).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF000B58), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2d3436),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _stripHtmlTags(String htmlString) {
    // Remove HTML tags using regex
    String cleaned = htmlString.replaceAll(RegExp(r'<[^>]*>'), '');

    // Decode common HTML entities
    cleaned = cleaned.replaceAll('&amp;', '&');
    cleaned = cleaned.replaceAll('&lt;', '<');
    cleaned = cleaned.replaceAll('&gt;', '>');
    cleaned = cleaned.replaceAll('&quot;', '"');
    cleaned = cleaned.replaceAll('&#39;', "'");
    cleaned = cleaned.replaceAll('&nbsp;', ' ');

    // Clean up excessive whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }

  String _convertToIsoString(dynamic date) {
    if (date == null) return DateTime.now().toIso8601String();

    if (date is String) {
      return date;
    } else if (date is DateTime) {
      return date.toIso8601String();
    } else {
      return DateTime.now().toIso8601String();
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';

    DateTime dateTime;
    if (date is String) {
      dateTime = DateTime.tryParse(date) ?? DateTime.now();
    } else if (date is DateTime) {
      dateTime = date;
    } else {
      return 'N/A';
    }

    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }
}
