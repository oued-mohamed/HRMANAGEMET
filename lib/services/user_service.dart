import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import '../data/models/user_model.dart';
import 'odoo_service.dart';

class UserService {
  static UserService? _instance;
  static UserService get instance => _instance ??= UserService._();

  UserService._();

  UserModel? _currentUser;
  final StreamController<UserModel?> _userController =
      StreamController<UserModel?>.broadcast();
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  Stream<UserModel?> get userStream => _userController.stream;
  bool get isLoading => _isLoading;

  Future<UserModel?> loadCurrentUser() async {
    // Si déjà en cours de chargement, ne pas relancer
    if (_isLoading) {
      print('UserService - Already loading, returning cached user');
      return _currentUser;
    }

    // Si déjà chargé, retourner immédiatement
    if (_currentUser != null) {
      print(
          'UserService - User already loaded: ${_currentUser!.name}, has image: ${_currentUser!.profileImage != null}');
      return _currentUser;
    }

    print('UserService - Loading user data...');
    _isLoading = true;
    try {
      final employeeData = await OdooService().getEmployeeDetails();
      _currentUser = UserModel.fromJson(employeeData);
      print(
          'UserService - User loaded: ${_currentUser!.name}, has image: ${_currentUser!.profileImage != null}');
      if (_currentUser!.profileImage != null) {
        print(
            'UserService - Image data length: ${_currentUser!.profileImage!.length}');
      }
      _userController.add(_currentUser);
      return _currentUser;
    } catch (e) {
      print('UserService - Error loading user: $e');
      return null;
    } finally {
      _isLoading = false;
    }
  }

  void updateUserProfileImage(String? imageBase64) {
    print(
        'UserService - Updating profile image, has data: ${imageBase64 != null && imageBase64.isNotEmpty}');
    if (_currentUser != null) {
      _currentUser = UserModel(
        id: _currentUser!.id,
        name: _currentUser!.name,
        username: _currentUser!.username,
        email: _currentUser!.email,
        isActive: _currentUser!.isActive,
        companyIds: _currentUser!.companyIds,
        profileImage: imageBase64,
      );
      print(
          'UserService - Profile image updated, new image length: ${imageBase64?.length ?? 0}');
      _userController.add(_currentUser);
    } else {
      print('UserService - Cannot update image: no current user');
    }
  }

  void updateUserName(String newName) {
    print('UserService - Updating user name to: $newName');
    if (_currentUser != null) {
      _currentUser = UserModel(
        id: _currentUser!.id,
        name: newName,
        username: _currentUser!.username,
        email: _currentUser!.email,
        isActive: _currentUser!.isActive,
        companyIds: _currentUser!.companyIds,
        profileImage: _currentUser!.profileImage,
      );
      print('UserService - User name updated');
      _userController.add(_currentUser);
    } else {
      print('UserService - Cannot update name: no current user');
    }
  }

  Uint8List? getProfileImageBytes() {
    if (_currentUser?.profileImage != null) {
      try {
        return base64Decode(_currentUser!.profileImage!);
      } catch (e) {
        print('Error decoding profile image: $e');
        return null;
      }
    }
    return null;
  }

  // Méthode pour initialiser le service au démarrage
  Future<void> initialize() async {
    if (_currentUser == null && !_isLoading) {
      await loadCurrentUser();
    }
  }

  // Méthode pour forcer le rechargement
  Future<UserModel?> refreshUser() async {
    _currentUser = null;
    _isLoading = false;
    return await loadCurrentUser();
  }

  void dispose() {
    _userController.close();
  }
}
