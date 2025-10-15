import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/models/company_model.dart';
import '../../services/odoo_service.dart';
import '../../core/enums/user_role.dart';
import '../../core/models/auth_result.dart';

class AuthProvider extends ChangeNotifier {
  final OdooService _odooService = OdooService();

  UserModel? _user;
  List<CompanyModel>? _companies;
  CompanyModel? _currentCompany;
  bool _isLoading = false;
  String? _error;

  // Store credentials for re-authentication
  String? _lastUsername;
  String? _lastPassword;

  // Getters
  UserModel? get user => _user;
  List<CompanyModel>? get companies => _companies;
  CompanyModel? get currentCompany => _currentCompany;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  OdooService get odooService => _odooService;

  Future<AuthResult> login(String username, String password) async {
    _setLoading(true);
    _clearError();

    try {
      // Store credentials for potential re-authentication
      _lastUsername = username;
      _lastPassword = password;

      final success = await _odooService.login(username, password);

      if (success) {
        final userInfo = await _odooService.getUserInfo();

        print('User info retrieved: $userInfo');

        // Safely cast dynamic Odoo arrays (which are JSArray on web) to List<int>
        List<int> asIntList(dynamic value) {
          if (value is List) {
            return value.map((e) {
              if (e is int) return e;
              if (e is num) return e.toInt();
              return int.tryParse(e.toString()) ?? 0;
            }).toList();
          }
          return <int>[];
        }

        // Safely get string value (handle false/null)
        String asString(dynamic value, String defaultValue) {
          if (value == null || value == false) return defaultValue;
          return value.toString();
        }

        final user = UserModel(
          id: userInfo['id'] ?? 0,
          name: asString(userInfo['name'], 'User'),
          username: username,
          email: asString(userInfo['email'], username),
          isActive: (userInfo['active'] ?? true) == true,
          companyIds: asIntList(userInfo['company_ids']),
        );

        _user = user;

        // Create company entry based on Odoo data
        final userRole =
            await _determineUserRole(asIntList(userInfo['groups_id']));

        final companies = <CompanyModel>[
          CompanyModel(
            id: asIntList(userInfo['company_ids']).isNotEmpty
                ? asIntList(userInfo['company_ids']).first
                : 1,
            name: 'DBC Company', // You can fetch this from Odoo if needed
            employeeId: userInfo['id'] ?? 0,
            employeeName: asString(userInfo['name'], 'User'),
            jobTitle: 'Employee', // Default job title
            userRole: userRole,
          ),
        ];

        _companies = companies;

        // If user has only one company, set it as current
        if (_companies != null && _companies!.length == 1) {
          _currentCompany = _companies!.first;
        }

        print('Login successful - AuthProvider state updated');
        print('User: ${_user?.name}');
        print('OdooService authenticated: ${_odooService.isAuthenticated}');

        return AuthResult.success(user, companies);
      } else {
        print('Login failed for username: $username');
        _setError(
            'Invalid username or password. Please check your credentials.');
        return AuthResult.failure('Invalid username or password');
      }
    } catch (e) {
      _setError('An error occurred: ${e.toString()}');
      return AuthResult.failure(_error!);
    } finally {
      _setLoading(false);
    }
  }

  /// Verify and restore authentication if needed
  /// Returns true if authenticated, false otherwise
  Future<bool> verifyAuthentication() async {
    print('Verifying authentication...');
    print('AuthProvider isAuthenticated: $isAuthenticated');
    print('OdooService isAuthenticated: ${_odooService.isAuthenticated}');

    // If both are authenticated, we're good
    if (isAuthenticated && _odooService.isAuthenticated) {
      print('Authentication verified - both authenticated');
      return true;
    }

    // If OdooService lost auth but we have credentials, re-authenticate
    if (!_odooService.isAuthenticated &&
        _lastUsername != null &&
        _lastPassword != null) {
      print('OdooService lost auth, attempting to re-authenticate...');
      try {
        final result = await login(_lastUsername!, _lastPassword!);
        final success = result.isSuccess;
        print('Re-authentication ${success ? 'successful' : 'failed'}');
        return success;
      } catch (e) {
        print('Re-authentication error: $e');
        return false;
      }
    }

    print('Authentication verification failed');
    return false;
  }

  Future<UserRole> _determineUserRole(List<int> groupIds) async {
    try {
      print('Determining user role...');
      print('User group IDs: $groupIds');

      // Check if user has subordinates (is a manager)
      final hasSubordinates = await _odooService.isManager();

      if (hasSubordinates) {
        print('User is a manager (has subordinates)');
        return UserRole.manager;
      }

      // Check for HR role based on Odoo groups
      // HR Officer/Manager group IDs in Odoo
      // Base HR groups: base.group_hr_manager, base.group_hr_user
      // These typically have high IDs, not 13-14
      // Let's check for specific HR groups - adjust these based on your Odoo setup
      final hrGroupIds = [
        // 13, 14 are too common - might be basic user groups
        // Uncomment if you want to check specific HR groups:
        // 50, // Example: hr.group_hr_manager
        // 51, // Example: hr.group_hr_user
      ];

      if (hrGroupIds.isNotEmpty &&
          groupIds.any((id) => hrGroupIds.contains(id))) {
        print('User has HR role (group match)');
        return UserRole.hr;
      }

      print('User is a regular employee');
      return UserRole.employee;
    } catch (e) {
      print('Error determining user role: $e');
      print('Defaulting to employee role');
      // If there's an error (e.g., no employee record), default to employee
      return UserRole.employee;
    }
  }

  Future<void> setCurrentCompany(CompanyModel company) async {
    _currentCompany = company;
    notifyListeners();
  }

  Future<void> logout() async {
    _setLoading(true);

    try {
      await _odooService.logout();
    } catch (e) {
      // Log error but continue with logout
      print('Logout error: $e');
    } finally {
      _user = null;
      _companies = null;
      _currentCompany = null;
      _lastUsername = null;
      _lastPassword = null;
      _clearError();
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
