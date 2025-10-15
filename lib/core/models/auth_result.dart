import '../../data/models/user_model.dart';
import '../../data/models/company_model.dart';

class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final UserModel? user;
  final List<CompanyModel>? companies;

  const AuthResult._({
    required this.isSuccess,
    this.errorMessage,
    this.user,
    this.companies,
  });

  factory AuthResult.success(UserModel user, List<CompanyModel> companies) {
    return AuthResult._(
      isSuccess: true,
      user: user,
      companies: companies,
    );
  }

  factory AuthResult.failure(String errorMessage) {
    return AuthResult._(
      isSuccess: false,
      errorMessage: errorMessage,
    );
  }
}
