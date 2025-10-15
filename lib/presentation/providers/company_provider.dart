import 'package:flutter/material.dart';
import '../../data/models/company_model.dart';

class CompanyProvider extends ChangeNotifier {
  CompanyModel? _currentCompany;
  List<CompanyModel>? _availableCompanies;

  CompanyModel? get currentCompany => _currentCompany;
  List<CompanyModel>? get availableCompanies => _availableCompanies;

  void setCurrentCompany(CompanyModel company) {
    _currentCompany = company;
    notifyListeners();
  }

  void setAvailableCompanies(List<CompanyModel> companies) {
    _availableCompanies = companies;
    notifyListeners();
  }

  void clearCurrentCompany() {
    _currentCompany = null;
    notifyListeners();
  }
}
