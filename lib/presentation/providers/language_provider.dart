import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('fr', 'FR'); // Default to French
  bool _isDarkMode = false;

  Locale get locale => _locale;
  bool get isDarkMode => _isDarkMode;

  LanguageProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language') ?? 'Français';
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;

    _locale = _getLocaleFromLanguageName(languageCode);
    notifyListeners();
  }

  Locale _getLocaleFromLanguageName(String languageName) {
    switch (languageName) {
      case 'English':
        return const Locale('en', 'US');
      case 'العربية':
        return const Locale('ar', 'MA');
      case 'Français':
      default:
        return const Locale('fr', 'FR');
    }
  }

  String _getLanguageNameFromLocale(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'ar':
        return 'العربية';
      case 'fr':
      default:
        return 'Français';
    }
  }

  Future<void> changeLanguage(String languageName) async {
    _locale = _getLocaleFromLanguageName(languageName);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageName);

    notifyListeners();
  }

  Future<void> changeTheme(bool isDark) async {
    _isDarkMode = isDark;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);

    notifyListeners();
  }

  String getLanguageName() {
    return _getLanguageNameFromLocale(_locale);
  }
}
