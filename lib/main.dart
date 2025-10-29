import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/company_selection_screen.dart';
import 'screens/employee_dashboard.dart';
import 'screens/profile_screen.dart';
import 'screens/hr_dashboard_new.dart';
import 'screens/manager_dashboard.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/company_provider.dart';
import 'presentation/providers/leave_provider.dart';
import 'presentation/providers/language_provider.dart';
import 'presentation/providers/dashboard_provider.dart';
import 'utils/app_localizations.dart';
import 'screens/leave_calendar_screen.dart';
import 'screens/leave_request_screen.dart';
import 'screens/leave_balance_screen.dart';
import 'screens/personal_info_screen.dart';
import 'screens/personal_documents_screen.dart';
import 'screens/profile_settings_screen.dart';
import 'screens/hr_employee_management_screen.dart';
import 'screens/leave_management_screen.dart';
import 'screens/employee_notifications_screen.dart';
import 'screens/hr_notifications_screen.dart';
import 'screens/hr_sent_notifications_screen.dart';
import 'screens/employee_tasks_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/attendance_history_screen.dart';
import 'screens/work_time_statistics_screen.dart';
import 'screens/expense_reports_screen.dart';
import 'data/models/employee_model.dart';
import 'services/user_service.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser le service utilisateur au démarrage
  await UserService.instance.initialize();

  // Initialize Odoo Notification Service
  await OdooNotificationService().initialize();

  runApp(const HRManagementApp());
}

class HRManagementApp extends StatelessWidget {
  const HRManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CompanyProvider()),
        ChangeNotifierProvider(create: (_) => LeaveProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            title: 'HR Management',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              brightness: languageProvider.isDarkMode
                  ? Brightness.dark
                  : Brightness.light,
            ),
            locale: languageProvider.locale,
            supportedLocales: const [
              Locale('fr', 'FR'), // Primary: French
              Locale('en', 'US'), // English
              Locale('ar', 'MA'), // Arabic
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const WelcomeScreen(),
            debugShowCheckedModeBanner: false,
            routes: {
              '/login': (context) => const LoginScreen(),
              '/company-selection': (context) => const CompanySelectionScreen(),
              '/employee-dashboard': (context) => const EmployeeDashboard(),
              '/hr-dashboard': (context) => const HRDashboardNew(),
              '/manager-dashboard': (context) => const ManagerDashboard(),
              '/leave-calendar': (context) => const LeaveCalendarScreen(),
              '/leave-request': (context) => const LeaveRequestScreen(),
              '/leave-balance': (context) => const LeaveBalanceScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/personal-info': (context) => const PersonalInfoScreen(),
              '/personal-documents': (context) =>
                  const PersonalDocumentsScreen(),
              '/profile-settings': (context) => const ProfileSettingsScreen(),
              '/hr-employees': (context) => const HREmployeeManagementScreen(
                    showAllEmployees: true, // HR sees all employees
                  ),
              '/manager-employees': (context) =>
                  const HREmployeeManagementScreen(
                    showAllEmployees:
                        true, // Manager sees all employees under their management
                  ),
              '/leave-management': (context) => const LeaveManagementScreen(),
              '/employee-notifications': (context) =>
                  const EmployeeNotificationsScreen(),
              '/employee-tasks': (context) => EmployeeTasksScreen(
                    employee: Employee(
                      id: 1, // This should be the current employee ID
                      name: 'Employee Name',
                      email: 'employee@example.com',
                      isActive: true,
                    ),
                  ),
              '/hr-notifications': (context) => const HRNotificationsScreen(),
              '/hr-sent-notifications': (context) =>
                  const HRSentNotificationsScreen(),
              '/attendance': (context) => const AttendanceScreen(),
              '/attendance-history': (context) =>
                  const AttendanceHistoryScreen(),
              '/work-time-statistics': (context) =>
                  const WorkTimeStatisticsScreen(),
              '/expense-reports': (context) => const ExpenseReportsScreen(),
            },
          );
        },
      ),
    );
  }
}
