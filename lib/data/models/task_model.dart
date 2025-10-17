class TaskModel {
  final int id;
  final String title;
  final String description;
  final String priority;
  final DateTime dueDate;
  final DateTime assignedDate;
  final String status;
  final int assignedById;
  final String assignedByName;
  final int assignedToId;
  final String assignedToName;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.dueDate,
    required this.assignedDate,
    required this.status,
    required this.assignedById,
    required this.assignedByName,
    required this.assignedToId,
    required this.assignedToName,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      priority: json['priority'] ?? 'medium_priority',
      dueDate: DateTime.parse(json['dueDate']),
      assignedDate: DateTime.parse(json['assignedDate']),
      status: json['status'] ?? 'pending',
      assignedById: json['assignedById'] ?? 0,
      assignedByName: json['assignedByName'] ?? '',
      assignedToId: json['assignedToId'] ?? 0,
      assignedToName: json['assignedToName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'priority': priority,
      'dueDate': dueDate.toIso8601String(),
      'assignedDate': assignedDate.toIso8601String(),
      'status': status,
      'assignedById': assignedById,
      'assignedByName': assignedByName,
      'assignedToId': assignedToId,
      'assignedToName': assignedToName,
    };
  }

  TaskModel copyWith({
    int? id,
    String? title,
    String? description,
    String? priority,
    DateTime? dueDate,
    DateTime? assignedDate,
    String? status,
    int? assignedById,
    String? assignedByName,
    int? assignedToId,
    String? assignedToName,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      assignedDate: assignedDate ?? this.assignedDate,
      status: status ?? this.status,
      assignedById: assignedById ?? this.assignedById,
      assignedByName: assignedByName ?? this.assignedByName,
      assignedToId: assignedToId ?? this.assignedToId,
      assignedToName: assignedToName ?? this.assignedToName,
    );
  }

  String get priorityDisplayName {
    switch (priority) {
      case 'high_priority':
        return 'Élevée';
      case 'medium_priority':
        return 'Moyenne';
      case 'low_priority':
        return 'Faible';
      default:
        return 'Moyenne';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'in_progress':
        return 'En cours';
      case 'completed':
        return 'Terminée';
      case 'cancelled':
        return 'Annulée';
      default:
        return 'En attente';
    }
  }

  String get priorityColor {
    switch (priority) {
      case 'high_priority':
        return 'red';
      case 'medium_priority':
        return 'orange';
      case 'low_priority':
        return 'green';
      default:
        return 'orange';
    }
  }
}

