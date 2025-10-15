enum UserRole {
  employee('Employee', 'employee'),
  hr('HR Manager', 'hr'),
  manager('Manager', 'manager');

  const UserRole(this.displayName, this.odooCode);
  final String displayName;
  final String odooCode;

  bool get canApproveLeaves => this == UserRole.hr || this == UserRole.manager;
  bool get canManageEmployees => this == UserRole.hr;
  bool get canViewReports => this == UserRole.hr || this == UserRole.manager;
}
