import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../presentation/providers/language_provider.dart';
import '../utils/navigation_helpers.dart';
import '../utils/responsive_helper.dart';
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

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        // Handle Android back button - same functionality as AppBar back button
        await NavigationHelpers.backToMenu(context);
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavigationHelpers.backToMenu(context),
        ),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = ResponsiveHelper.isTablet(context);
            final isDesktop = ResponsiveHelper.isDesktop(context);
            
            Widget content = ListView(
              padding: ResponsiveHelper.responsivePadding(context),
              children: [
            // Notifications Section
            _buildSectionTitle(context, localizations.notifications),
            SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 16)),

            _buildSwitchCard(
              context: context,
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
              context: context,
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
              context: context,
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

            SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 32)),

            // Preferences Section
            _buildSectionTitle(context, localizations.preferences),
            SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 16)),

            _buildLanguageCard(context, languageProvider, localizations),

            SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 32)),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _saveSettings(languageProvider, localizations),
                icon: Icon(
                  Icons.save,
                  size: ResponsiveHelper.responsiveIconSize(context, mobile: 20.0, tablet: 24.0),
                ),
                label: Text(
                  localizations.saveSettings,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 16.0, tablet: 18.0),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF000B58),
                  padding: EdgeInsets.symmetric(
                    vertical: ResponsiveHelper.responsiveValue(context, mobile: 16.0, tablet: 20.0),
                    horizontal: ResponsiveHelper.responsiveValue(context, mobile: 16.0, tablet: 24.0),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      ResponsiveHelper.responsiveBorderRadius(context, mobile: 12.0, tablet: 16.0),
                    ),
                  ),
                ),
              ),
            ),

                SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 20)),
              ],
            );

            // Center and constrain width on tablets/desktop
            if (isTablet || isDesktop) {
              content = Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: ResponsiveHelper.cardMaxWidth(context) ?? double.infinity,
                  ),
                  child: content,
                ),
              );
            }

            return content;
          },
        ),
      ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 20.0, tablet: 24.0, desktop: 28.0),
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
                      '${localizations.language}: ${languageProvider.getLanguageName()}',
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
      BuildContext context, LanguageProvider languageProvider, AppLocalizations localizations) {
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.responsiveValue(context, mobile: 12.0, tablet: 16.0)),
      padding: EdgeInsets.all(
        ResponsiveHelper.responsiveValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.responsiveBorderRadius(context, mobile: 12.0, tablet: 16.0),
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.language_outlined,
            color: Colors.white,
            size: ResponsiveHelper.responsiveIconSize(context, mobile: 24.0, tablet: 28.0),
          ),
          SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 16)),
          Expanded(
            child: Text(
              localizations.language,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 16.0, tablet: 18.0),
              ),
            ),
          ),
          DropdownButton<String>(
            value: languageProvider.getLanguageName(),
            items: ['Français', 'العربية', 'English'].map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 16.0, tablet: 18.0),
                  ),
                ),
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
            style: TextStyle(
              color: Colors.white,
              fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 16.0, tablet: 18.0),
            ),
            underline: Container(),
            icon: Icon(
              Icons.arrow_drop_down,
              color: Colors.white,
              size: ResponsiveHelper.responsiveIconSize(context, mobile: 24.0, tablet: 28.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.responsiveValue(context, mobile: 12.0, tablet: 16.0)),
      padding: EdgeInsets.all(
        ResponsiveHelper.responsiveValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.responsiveBorderRadius(context, mobile: 12.0, tablet: 16.0),
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: ResponsiveHelper.responsiveIconSize(context, mobile: 24.0, tablet: 28.0),
          ),
          SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 16.0, tablet: 18.0),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.responsiveValue(context, mobile: 4.0, tablet: 6.0)),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: ResponsiveHelper.responsiveFontSize(context, mobile: 12.0, tablet: 14.0),
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
