import '../data/models/user_model.dart';
import '../data/models/company_model.dart';

class AuthResult {
  final bool success;
  final String? error;
  final UserModel? user;
  final List<CompanyModel>? companies;

  AuthResult.success(this.user, this.companies)
      : success = true,
        error = null;
  AuthResult.failure(this.error)
      : success = false,
        user = null,
        companies = null;
}

class MockAuthService {
  // Mock users data
  static final Map<String, Map<String, dynamic>> _mockUsers = {
    'admin@company.com': {
      'password': 'admin123',
      'user': {
        'id': 1,
        'name': 'Admin User',
        'login': 'admin@company.com',
        'email': 'admin@company.com',
        'active': true,
        'company_ids': [1, 2],
      },
      'companies': [
        {
          'company_id': 1,
          'company_name': 'TechCorp Solutions',
          'id': 1,
          'name': 'Admin User',
          'job_title': 'HR Manager',
          'department_id': 1,
          'department_name': 'Human Resources',
        },
        {
          'company_id': 2,
          'company_name': 'InnovateLab',
          'id': 2,
          'name': 'Admin User',
          'job_title': 'HR Manager',
          'department_id': 1,
          'department_name': 'Human Resources',
        },
      ],
    },
    'manager@company.com': {
      'password': 'manager123',
      'user': {
        'id': 2,
        'name': 'John Manager',
        'login': 'manager@company.com',
        'email': 'manager@company.com',
        'active': true,
        'company_ids': [1],
      },
      'companies': [
        {
          'company_id': 1,
          'company_name': 'TechCorp Solutions',
          'id': 2,
          'name': 'John Manager',
          'job_title': 'Project Manager',
          'department_id': 2,
          'department_name': 'Engineering',
        },
      ],
    },
    'employee@company.com': {
      'password': 'employee123',
      'user': {
        'id': 3,
        'name': 'Sarah Employee',
        'login': 'employee@company.com',
        'email': 'employee@company.com',
        'active': true,
        'company_ids': [1],
      },
      'companies': [
        {
          'company_id': 1,
          'company_name': 'TechCorp Solutions',
          'id': 3,
          'name': 'Sarah Employee',
          'job_title': 'Software Developer',
          'department_id': 2,
          'department_name': 'Engineering',
          'parent_id': 2,
          'manager_name': 'John Manager',
        },
      ],
    },
  };

  Future<AuthResult> authenticateUser(String username, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    try {
      // Check if user exists in mock data
      final userData = _mockUsers[username.toLowerCase()];
      if (userData == null) {
        return AuthResult.failure('User not found in system');
      }

      // Check password
      if (userData['password'] != password) {
        return AuthResult.failure('Invalid password');
      }

      // Create user model
      final user = UserModel.fromJson(userData['user']);

      // Create company models
      final companies = (userData['companies'] as List)
          .map((companyData) => CompanyModel.fromJson(companyData))
          .toList();

      if (companies.isEmpty) {
        return AuthResult.failure('User has no company assignments');
      }

      return AuthResult.success(user, companies);
    } catch (e) {
      return AuthResult.failure('Authentication failed: ${e.toString()}');
    }
  }

  Future<bool> isUserActive(String username) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final userData = _mockUsers[username.toLowerCase()];
    return userData?['user']['active'] ?? false;
  }

  Future<void> logout() async {
    // Simulate logout delay
    await Future.delayed(const Duration(milliseconds: 300));
    // In real implementation, this would clear tokens and session data
  }
}
