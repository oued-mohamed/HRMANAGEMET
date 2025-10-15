import '../../core/enums/user_role.dart';

class CompanyModel {
  final int id;
  final String name;
  final int employeeId;
  final String employeeName;
  final String jobTitle;
  final int? departmentId;
  final String? departmentName;
  final int? managerId;
  final String? managerName;
  final UserRole userRole;

  const CompanyModel({
    required this.id,
    required this.name,
    required this.employeeId,
    required this.employeeName,
    required this.jobTitle,
    this.departmentId,
    this.departmentName,
    this.managerId,
    this.managerName,
    required this.userRole,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['company_id'] ?? 0,
      name: json['company_name'] ?? 'Unknown Company',
      employeeId: json['id'] ?? 0,
      employeeName: json['name'] ?? '',
      jobTitle: json['job_title'] ?? '',
      departmentId: json['department_id'],
      departmentName: json['department_name'],
      managerId: json['parent_id'],
      managerName: json['manager_name'],
      userRole: _determineUserRole(json),
    );
  }

  static UserRole _determineUserRole(Map<String, dynamic> json) {
    // Mock logic to determine user role based on job title
    final jobTitle = (json['job_title'] ?? '').toLowerCase();

    if (jobTitle.contains('hr') || jobTitle.contains('human resources')) {
      return UserRole.hr;
    } else if (jobTitle.contains('manager') || jobTitle.contains('director')) {
      return UserRole.manager;
    } else {
      return UserRole.employee;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'company_id': id,
      'company_name': name,
      'id': employeeId,
      'name': employeeName,
      'job_title': jobTitle,
      'department_id': departmentId,
      'department_name': departmentName,
      'parent_id': managerId,
      'manager_name': managerName,
    };
  }
}
