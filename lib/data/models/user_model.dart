class UserModel {
  final int id;
  final String name;
  final String username;
  final String email;
  final bool isActive;
  final List<int> companyIds;
  final String? profileImage;

  const UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.isActive,
    required this.companyIds,
    this.profileImage,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      name: json['user_name'] ??
          json['name'] ??
          '', // Use user_name first, fallback to name
      username: json['login'] ?? '',
      email: json['user_email'] ??
          json['email'] ??
          '', // Use user_email first, fallback to email
      isActive: json['active'] ?? true,
      companyIds: List<int>.from(json['company_ids'] ?? []),
      profileImage: json['image_1920'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'login': username,
      'email': email,
      'active': isActive,
      'company_ids': companyIds,
      'image_1920': profileImage,
    };
  }
}
