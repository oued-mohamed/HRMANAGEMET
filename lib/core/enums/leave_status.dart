enum LeaveStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected'),
  cancelled('Cancelled');

  const LeaveStatus(this.displayName);
  final String displayName;
}

enum LeaveType {
  annual('Annual Leave'),
  sick('Sick Leave'),
  personal('Personal Leave'),
  emergency('Emergency Leave');

  const LeaveType(this.displayName);
  final String displayName;
}

enum ApprovalStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected');

  const ApprovalStatus(this.displayName);
  final String displayName;
}
