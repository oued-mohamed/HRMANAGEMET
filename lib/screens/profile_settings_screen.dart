import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../presentation/providers/language_provider.dart';
import '../utils/app_localizations.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  bool _pushNotifications = true;
  bool _leaveReminders = true;
  bool _birthdayNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = prefs.getBool('pushNotifications') ?? true;
      _leaveReminders = prefs.getBool('leaveReminders') ?? true;
      _birthdayNotifications = prefs.getBool('birthdayNotifications') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.profileSettings,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF000B58),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF000B58),
              Color(0xFF35BF8C),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Notifications Section
            _buildSectionTitle(localizations.notifications),
            const SizedBox(height: 16),

            _buildSwitchCard(
              icon: Icons.notifications_outlined,
              title: localizations.pushNotifications,
              subtitle: localizations.receivePushNotifications,
              value: _pushNotifications,
              onChanged: (value) {
                setState(() {
                  _pushNotifications = value;
                });
              },
            ),

            _buildSwitchCard(
              icon: Icons.event_available_outlined,
              title: localizations.leaveReminders,
              subtitle: localizations.receiveLeaveReminders,
              value: _leaveReminders,
              onChanged: (value) {
                setState(() {
                  _leaveReminders = value;
                });
              },
            ),

            _buildSwitchCard(
              icon: Icons.cake_outlined,
              title: localizations.colleagueBirthdays,
              subtitle: localizations.beNotifiedBirthdays,
              value: _birthdayNotifications,
              onChanged: (value) {
                setState(() {
                  _birthdayNotifications = value;
                });
              },
            ),

            const SizedBox(height: 32),

            // Preferences Section
            _buildSectionTitle(localizations.preferences),
            const SizedBox(height: 16),

            _buildLanguageCard(languageProvider, localizations),

            _buildThemeCard(languageProvider, localizations),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _saveSettings(languageProvider, localizations),
                icon: const Icon(Icons.save),
                label: Text(localizations.saveSettings),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF000B58),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Future<void> _saveSettings(
      LanguageProvider languageProvider, AppLocalizations localizations) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('pushNotifications', _pushNotifications);
    await prefs.setBool('leaveReminders', _leaveReminders);
    await prefs.setBool('birthdayNotifications', _birthdayNotifications);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      localizations.settingsSaved,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${localizations.language}: ${languageProvider.getLanguageName()} • ${localizations.theme}: ${languageProvider.isDarkMode ? localizations.dark : localizations.light}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF35BF8C),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildLanguageCard(
      LanguageProvider languageProvider, AppLocalizations localizations) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.language_outlined, color: Colors.white),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              localizations.language,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          DropdownButton<String>(
            value: languageProvider.getLanguageName(),
            items: ['Français', 'العربية', 'English'].map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: (value) async {
              if (value != null) {
                await languageProvider.changeLanguage(value);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${localizations.languageChanged}: $value'),
                      backgroundColor: const Color(0xFF35BF8C),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              }
            },
            dropdownColor: const Color(0xFF000B58),
            style: const TextStyle(color: Colors.white),
            underline: Container(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(
      LanguageProvider languageProvider, AppLocalizations localizations) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.palette_outlined, color: Colors.white),
              const SizedBox(width: 16),
              Text(
                localizations.theme,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildThemeButton(
                  label: localizations.light,
                  icon: Icons.light_mode,
                  isSelected: !languageProvider.isDarkMode,
                  onTap: () async {
                    await languageProvider.changeTheme(false);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(localizations.lightThemeActivated),
                          backgroundColor: const Color(0xFF35BF8C),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThemeButton(
                  label: localizations.dark,
                  icon: Icons.dark_mode,
                  isSelected: languageProvider.isDarkMode,
                  onTap: () async {
                    await languageProvider.changeTheme(true);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(localizations.darkThemeActivated),
                          backgroundColor: const Color(0xFF35BF8C),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF35BF8C)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF35BF8C)
                : Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF35BF8C),
            activeTrackColor: const Color(0xFF35BF8C).withOpacity(0.5),
          ),
        ],
      ),
    );
  }
}
