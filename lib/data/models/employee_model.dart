class Employee {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? jobTitle;
  final String? department;
  final bool isActive;
  final int? userId;
  final String? profileImage;

  const Employee({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.jobTitle,
    this.department,
    required this.isActive,
    this.userId,
    this.profileImage,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['work_email'] ?? json['email'] ?? '',
      phone: json['work_phone'] ?? json['phone'],
      jobTitle: json['job_title'] ??
          json['job_id']?[1], // job_id is usually [id, name]
      department: json['department_id']
          ?[1], // department_id is usually [id, name]
      isActive: json['active'] ?? true,
      userId: json['user_id'] is List ? json['user_id'][0] : json['user_id'],
      profileImage: json['image_1920'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'work_email': email,
      'work_phone': phone,
      'job_title': jobTitle,
      'department_id': department,
      'active': isActive,
      'user_id': userId,
      'image_1920': profileImage,
    };
  }

  @override
  String toString() {
    return 'Employee(id: $id, name: $name, email: $email)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Employee && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
