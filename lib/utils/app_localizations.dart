import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Common
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'confirm': 'Confirm',
      'close': 'Close',

      // Profile Settings
      'profile_settings': 'Profile Settings',
      'notifications': 'Notifications',
      'push_notifications': 'Push notifications',
      'receive_push_notifications': 'Receive push notifications',
      'leave_reminders': 'Leave reminders',
      'receive_leave_reminders': 'Receive reminders for upcoming leaves',
      'colleague_birthdays': 'Colleague birthdays',
      'be_notified_birthdays': 'Be notified of birthdays',
      'preferences': 'Preferences',
      'language': 'Language',
      'theme': 'Theme',
      'light': 'Light',
      'dark': 'Dark',
      'save_settings': 'Save settings',
      'settings_saved': 'Settings saved!',
      'language_changed': 'Language changed',
      'light_theme_activated': 'Light theme activated',
      'dark_theme_activated': 'Dark theme activated',

      // Profile
      'my_profile': 'My Profile',
      'personal_employment_info': 'Personal & Employment Info',
      'personal_documents': 'Personal Documents',
      'profile_settings_menu': 'Profile Settings',
      'logout': 'Logout',

      // Documents
      'identity_documents': 'Identity Documents',
      'professional_documents': 'Professional Documents',
      'certificates_diplomas': 'Certificates & Diplomas',
      'other_documents': 'Other Documents',
      'no_documents': 'No documents available',
      'loading_documents': 'Loading documents...',
      'error_loading_documents': 'Error loading documents',

      // Personal Info
      'change_photo': 'Change Photo',
      'personal_information': 'Personal Information',
      'phone': 'Phone',
      'email': 'Email',
      'address': 'Address',
      'employment_information': 'Employment Information',
      'employee_id': 'Employee ID',
      'job_position': 'Job Position',
      'department': 'Department',
      'manager': 'Manager',
      'work_location': 'Work Location',
      'hire_date': 'Hire Date',
      'contract_type': 'Contract Type',
      'work_phone': 'Work Phone',
      'select_photo_source': 'Select Photo Source',
      'gallery': 'Gallery',
      'camera': 'Camera',
      'uploading_photo': 'Uploading photo...',
      'photo_updated': 'Photo updated successfully!',
      'error_uploading': 'Error uploading photo',
      'loading_employee_data': 'Loading employee data...',
      'error_loading_data': 'Error loading data',
      'image_too_large': 'Image too large. Try a smaller image.',
      'connection_timeout': 'Connection timeout. Check your connection.',
      'upload_error': 'Error',
      'loading_error': 'Loading Error',
      'retry': 'Retry',
      'back': 'Back',
      'edit_my_info': 'Edit My Information',
      'choose_photo': 'Choose Photo',

      // Dashboard
      'high_performance': 'High Performance',
      'hr_management': 'HR Management',
      'search_dashboard': 'Search Dashboard',
      'leave_balance_remaining': 'Leave Balance\nRemaining',
      'days_available': 'days available',
      'requests_status': 'Requests\nStatus',
      'in_progress': 'In progress',
      'hr_notifications': 'HR\nNotifications',
      'unread': 'Unread',
      'working_period': 'Working\nPeriod',
      'today': 'Today',
      'team_statistics': 'Team Statistics',
      'team_statistics_data': 'Team Statistics Data',
      'filter': 'Filter',

      // HR Screens
      'employee_management': 'Employee Management',
      'employees': 'Employees',
      'search_employees': 'Search employees...',
      'no_employees_found': 'No employees found',
      'add_employee': 'Add Employee',
      'add_employee_via_odoo': 'Add employees via Odoo',
      'unknown': 'Unknown',
      'no_position': 'No Position',
      'no_department': 'No Department',

      // Manager Dashboard
      'manager_dashboard': 'Manager Dashboard',
      'team_management': 'Team Management',
      'team_approvals': 'Team Approvals',
      'team_members': 'Team Members',
      'team_reports': 'Team Reports',
      'schedule': 'Schedule',
      'team_size': 'Team Size',
      'pending_approvals': 'Pending Approvals',
      'approved_this_week': 'Approved This Week',
      'team_productivity': 'Team Productivity',
      'team_activity': 'Team Activity',
      'view_all': 'View All',
      'online': 'Online',
      'away': 'Away',
      'offline': 'Offline',
      'needs_approval': 'Needs Approval',
      'approved': 'Approved',
      'completed': 'Completed',
      'approve': 'Approve',
      'reject': 'Reject',
      'days': 'days',

      // Employee Drawer
      'menu': 'Menu',
      'dashboard': 'Dashboard',
      'employee_space': 'Employee Space',
      'leaves': 'Leaves',
      'calendar': 'Calendar',
      'request_leave': 'Request Leave',
      'leave_balance': 'Leave Balance',
      'report_unexpected_absence': 'Report Unexpected Absence',
      'working_time': 'Working Time',
      'time_tracking': 'Time Tracking (In/Out)',
      'time_tracking_history': 'My Time Tracking History',
      'pay_benefits': 'Pay & Benefits',
      'salary_information': 'My Salary Information',
      'my_benefits': 'My Benefits',
      'expense_report': 'Expense Report',
      'profile': 'Profile',
      'settings': 'Settings',
    },
    'fr': {
      // Common
      'loading': 'Chargement...',
      'error': 'Erreur',
      'success': 'Succès',
      'cancel': 'Annuler',
      'save': 'Enregistrer',
      'delete': 'Supprimer',
      'edit': 'Modifier',
      'confirm': 'Confirmer',
      'close': 'Fermer',

      // Profile Settings
      'profile_settings': 'Paramètres de profil',
      'notifications': 'Notifications',
      'push_notifications': 'Notifications push',
      'receive_push_notifications': 'Recevoir les notifications push',
      'leave_reminders': 'Rappels de congés',
      'receive_leave_reminders': 'Recevoir des rappels pour les congés à venir',
      'colleague_birthdays': 'Anniversaires des collègues',
      'be_notified_birthdays': 'Être notifié des anniversaires',
      'preferences': 'Préférences',
      'language': 'Langue',
      'theme': 'Thème',
      'light': 'Clair',
      'dark': 'Sombre',
      'save_settings': 'Sauvegarder les paramètres',
      'settings_saved': 'Paramètres sauvegardés!',
      'language_changed': 'Langue changée',
      'light_theme_activated': 'Thème clair activé',
      'dark_theme_activated': 'Thème sombre activé',

      // Profile
      'my_profile': 'Mon profil',
      'personal_employment_info': 'Infos personnelles & emploi',
      'personal_documents': 'Documents personnels',
      'profile_settings_menu': 'Paramètres de profil',
      'logout': 'Déconnexion',

      // Documents
      'identity_documents': 'Documents d\'identité',
      'professional_documents': 'Documents professionnels',
      'certificates_diplomas': 'Certificats et diplômes',
      'other_documents': 'Autres documents',
      'no_documents': 'Aucun document disponible',
      'loading_documents': 'Chargement des documents...',
      'error_loading_documents': 'Erreur lors du chargement des documents',

      // Personal Info
      'change_photo': 'Changer la photo',
      'personal_information': 'Informations personnelles',
      'phone': 'Téléphone',
      'email': 'Email',
      'address': 'Adresse',
      'employment_information': 'Informations d\'emploi',
      'employee_id': 'ID Employé',
      'job_position': 'Poste',
      'department': 'Département',
      'manager': 'Manager',
      'work_location': 'Lieu de travail',
      'hire_date': 'Date d\'embauche',
      'contract_type': 'Type de contrat',
      'work_phone': 'Téléphone professionnel',
      'select_photo_source': 'Sélectionner la source de la photo',
      'gallery': 'Galerie',
      'camera': 'Appareil photo',
      'uploading_photo': 'Téléchargement de la photo...',
      'photo_updated': 'Photo mise à jour avec succès!',
      'error_uploading': 'Erreur lors du téléchargement',
      'loading_employee_data': 'Chargement des données...',
      'error_loading_data': 'Erreur lors du chargement',
      'image_too_large':
          'Image trop volumineuse. Essayez avec une image plus petite.',
      'connection_timeout':
          'Temps d\'attente dépassé. Vérifiez votre connexion.',
      'upload_error': 'Erreur',
      'loading_error': 'Erreur de chargement',
      'retry': 'Réessayer',
      'back': 'Retour',
      'edit_my_info': 'Modifier mes informations',
      'choose_photo': 'Choisir une photo',

      // Dashboard
      'high_performance': 'High Performance',
      'hr_management': 'Gestion RH',
      'search_dashboard': 'Rechercher Dashboard',
      'leave_balance_remaining': 'Solde des Congés\nRestants',
      'days_available': 'jours disponibles',
      'requests_status': 'État des\nDemandes',
      'in_progress': 'En cours',
      'hr_notifications': 'Notifications\nRH',
      'unread': 'Non lues',
      'working_period': 'Temps de\nTravail',
      'today': 'Aujourd\'hui',
      'team_statistics': 'Statistiques d\'Équipe',
      'team_statistics_data': 'Données Statistiques d\'Équipe',
      'filter': 'Filtre',

      // HR Screens
      'employee_management': 'Gestion des Employés',
      'employees': 'Employés',
      'search_employees': 'Rechercher des employés...',
      'no_employees_found': 'Aucun employé trouvé',
      'add_employee': 'Ajouter un Employé',
      'add_employee_via_odoo': 'Ajoutez des employés via Odoo',
      'unknown': 'Inconnu',
      'no_position': 'Aucun Poste',
      'no_department': 'Aucun Département',

      // Manager Dashboard
      'manager_dashboard': 'Tableau de Bord Manager',
      'team_management': 'Gestion d\'Équipe',
      'team_approvals': 'Approbations d\'Équipe',
      'team_members': 'Membres de l\'Équipe',
      'team_reports': 'Rapports d\'Équipe',
      'schedule': 'Planning',
      'team_size': 'Taille de l\'Équipe',
      'pending_approvals': 'Approbations en Attente',
      'approved_this_week': 'Approuvés cette Semaine',
      'team_productivity': 'Productivité de l\'Équipe',
      'team_activity': 'Activité de l\'Équipe',
      'view_all': 'Voir Tout',
      'online': 'En ligne',
      'away': 'Absent',
      'offline': 'Hors ligne',
      'needs_approval': 'Nécessite Approbation',
      'approved': 'Approuvé',
      'completed': 'Terminé',
      'approve': 'Approuver',
      'reject': 'Refuser',
      'days': 'jours',

      // Employee Drawer
      'menu': 'Menu',
      'dashboard': 'Tableau de bord',
      'employee_space': 'Espace Employé',
      'leaves': 'Congés',
      'calendar': 'Calendrier',
      'request_leave': 'Demander un congé',
      'leave_balance': 'Solde de congés',
      'report_unexpected_absence': 'Déclarer une absence imprévue',
      'working_time': 'Temps de travail',
      'time_tracking': 'Pointage (Entrée / Sortie)',
      'time_tracking_history': 'Historique de mes pointages',
      'pay_benefits': 'Paie & avantages',
      'salary_information': 'Mes informations salariales',
      'my_benefits': 'Mes avantages',
      'expense_report': 'Note de frais',
      'profile': 'Profil',
      'settings': 'Paramètres',
    },
    'ar': {
      // Common
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'success': 'نجح',
      'cancel': 'إلغاء',
      'save': 'حفظ',
      'delete': 'حذف',
      'edit': 'تعديل',
      'confirm': 'تأكيد',
      'close': 'إغلاق',

      // Profile Settings
      'profile_settings': 'إعدادات الملف الشخصي',
      'notifications': 'الإشعارات',
      'push_notifications': 'الإشعارات الفورية',
      'receive_push_notifications': 'استقبال الإشعارات الفورية',
      'leave_reminders': 'تذكيرات الإجازة',
      'receive_leave_reminders': 'استقبال تذكيرات الإجازات القادمة',
      'colleague_birthdays': 'أعياد ميلاد الزملاء',
      'be_notified_birthdays': 'تلقي إشعارات أعياد الميلاد',
      'preferences': 'التفضيلات',
      'language': 'اللغة',
      'theme': 'المظهر',
      'light': 'فاتح',
      'dark': 'داكن',
      'save_settings': 'حفظ الإعدادات',
      'settings_saved': 'تم حفظ الإعدادات!',
      'language_changed': 'تم تغيير اللغة',
      'light_theme_activated': 'تم تفعيل المظهر الفاتح',
      'dark_theme_activated': 'تم تفعيل المظهر الداكن',

      // Profile
      'my_profile': 'ملفي الشخصي',
      'personal_employment_info': 'المعلومات الشخصية والوظيفية',
      'personal_documents': 'المستندات الشخصية',
      'profile_settings_menu': 'إعدادات الملف الشخصي',
      'logout': 'تسجيل الخروج',

      // Documents
      'identity_documents': 'وثائق الهوية',
      'professional_documents': 'المستندات المهنية',
      'certificates_diplomas': 'الشهادات والدبلومات',
      'other_documents': 'مستندات أخرى',
      'no_documents': 'لا توجد مستندات متاحة',
      'loading_documents': 'جاري تحميل المستندات...',
      'error_loading_documents': 'خطأ في تحميل المستندات',

      // Personal Info
      'change_photo': 'تغيير الصورة',
      'personal_information': 'المعلومات الشخصية',
      'phone': 'الهاتف',
      'email': 'البريد الإلكتروني',
      'address': 'العنوان',
      'employment_information': 'معلومات الوظيفة',
      'employee_id': 'رقم الموظف',
      'job_position': 'المنصب',
      'department': 'القسم',
      'manager': 'المدير',
      'work_location': 'مكان العمل',
      'hire_date': 'تاريخ التوظيف',
      'contract_type': 'نوع العقد',
      'work_phone': 'هاتف العمل',
      'select_photo_source': 'اختر مصدر الصورة',
      'gallery': 'المعرض',
      'camera': 'الكاميرا',
      'uploading_photo': 'جاري رفع الصورة...',
      'photo_updated': 'تم تحديث الصورة بنجاح!',
      'error_uploading': 'خطأ في رفع الصورة',
      'loading_employee_data': 'جاري تحميل البيانات...',
      'error_loading_data': 'خطأ في تحميل البيانات',
      'image_too_large': 'الصورة كبيرة جدًا. جرب صورة أصغر.',
      'connection_timeout': 'انتهت مهلة الاتصال. تحقق من اتصالك.',
      'upload_error': 'خطأ',
      'loading_error': 'خطأ في التحميل',
      'retry': 'إعادة المحاولة',
      'back': 'رجوع',
      'edit_my_info': 'تعديل معلوماتي',
      'choose_photo': 'اختر صورة',

      // Dashboard
      'high_performance': 'الأداء العالي',
      'hr_management': 'إدارة الموارد البشرية',
      'search_dashboard': 'بحث لوحة التحكم',
      'leave_balance_remaining': 'رصيد الإجازات\nالمتبقي',
      'days_available': 'أيام متاحة',
      'requests_status': 'حالة\nالطلبات',
      'in_progress': 'قيد التنفيذ',
      'hr_notifications': 'إشعارات\nالموارد البشرية',
      'unread': 'غير مقروء',
      'working_period': 'فترة\nالعمل',
      'today': 'اليوم',
      'team_statistics': 'إحصائيات الفريق',
      'team_statistics_data': 'بيانات إحصائيات الفريق',
      'filter': 'تصفية',

      // HR Screens
      'employee_management': 'إدارة الموظفين',
      'employees': 'الموظفون',
      'search_employees': 'البحث عن الموظفين...',
      'no_employees_found': 'لم يتم العثور على موظفين',
      'add_employee': 'إضافة موظف',
      'add_employee_via_odoo': 'إضافة الموظفين عبر Odoo',
      'unknown': 'غير معروف',
      'no_position': 'لا يوجد منصب',
      'no_department': 'لا يوجد قسم',

      // Manager Dashboard
      'manager_dashboard': 'لوحة التحكم للمدير',
      'team_management': 'إدارة الفريق',
      'team_approvals': 'موافقات الفريق',
      'team_members': 'أعضاء الفريق',
      'team_reports': 'تقارير الفريق',
      'schedule': 'الجدول الزمني',
      'team_size': 'حجم الفريق',
      'pending_approvals': 'الموافقات المعلقة',
      'approved_this_week': 'تمت الموافقة هذا الأسبوع',
      'team_productivity': 'إنتاجية الفريق',
      'team_activity': 'نشاط الفريق',
      'view_all': 'عرض الكل',
      'online': 'متصل',
      'away': 'بعيد',
      'offline': 'غير متصل',
      'needs_approval': 'يحتاج موافقة',
      'approved': 'تمت الموافقة',
      'completed': 'مكتمل',
      'approve': 'موافقة',
      'reject': 'رفض',
      'days': 'أيام',

      // Employee Drawer
      'menu': 'القائمة',
      'dashboard': 'لوحة التحكم',
      'employee_space': 'مساحة الموظف',
      'leaves': 'الإجازات',
      'calendar': 'التقويم',
      'request_leave': 'طلب إجازة',
      'leave_balance': 'رصيد الإجازات',
      'report_unexpected_absence': 'الإبلاغ عن غياب غير متوقع',
      'working_time': 'وقت العمل',
      'time_tracking': 'التوقيت (الدخول / الخروج)',
      'time_tracking_history': 'سجل التوقيت الخاص بي',
      'pay_benefits': 'الرواتب والمزايا',
      'salary_information': 'معلومات الراتب الخاصة بي',
      'my_benefits': 'مزاياي',
      'expense_report': 'تقرير المصروفات',
      'profile': 'الملف الشخصي',
      'settings': 'الإعدادات',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  String get profileSettings => translate('profile_settings');
  String get notifications => translate('notifications');
  String get pushNotifications => translate('push_notifications');
  String get receivePushNotifications =>
      translate('receive_push_notifications');
  String get leaveReminders => translate('leave_reminders');
  String get receiveLeaveReminders => translate('receive_leave_reminders');
  String get colleagueBirthdays => translate('colleague_birthdays');
  String get beNotifiedBirthdays => translate('be_notified_birthdays');
  String get preferences => translate('preferences');
  String get language => translate('language');
  String get theme => translate('theme');
  String get light => translate('light');
  String get dark => translate('dark');
  String get saveSettings => translate('save_settings');
  String get settingsSaved => translate('settings_saved');
  String get languageChanged => translate('language_changed');
  String get lightThemeActivated => translate('light_theme_activated');
  String get darkThemeActivated => translate('dark_theme_activated');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'fr', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
