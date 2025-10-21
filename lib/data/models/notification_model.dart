class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String type;
  final Map<String, dynamic>? data;
  final DateTime createDate;
  final DateTime? readDate;
  final bool isRead;
  final int employeeId;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.data,
    required this.createDate,
    this.readDate,
    required this.isRead,
    required this.employeeId,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? 0,
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? 'general',
      data: map['data'] != null ? Map<String, dynamic>.from(map['data']) : null,
      createDate: map['create_date'] != null
          ? DateTime.parse(map['create_date'].toString().split(' ')[0])
          : DateTime.now(),
      readDate: map['read_date'] != null
          ? DateTime.parse(map['read_date'].toString().split(' ')[0])
          : null,
      isRead: map['is_read'] ?? false,
      employeeId: map['employee_id'] is List
          ? map['employee_id'][0]
          : map['employee_id'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'data': data,
      'create_date': createDate.toIso8601String(),
      'read_date': readDate?.toIso8601String(),
      'is_read': isRead,
      'employee_id': employeeId,
    };
  }

  NotificationModel copyWith({
    int? id,
    String? title,
    String? message,
    String? type,
    Map<String, dynamic>? data,
    DateTime? createDate,
    DateTime? readDate,
    bool? isRead,
    int? employeeId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      data: data ?? this.data,
      createDate: createDate ?? this.createDate,
      readDate: readDate ?? this.readDate,
      isRead: isRead ?? this.isRead,
      employeeId: employeeId ?? this.employeeId,
    );
  }

  @override
  String toString() {
    return 'NotificationModel(id: $id, title: $title, message: $message, type: $type, isRead: $isRead)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Notification types enum
enum NotificationType {
  taskAssignment('task_assignment', 'Task Assignment'),
  leaveApproval('leave_approval', 'Leave Approval'),
  general('general', 'General'),
  system('system', 'System');

  const NotificationType(this.value, this.displayName);
  final String value;
  final String displayName;

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NotificationType.general,
    );
  }
}
