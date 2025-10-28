import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import '../services/odoo_service.dart';

class OdooNotificationService {
  static final OdooNotificationService _instance =
      OdooNotificationService._internal();
  factory OdooNotificationService() => _instance;
  OdooNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Timer? _pollingTimer;
  bool _isPolling = false;

  // Track which notifications have been shown to avoid duplicates
  final Set<int> _shownNotificationIds = {};

  // Initialize the Odoo notification service
  Future<void> initialize() async {
    try {
      // Request permission for notifications
      await _requestPermission();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Start polling for notifications
      await startPolling();

      print('✅ OdooNotificationService initialized successfully');
    } catch (e) {
      print('❌ Error initializing OdooNotificationService: $e');
    }
  }

  // Request notification permissions
  Future<void> _requestPermission() async {
    // Request permissions for local notifications
    final result = await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    print('🔔 Notification permission granted: ${result ?? false}');
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  // Start polling for notifications from Odoo
  Future<void> startPolling() async {
    if (_isPolling) return;

    _isPolling = true;
    print('🔄 Starting notification polling...');

    // Poll every 30 seconds when app is active
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _checkForNewNotifications();
    });

    // Initial check
    await _checkForNewNotifications();
  }

  // Stop polling for notifications
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    print('⏹️ Stopped notification polling');
  }

  // Check for new notifications from Odoo
  Future<void> _checkForNewNotifications() async {
    try {
      if (!OdooService().isAuthenticated) return;

      final notifications = await OdooService().getUnreadNotifications();

      for (final notification in notifications) {
        final notificationId = notification['id'] as int;

        // Only show notifications that haven't been shown before
        if (!_shownNotificationIds.contains(notificationId)) {
          await _showLocalNotification(notification);
          // Track that this notification has been shown
          _shownNotificationIds.add(notificationId);
        }
      }
    } catch (e) {
      print('❌ Error checking notifications: $e');
    }
  }

  // Show local notification from Odoo data
  Future<void> _showLocalNotification(Map<String, dynamic> notification) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'odoo_notifications',
      'Odoo Notifications',
      channelDescription: 'Notifications from Odoo HR system',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Strip HTML tags from the message
    String cleanMessage = _stripHtmlTags(
        notification['message'] ?? 'You have a new notification');

    await _localNotifications.show(
      notification['id'],
      _stripHtmlTags(notification['title'] ?? 'HR Notification'),
      cleanMessage,
      platformChannelSpecifics,
      payload: notification.toString(),
    );
  }

  // Remove HTML tags from string
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

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('👆 Notification tapped: ${response.payload}');

    // Parse payload and navigate accordingly
    // This will be implemented based on your navigation structure
    _handleNotificationNavigation(response.payload ?? '');
  }

  // Handle notification navigation
  void _handleNotificationNavigation(String payload) {
    try {
      // Parse the notification data and navigate accordingly
      // For now, we'll implement basic navigation
      print('🧭 Navigating based on notification: $payload');

      // TODO: Implement navigation logic based on notification type
      // This could navigate to specific screens like:
      // - Task details
      // - Leave management
      // - Notifications screen
      // - Dashboard
    } catch (e) {
      print('❌ Error handling notification navigation: $e');
    }
  }

  // Send test notification (for testing purposes)
  Future<void> sendTestNotification(String title, String body) async {
    try {
      await _showLocalNotification({
        'id': DateTime.now().millisecondsSinceEpoch,
        'title': title,
        'message': body,
        'type': 'test',
      });
    } catch (e) {
      print('❌ Error sending test notification: $e');
    }
  }

  // Dispose resources
  void dispose() {
    stopPolling();
  }
}
