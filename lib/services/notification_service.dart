import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<Map<String, dynamic>> _notifications = [];
  final List<VoidCallback> _listeners = [];

  List<Map<String, dynamic>> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount =>
      _notifications.where((n) => n['isRead'] == false).length;

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  void addNotification({
    required String title,
    required String description,
    required String priority,
    required DateTime dueDate,
    required String assignedByName,
    required String assignedToName,
    String type = 'task',
  }) {
    final notification = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'description': description,
      'priority': priority,
      'dueDate': dueDate,
      'createdAt': DateTime.now(),
      'assignedByName': assignedByName,
      'assignedToName': assignedToName,
      'type': type,
      'isRead': false,
    };

    _notifications.insert(0, notification);
    _notifyListeners();
  }

  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n['id'] == notificationId);
    if (index != -1) {
      _notifications[index]['isRead'] = true;
      _notifyListeners();
    }
  }

  void markAllAsRead() {
    for (final notification in _notifications) {
      notification['isRead'] = true;
    }
    _notifyListeners();
  }

  void removeNotification(String notificationId) {
    _notifications.removeWhere((n) => n['id'] == notificationId);
    _notifyListeners();
  }

  void clearAllNotifications() {
    _notifications.clear();
    _notifyListeners();
  }

  Color getPriorityColor(String priority) {
    switch (priority) {
      case 'high_priority':
        return Colors.red;
      case 'medium_priority':
        return Colors.orange;
      case 'low_priority':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  String getPriorityDisplayName(String priority) {
    switch (priority) {
      case 'high_priority':
        return 'Haute priorité';
      case 'medium_priority':
        return 'Priorité moyenne';
      case 'low_priority':
        return 'Basse priorité';
      default:
        return 'Priorité normale';
    }
  }

  // Add some sample notifications for testing
  void addSampleNotifications() {
    addNotification(
      title: 'Révision du rapport mensuel',
      description:
          'Veuillez réviser et finaliser le rapport mensuel de votre département.',
      priority: 'high_priority',
      dueDate: DateTime.now().add(const Duration(days: 3)),
      assignedByName: 'Sarah Manager',
      assignedToName: 'John Doe',
      type: 'task',
    );

    addNotification(
      title: 'Formation sécurité',
      description:
          'Participation obligatoire à la formation sécurité le vendredi.',
      priority: 'medium_priority',
      dueDate: DateTime.now().add(const Duration(days: 5)),
      assignedByName: 'HR Department',
      assignedToName: 'John Doe',
      type: 'training',
    );

    addNotification(
      title: 'Mise à jour du profil',
      description:
          'Veuillez mettre à jour vos informations personnelles dans votre profil.',
      priority: 'low_priority',
      dueDate: DateTime.now().add(const Duration(days: 7)),
      assignedByName: 'System',
      assignedToName: 'John Doe',
      type: 'profile_update',
    );
  }
}

typedef VoidCallback = void Function();
