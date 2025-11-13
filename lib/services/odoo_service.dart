import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'sync_service.dart';

class OdooService {
  // Singleton instance so auth state (uid/password) is shared across providers
  static final OdooService _singleton = OdooService._internal();
  factory OdooService() => _singleton;
  OdooService._internal();
  // Use local proxy on web to avoid CORS; direct host on mobile/desktop
  static String get baseUrl {
    // kIsWeb lives in foundation.dart but we avoid importing Flutter here.
    // Instead, read from const bool.fromEnvironment provided at build time.
    const isWeb = bool.fromEnvironment('dart.library.html');
    return isWeb ? 'http://localhost:8081' : 'https://pointy.dbc.ma';
  }

  static const String database = 'dev';

  // String? _sessionId; // Reserved for future session-based authentication
  int? _userId;
  String? _password;

  // -------- In-memory caching (per app session) --------
  // Keep lightweight caches to avoid reloading the same datasets across screens
  // These are cleared only on explicit refresh or re-login.
  List<Map<String, dynamic>>? _cachedDirectReports;
  DateTime? _cachedDirectReportsAt;

  List<Map<String, dynamic>>? _cachedAllManagedEmployees;
  DateTime? _cachedAllManagedEmployeesAt;

  final Map<int, List<Map<String, dynamic>>> _employeeAttendanceCache = {};
  final Map<int, DateTime> _employeeAttendanceCachedAt = {};

  List<Map<String, dynamic>>? _cachedTeamMembers;
  DateTime? _cachedTeamMembersAt;

  List<Map<String, dynamic>>? _cachedPendingTeamLeaves;
  DateTime? _cachedPendingTeamLeavesAt;

  List<Map<String, dynamic>>? _cachedLeaveTypes;
  DateTime? _cachedLeaveTypesAt;

  List<Map<String, dynamic>>? _cachedPunchingEntities;
  DateTime? _cachedPunchingEntitiesAt;

  // Default cache lifetime
  static const Duration _defaultCacheTtl = Duration(minutes: 5);

  void clearEmployeeCaches() {
    _cachedDirectReports = null;
    _cachedDirectReportsAt = null;
    _cachedAllManagedEmployees = null;
    _cachedAllManagedEmployeesAt = null;
    _employeeAttendanceCache.clear();
    _employeeAttendanceCachedAt.clear();
    _cachedTeamMembers = null;
    _cachedTeamMembersAt = null;
    _cachedPendingTeamLeaves = null;
    _cachedPendingTeamLeavesAt = null;
    _cachedLeaveTypes = null;
    _cachedLeaveTypesAt = null;
    _cachedPunchingEntities = null;
    _cachedPunchingEntitiesAt = null;
  }

  // Login method
  Future<bool> login(String username, String password) async {
    print('OdooService.login called');
    print('Username: $username');
    print('Database: $database');
    print('Base URL: $baseUrl');

    try {
      _password = password; // Store for subsequent calls

      print('Calling XML-RPC authenticate...');
      final response = await _callRPC(
          'common', 'authenticate', [database, username, password, {}]);

      print('Authenticate response: $response');
      print('Response type: ${response.runtimeType}');

      if (response is int && response > 0) {
        _userId = response;
        print('Login successful! User ID: $_userId');
        return true;
      }

      print('Login failed - invalid response');
      return false;
    } catch (e) {
      print('Login error: $e');
      print('Error type: ${e.runtimeType}');
      return false;
    }
  }

  // Get user info and companies
  Future<Map<String, dynamic>> getUserInfo() async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    final userData = await _callRPC('object', 'execute', [
      database,
      _userId,
      _password,
      'res.users',
      'read',
      [_userId!],
      ['name', 'email', 'company_ids', 'groups_id']
    ]);

    return userData.first;
  }

  // Get current employee ID for the logged-in user
  Future<int> getCurrentEmployeeId() async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    final employee = await _callRPC('object', 'execute', [
      database,
      _userId,
      _password,
      'hr.employee',
      'search',
      [
        ['user_id', '=', _userId]
      ]
    ]);

    if (employee.isEmpty) {
      throw Exception('No employee record found for user');
    }

    return employee.first;
  }

  // Get complete employee details
  Future<Map<String, dynamic>> getEmployeeDetails() async {
    print('Fetching employee details...');

    try {
      final employeeId = await getCurrentEmployeeId();
      print('Employee ID: $employeeId');

      // First, get basic employee info with minimal fields
      final employeeData = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'read',
        [employeeId],
        {
          'fields': [
            'name',
            'work_email',
            'work_phone',
            'mobile_phone',
            'birthday',
            'job_id',
            'department_id',
            'parent_id',
            'barcode',
            'company_id',
            'image_1920',
          ],
          'context': {'lang': 'fr_FR'}
        }
      ]);

      print('Employee data fetched successfully');

      if (employeeData is List && employeeData.isNotEmpty) {
        final data = Map<String, dynamic>.from(employeeData.first);

        // Get additional user info safely
        try {
          final userInfo = await getUserInfo();
          data['user_name'] = userInfo['name'];
          data['user_email'] = userInfo['email'];
        } catch (e) {
          print('Could not fetch user info: $e');
        }

        return data;
      }

      throw Exception('Aucune donnée d\'employé trouvée');
    } catch (e) {
      print('Error fetching employee details: $e');

      // Return a more user-friendly error message
      if (e.toString().contains('XML-RPC fault')) {
        throw Exception(
            'Erreur de communication avec le serveur Odoo. Vérifiez vos permissions.');
      } else if (e.toString().contains('No employee record')) {
        throw Exception('Aucun profil employé associé à votre compte.');
      } else {
        throw Exception('Erreur: ${e.toString()}');
      }
    }
  }

  // Update employee photo
  Future<bool> updateEmployeePhoto(String base64Image) async {
    final syncService = SyncService();

    // Check if offline - queue operation if so
    if (!syncService.isConnected) {
      print('📴 Offline: Queueing photo update for sync');
      await syncService.queueOperation(
        operationType: SyncService.opEmployeePhotoUpdate,
        operationData: {
          'base64Image': base64Image,
        },
      );
      return true; // Return success immediately for offline mode
    }

    print('Updating employee photo...');

    try {
      final employeeId = await getCurrentEmployeeId();
      print('Employee ID: $employeeId');

      final result = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'write',
        [
          [employeeId],
          {
            'image_1920': base64Image,
          }
        ],
        {
          'context': {'lang': 'fr_FR'}
        }
      ]);

      print('Photo update result: $result');
      return result == true;
    } catch (e) {
      print('Error updating employee photo: $e');
      rethrow;
    }
  }

  // Update individual employee field
  Future<bool> updateEmployeeField(String fieldKey, String newValue) async {
    final syncService = SyncService();

    // Check if offline - queue operation if so
    if (!syncService.isConnected) {
      print('📴 Offline: Queueing field update for sync');
      await syncService.queueOperation(
        operationType: SyncService.opEmployeeUpdate,
        operationData: {
          'fieldKey': fieldKey,
          'newValue': newValue,
        },
      );
      return true; // Return success immediately for offline mode
    }

    print('Updating employee field: $fieldKey to $newValue');

    try {
      final employeeId = await getCurrentEmployeeId();
      print('Employee ID: $employeeId');

      // Special handling for 'name' field - update in res.users instead of hr.employee
      if (fieldKey == 'name') {
        print('Updating name in res.users table');

        final result = await _callRPC('object', 'execute_kw', [
          database,
          _userId,
          _password,
          'res.users',
          'write',
          [
            [_userId!], // Update current user
            {'name': newValue}
          ],
          {
            'context': {'lang': 'fr_FR'}
          }
        ]);

        print('Name update result: $result');
        return result == true;
      }

      // For other fields, update in hr.employee
      Map<String, dynamic> fieldData = {fieldKey: newValue};

      final result = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'write',
        [
          [employeeId],
          fieldData
        ],
        {
          'context': {'lang': 'fr_FR'}
        }
      ]);

      print('Field update result: $result');
      return result == true;
    } catch (e) {
      print('Error updating employee field: $e');
      rethrow;
    }
  }

  // Get unread notifications for current user
  Future<List<Map<String, dynamic>>> getUnreadNotifications() async {
    print('Fetching unread notifications...');

    try {
      final employeeId = await getCurrentEmployeeId();
      print('Employee ID: $employeeId');
      print('Current user ID: $_userId');

      // Get employee's user ID and partner ID
      final employeeData = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'read',
        [employeeId],
        {
          'fields': ['user_id']
        }
      ]);

      if (employeeData is List && employeeData.isNotEmpty) {
        final userData = employeeData.first;
        final userId = userData['user_id'];

        if (userId is List && userId.isNotEmpty) {
          print('Searching for notifications for user ID: ${userId[0]}');

          // Get the partner_id from the user (partner_ids field contains res.partner IDs, not res.users IDs)
          int? partnerId;
          try {
            final userInfo = await _callRPC('object', 'execute_kw', [
              database,
              _userId,
              _password,
              'res.users',
              'read',
              [userId[0]],
              {
                'fields': ['partner_id']
              }
            ]);

            if (userInfo is List && userInfo.isNotEmpty) {
              final userPartner = userInfo.first['partner_id'];
              if (userPartner is List && userPartner.isNotEmpty) {
                partnerId = userPartner[0] as int;
                print('Found partner ID: $partnerId for user ID: ${userId[0]}');
              }
            }
          } catch (e) {
            print('Error getting partner_id from user: $e');
          }

          // If no partner_id found, return empty list
          if (partnerId == null) {
            print(
                '⚠️ No partner_id found for user, cannot fetch notifications');
            return [];
          }

          // Fetch mail.message notifications sent to this user's partner
          // This matches the original logic from GitHub
          final notifications = await _callRPC('object', 'execute_kw', [
            database,
            _userId,
            _password,
            'mail.message',
            'search_read',
            [
              [
                [
                  'partner_ids',
                  'in',
                  [partnerId]
                ],
                ['message_type', '=', 'notification'],
              ]
            ],
            {
              'fields': [
                'id',
                'subject',
                'body',
                'create_date',
                'partner_ids',
                'model',
                'res_id',
              ],
              'order': 'create_date desc',
              'limit': 50,
              'context': {'lang': 'fr_FR'}
            }
          ]);

          print(
              'Found ${notifications is List ? notifications.length : 0} mail.message notifications');

          if (notifications is List) {
            // Get read status from mail.notification for all messages
            final messageIds = notifications
                .where((item) =>
                    item is Map<String, dynamic> && item['id'] != null)
                .map((item) => (item as Map<String, dynamic>)['id'] as int)
                .toList();

            Map<int, bool> readStatusMap = {};
            if (messageIds.isNotEmpty) {
              try {
                final mailNotifications =
                    await _callRPC('object', 'execute_kw', [
                  database,
                  _userId,
                  _password,
                  'mail.notification',
                  'search_read',
                  [
                    [
                      ['mail_message_id', 'in', messageIds],
                      ['res_partner_id', '=', partnerId],
                    ]
                  ],
                  {
                    'fields': ['mail_message_id', 'is_read'],
                  }
                ]);

                if (mailNotifications is List) {
                  for (var notif in mailNotifications) {
                    if (notif is Map<String, dynamic>) {
                      final msgId = notif['mail_message_id'];
                      final isRead = notif['is_read'] ?? false;
                      if (msgId is List && msgId.isNotEmpty) {
                        readStatusMap[msgId[0] as int] = isRead == true;
                      } else if (msgId is int) {
                        readStatusMap[msgId] = isRead == true;
                      }
                    }
                  }
                }
              } catch (e) {
                print('Error fetching read status: $e');
                // Continue with all notifications marked as unread if we can't fetch status
              }
            }

            final List<Map<String, dynamic>> validNotifications = [];
            for (var item in notifications) {
              if (item is Map<String, dynamic>) {
                // Convert false values to null/empty for string fields
                // Odoo returns false for empty fields, but we need strings
                final subject = item['subject'];
                final body = item['body'];
                final createDate = item['create_date'];
                final model = item['model'];
                final resId = item['res_id'];
                final messageId = item['id'] as int;

                // Get read status from map, default to false if not found
                final isRead = readStatusMap[messageId] ?? false;

                // Transform mail.message data to notification format
                validNotifications.add({
                  'id': messageId,
                  'title': (subject == false || subject == null)
                      ? 'Notification'
                      : subject.toString(),
                  'message':
                      (body == false || body == null) ? '' : body.toString(),
                  'type': 'hr_notification',
                  'data': {
                    'message_id': messageId,
                    'subject': (subject == false || subject == null)
                        ? null
                        : subject.toString(),
                    'body': (body == false || body == null)
                        ? null
                        : body.toString(),
                    'model': (model == false || model == null)
                        ? null
                        : model.toString(),
                    'res_id': resId,
                  },
                  'create_date': (createDate == false || createDate == null)
                      ? null
                      : createDate.toString(),
                  'employee_id': employeeId,
                  'is_read': isRead,
                });
              }
            }
            return validNotifications;
          }

          return [];
        }
      }

      return [];
    } catch (e) {
      print('Error fetching unread notifications: $e');
      return [];
    }
  }

  // Get tasks assigned to current employee using project.task
  Future<List<Map<String, dynamic>>> getEmployeeTasks() async {
    print('Fetching tasks for current employee...');

    try {
      final employeeId = await getCurrentEmployeeId();
      print('Employee ID: $employeeId');

      // Get employee's user ID
      final employeeData = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'read',
        [employeeId],
        {
          'fields': ['user_id']
        }
      ]);

      if (employeeData is List && employeeData.isNotEmpty) {
        final userData = employeeData.first;
        final userId = userData['user_id'];

        if (userId is List && userId.isNotEmpty) {
          final tasks = await _callRPC('object', 'execute_kw', [
            database,
            _userId,
            _password,
            'project.task',
            'search_read',
            [
              [
                [
                  'user_ids',
                  'in',
                  [userId[0]]
                ]
              ]
            ],
            {
              'fields': [
                'id',
                'name',
                'description',
                'priority',
                'date_deadline',
                'stage_id',
                'create_date',
                'user_ids'
              ],
              'order': 'create_date desc',
              'limit': 50,
              'context': {'lang': 'fr_FR'}
            }
          ]);

          print('Found ${tasks is List ? tasks.length : 0} tasks');

          if (tasks is List) {
            final List<Map<String, dynamic>> validTasks = [];
            for (var item in tasks) {
              if (item is Map<String, dynamic>) {
                // Transform project.task data to match our expected format
                validTasks.add({
                  'id': item['id'],
                  'title': item['name'],
                  'description': item['description'] ?? '',
                  'priority': _mapOdooPriorityToFlutter(item['priority']),
                  'due_date': item['date_deadline'] ?? '',
                  'status': _getTaskStatusFromStage(item['stage_id']),
                  'assigned_by_name': 'Manager',
                  'create_date': item['create_date'],
                  'assigned_to_id': employeeId,
                });
              }
            }
            return validTasks;
          }
        }
      }

      return [];
    } catch (e) {
      print('Error fetching employee tasks: $e');
      return [];
    }
  }

  // Helper method to convert stage to status
  String _getTaskStatusFromStage(dynamic stageId) {
    if (stageId is List && stageId.isNotEmpty) {
      final stageName = stageId[1]?.toString().toLowerCase() ?? '';
      if (stageName.contains('done') || stageName.contains('completed')) {
        return 'completed';
      } else if (stageName.contains('progress') ||
          stageName.contains('doing')) {
        return 'in_progress';
      }
    }
    return 'pending';
  }

  // Helper method to map Odoo priority values to Flutter values
  String _mapOdooPriorityToFlutter(dynamic odooPriority) {
    if (odooPriority == null) return 'medium_priority';

    // Convert to string and check the value
    final priorityStr = odooPriority.toString();
    switch (priorityStr) {
      case '1':
        return 'high_priority';
      case '0':
        return 'medium_priority';
      case '-1':
        return 'low_priority';
      default:
        return 'medium_priority';
    }
  }

  // Helper method to format DateTime for Odoo (YYYY-MM-DD HH:MM:SS)
  String _formatDateForOdoo(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}:'
        '${date.second.toString().padLeft(2, '0')}';
  }

  // Debug method to search for a specific task by ID
  Future<Map<String, dynamic>?> searchTaskById(int taskId) async {
    try {
      print('Searching for task ID: $taskId');

      final result = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'project.task',
        'search_read',
        [
          ['id', '=', taskId]
        ],
        {
          'fields': [
            'id',
            'name',
            'description',
            'priority',
            'date_deadline',
            'user_ids',
            'project_id',
            'stage_id',
            'create_date'
          ]
        }
      ]);

      print('Search result for task $taskId: $result');
      return result.isNotEmpty ? result[0] : null;
    } catch (e) {
      print('Error searching for task $taskId: $e');
      return null;
    }
  }

  // Get tasks assigned by current manager
  Future<List<Map<String, dynamic>>> getManagerTasks() async {
    print('Fetching tasks assigned by current manager...');

    try {
      final employeeId = await getCurrentEmployeeId();
      print('Manager Employee ID: $employeeId');

      // Get manager's user ID
      final managerData = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'read',
        [employeeId],
        {
          'fields': ['user_id']
        }
      ]);

      if (managerData is List && managerData.isNotEmpty) {
        final userData = managerData.first;
        final userId = userData['user_id'];

        if (userId is List && userId.isNotEmpty) {
          final tasks = await _callRPC('object', 'execute_kw', [
            database,
            _userId,
            _password,
            'project.task',
            'search_read',
            [
              [
                ['create_uid', '=', userId[0]] // Tasks created by this manager
              ]
            ],
            {
              'fields': [
                'id',
                'name',
                'description',
                'priority',
                'date_deadline',
                'stage_id',
                'create_date',
                'user_ids',
                'create_uid'
              ],
              'order': 'create_date desc',
              'limit': 50,
              'context': {'lang': 'fr_FR'}
            }
          ]);

          print(
              'Found ${tasks is List ? tasks.length : 0} tasks assigned by manager');

          if (tasks is List) {
            final List<Map<String, dynamic>> validTasks = [];
            for (var item in tasks) {
              if (item is Map<String, dynamic>) {
                // Transform project.task data to match our expected format
                validTasks.add({
                  'id': item['id'],
                  'title': item['name'],
                  'description': item['description'] ?? '',
                  'priority': item['priority'] ?? 'medium_priority',
                  'due_date': item['date_deadline'] ?? '',
                  'status': _getTaskStatusFromStage(item['stage_id']),
                  'assigned_by_name': 'Manager',
                  'create_date': item['create_date'],
                  'assigned_to_id':
                      item['user_ids'] is List && item['user_ids'].isNotEmpty
                          ? item['user_ids'][0]
                          : null,
                });
              }
            }
            return validTasks;
          }
        }
      }

      return [];
    } catch (e) {
      print('Error fetching manager tasks: $e');
      return [];
    }
  }

  // Update task status
  Future<bool> updateTaskStatus(int taskId, String newStatus) async {
    print('Updating task $taskId status to $newStatus');

    try {
      final result = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'project.task',
        'write',
        [
          [taskId],
          {
            'status': newStatus,
            'update_date': _formatDateForOdoo(DateTime.now()),
          }
        ],
        {
          'context': {'lang': 'fr_FR'}
        }
      ]);

      print('Task status update result: $result');
      return result == true;
    } catch (e) {
      print('Error updating task status: $e');
      return false;
    }
  }

  // Mark notification as read using mail.notification
  Future<bool> markNotificationAsRead(int messageId) async {
    print('Marking notification $messageId as read...');

    if (_userId == null || _password == null) {
      print('Not authenticated');
      return false;
    }

    try {
      // Get employee's partner_id
      final employeeId = await getCurrentEmployeeId();
      final employeeData = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'read',
        [employeeId],
        {
          'fields': ['user_id']
        }
      ]);

      if (employeeData is List && employeeData.isNotEmpty) {
        final userData = employeeData.first;
        final userId = userData['user_id'];

        if (userId is List && userId.isNotEmpty) {
          // Get partner_id from user
          final userInfo = await _callRPC('object', 'execute_kw', [
            database,
            _userId,
            _password,
            'res.users',
            'read',
            [userId[0]],
            {
              'fields': ['partner_id']
            }
          ]);

          if (userInfo is List && userInfo.isNotEmpty) {
            final userPartner = userInfo.first['partner_id'];
            if (userPartner is List && userPartner.isNotEmpty) {
              final partnerId = userPartner[0] as int;

              // Find the mail.notification record for this message and partner
              final notificationIds = await _callRPC('object', 'execute_kw', [
                database,
                _userId,
                _password,
                'mail.notification',
                'search',
                [
                  [
                    ['mail_message_id', '=', messageId],
                    ['res_partner_id', '=', partnerId],
                  ]
                ]
              ]);

              if (notificationIds is List && notificationIds.isNotEmpty) {
                // Mark notification as read
                await _callRPC('object', 'execute_kw', [
                  database,
                  _userId,
                  _password,
                  'mail.notification',
                  'write',
                  [
                    notificationIds,
                    {'is_read': true}
                  ]
                ]);

                print('✅ Notification $messageId marked as read in Odoo');
                return true;
              } else {
                print(
                    '⚠️ No mail.notification found for message $messageId and partner $partnerId');
                // Still return true as the notification might have been read another way
                return true;
              }
            }
          }
        }
      }

      print('⚠️ Could not find partner_id to mark notification as read');
      return false;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  // Send notification to specific employee using mail.message
  // Uses the same module (mail.message) and logic as getSentNotifications()
  Future<bool> sendNotificationToEmployee({
    required int employeeId,
    required String title,
    required String message,
    String type = 'general',
    Map<String, dynamic>? data,
  }) async {
    print('Sending notification to employee $employeeId');

    try {
      // Get employee's user_id and work_contact_id
      final employeeData = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'read',
        [employeeId],
        {
          'fields': [
            'user_id',
            'work_contact_id',
          ]
        }
      ]);

      if (employeeData is List && employeeData.isNotEmpty) {
        final empData = employeeData.first;
        final userId = empData['user_id'];
        dynamic partnerId;

        // Try to get partner_id from user if user_id exists
        if (userId is List && userId.isNotEmpty) {
          try {
            final userData = await _callRPC('object', 'execute_kw', [
              database,
              _userId,
              _password,
              'res.users',
              'read',
              [userId[0]],
              {
                'fields': ['partner_id']
              }
            ]);

            if (userData is List && userData.isNotEmpty) {
              final userPartnerId = userData.first['partner_id'];
              if (userPartnerId is List && userPartnerId.isNotEmpty) {
                partnerId = userPartnerId[0];
                print(
                    'Sending notification to user ID: ${userId[0]} (partner: $partnerId) for employee $employeeId');
              }
            }
          } catch (e) {
            print('Error getting user partner_id: $e');
          }
        }

        // Fallback: Try work_contact_id
        if (partnerId == null) {
          partnerId = empData['work_contact_id'];
          if (partnerId is List && partnerId.isNotEmpty) {
            partnerId = partnerId[0];
            print(
                'Using work_contact_id (partner: $partnerId) for employee $employeeId');
          }
        }

        // Create mail.message notification - same structure as history query expects
        // The author_id will be automatically set to _userId (current logged-in user)
        List<int> partnerIds = [];
        if (partnerId != null && partnerId is int) {
          partnerIds.add(partnerId);
        }

        final messageData = <String, dynamic>{
          'subject': title,
          'body': message,
          'message_type': 'notification', // Must match history query filter
          'model': 'hr.employee',
          'res_id': employeeId,
          'date': _formatDateForOdoo(DateTime.now()),
          // Explicitly set author_id to ensure it's tracked correctly
          'author_id': _userId,
        };

        // Add partner_ids if we have valid partner IDs
        // This ensures the notification appears in employee's inbox and history shows recipient count
        if (partnerIds.isNotEmpty) {
          messageData['partner_ids'] = [
            [6, 0, partnerIds]
          ];
          print('✅ Sending to partner IDs: $partnerIds');
        } else {
          print(
              '⚠️ No partner_id found, creating notification anyway (will show as "Aucun destinataire" in history)');
        }

        // Create the mail.message record
        // author_id will be automatically set to _userId by Odoo
        final result = await _callRPC('object', 'execute_kw', [
          database,
          _userId,
          _password,
          'mail.message',
          'create',
          [messageData],
          {
            'context': {'lang': 'fr_FR'}
          }
        ]);

        print('✅ Notification sent result: $result');
        return result != null;
      }

      print('⚠️ Could not find employee data for employee $employeeId');
      return false;
    } catch (e) {
      print('❌ Error sending notification: $e');
      return false;
    }
  }

  // Send modification request notification to HR employees
  Future<bool> sendNotificationToHR({
    required int employeeId,
    required String fieldName,
    required String fieldLabel,
    required String currentValue,
    required String newValue,
    String? base64Image,
  }) async {
    final syncService = SyncService();

    // Check if offline - queue operation if so
    if (!syncService.isConnected) {
      print('📴 Offline: Queueing HR notification for sync');
      await syncService.queueOperation(
        operationType: SyncService.opHRNotification,
        operationData: {
          'employeeId': employeeId,
          'fieldName': fieldName,
          'fieldLabel': fieldLabel,
          'currentValue': currentValue,
          'newValue': newValue,
          'base64Image': base64Image,
        },
      );
      return true; // Return success immediately for offline mode
    }

    print('Sending modification request notification to HR');

    try {
      final currentEmployeeId = await getCurrentEmployeeId();

      // Find HR employees by searching for job titles containing "HR", "RH", or "Ressources Humaines"
      final hrEmployees = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'search_read',
        [
          [
            ['job_id', '!=', false],
            ['active', '=', true],
          ]
        ],
        {
          'fields': ['id', 'name', 'user_id', 'job_id'],
          'limit': 100,
        }
      ]);

      if (hrEmployees is! List || hrEmployees.isEmpty) {
        print('⚠️ No HR employees found');
        return false;
      }

      // Filter HR employees by job title
      final List<int> hrUserIds = [];
      for (var emp in hrEmployees) {
        if (emp is Map<String, dynamic>) {
          final jobId = emp['job_id'];
          String jobName = '';

          if (jobId is List && jobId.length > 1) {
            jobName = jobId[1].toString().toLowerCase();
          }

          // Check if job title contains HR-related keywords
          if (jobName.contains('rh') ||
              jobName.contains('ressources humaines') ||
              jobName.contains('hr') ||
              jobName.contains('human resources')) {
            final userId = emp['user_id'];
            if (userId is List && userId.isNotEmpty) {
              hrUserIds.add(userId[0]);
              print(
                  '✅ Found HR employee: ${emp['name']} (user_id: ${userId[0]})');
            }
          }
        }
      }

      if (hrUserIds.isEmpty) {
        print('⚠️ No HR employees with valid user accounts found');
        return false;
      }

      // Build notification message
      String notificationBody = '';
      if (base64Image != null) {
        notificationBody = '''
        <p><strong>Demande de modification de photo</strong></p>
        <p>L'employé ID $currentEmployeeId souhaite modifier sa photo de profil.</p>
        <p>Une nouvelle photo a été fournie.</p>
        ''';
      } else {
        notificationBody = '''
        <p><strong>Demande de modification d'information</strong></p>
        <p><strong>Employé ID:</strong> $currentEmployeeId</p>
        <p><strong>Champ:</strong> $fieldLabel ($fieldName)</p>
        <p><strong>Valeur actuelle:</strong> $currentValue</p>
        <p><strong>Nouvelle valeur demandée:</strong> $newValue</p>
        <p>Veuillez valider cette modification dans Odoo.</p>
        ''';
      }

      // Create mail message notification for all HR employees
      final messageData = {
        'subject': base64Image != null
            ? 'Demande de modification de photo - Employé ID $currentEmployeeId'
            : 'Demande de modification - $fieldLabel - Employé ID $currentEmployeeId',
        'body': notificationBody,
        'message_type': 'notification',
        'partner_ids': [
          [6, 0, hrUserIds]
        ], // Send to all HR users
        'model': 'hr.employee',
        'res_id': currentEmployeeId,
        'date': _formatDateForOdoo(DateTime.now()),
      };

      final result = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'mail.message',
        'create',
        [messageData],
        {
          'context': {'lang': 'fr_FR'}
        }
      ]);

      print('✅ HR notification sent result: $result');
      return result != null;
    } catch (e) {
      print('❌ Error sending HR notification: $e');
      return false;
    }
  }

  // Create task in Odoo using project.task (existing model)
  Future<int> createTask({
    required int employeeId,
    required String title,
    required String description,
    required String priority,
    required DateTime dueDate,
    required String assignedByName,
  }) async {
    final syncService = SyncService();

    // Check if offline - queue operation if so
    if (!syncService.isConnected) {
      print('📴 Offline: Queueing task creation for sync');
      final queueId = await syncService.queueOperation(
        operationType: SyncService.opTaskCreate,
        operationData: {
          'employeeId': employeeId,
          'title': title,
          'description': description,
          'priority': priority,
          'dueDate': dueDate.toIso8601String(),
          'assignedByName': assignedByName,
        },
      );
      return queueId; // Return queue ID as temporary ID for offline mode
    }

    print('Creating task in Odoo for employee $employeeId');

    try {
      // Step 1: Map Flutter priority values to Odoo priority values
      String odooPriority;
      switch (priority) {
        case 'high_priority':
          odooPriority = '1'; // High priority in Odoo
          break;
        case 'medium_priority':
          odooPriority = '0'; // Normal priority in Odoo
          break;
        case 'low_priority':
          odooPriority = '-1'; // Low priority in Odoo
          break;
        default:
          odooPriority = '0'; // Default to normal priority
      }

      // Step 2: Format date for Odoo (YYYY-MM-DD HH:MM:SS)
      final formattedDueDate = '${dueDate.year.toString().padLeft(4, '0')}-'
          '${dueDate.month.toString().padLeft(2, '0')}-'
          '${dueDate.day.toString().padLeft(2, '0')} '
          '${dueDate.hour.toString().padLeft(2, '0')}:'
          '${dueDate.minute.toString().padLeft(2, '0')}:'
          '${dueDate.second.toString().padLeft(2, '0')}';

      // Step 3: Get the user ID associated with the employee
      final employeeUser = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'read',
        [employeeId],
        {
          'fields': ['user_id']
        },
      ]);

      int? userId;
      if (employeeUser.isNotEmpty && employeeUser[0]['user_id'] != false) {
        userId =
            employeeUser[0]['user_id'][0]; // Get the user ID from the tuple
      }

      // Step 4: Build task data BEFORE the RPC call
      final Map<String, dynamic> taskData = {
        'name': title,
        'description': description,
        'priority': odooPriority,
        'date_deadline': formattedDueDate,
        'project_id': false, // No project assignment
        'partner_id': false, // No customer
      };

      // Add user assignment if available
      if (userId != null) {
        taskData['user_ids'] = [
          [
            6,
            0,
            [userId]
          ]
        ]; // Proper many2many format
      }

      print('Task data being sent to Odoo: $taskData');

      // Step 5: Create the task
      final result = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'project.task',
        'create',
        [taskData], // Pass as list with one map element
        {}
      ]);

      print('✅ Task created successfully with ID: $result');
      return result;
    } catch (e) {
      print('❌ ERROR creating task: $e');
      rethrow;
    }
  }

  // Fetch tasks assigned to a specific employee by ID
  Future<List<Map<String, dynamic>>> getTasksForEmployee({
    required int employeeId,
  }) async {
    try {
      print('Fetching tasks for employee $employeeId');

      // First get the user ID associated with the employee and their manager
      final employeeUser = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'read',
        [employeeId],
        {
          'fields': ['user_id', 'parent_id']
        },
      ]);

      print('Employee user data: $employeeUser');

      if (employeeUser.isEmpty || employeeUser[0]['user_id'] == false) {
        print('Employee $employeeId has no associated user account');
        return [];
      }

      final userId = employeeUser[0]['user_id'][0];
      print(
          '👤 Found user ID: $userId (type: ${userId.runtimeType}) for employee $employeeId');
      print('🔍 This is the user ID we will filter tasks by');

      // Additional safety check: verify this employee's user_id matches the logged-in user
      // If they don't match and we're in employee section, there might be an issue
      if (_userId != null) {
        final currentLoggedInUserId = _userId;
        if (userId != currentLoggedInUserId) {
          print(
              '⚠️ WARNING: Requested employee user_id ($userId) differs from logged-in user_id ($currentLoggedInUserId)');
          print(
              '⚠️ This is OK if manager is viewing employee tasks, but in employee section this should match!');
        } else {
          print(
              '✅ Employee user_id matches logged-in user_id - this is correct for employee section');
        }
      }

      // Get the manager's user ID (if employee has a parent/manager)
      int? managerUserId;
      if (employeeUser[0]['parent_id'] != null &&
          employeeUser[0]['parent_id'] != false &&
          employeeUser[0]['parent_id'] is List &&
          (employeeUser[0]['parent_id'] as List).isNotEmpty) {
        final managerId = (employeeUser[0]['parent_id'] as List)[0];
        print('Employee has manager with ID: $managerId');

        // Get manager's user ID
        try {
          final managerData = await _callRPC('object', 'execute_kw', [
            database,
            _userId,
            _password,
            'hr.employee',
            'read',
            [managerId],
            {
              'fields': ['user_id']
            },
          ]);

          if (managerData is List &&
              managerData.isNotEmpty &&
              managerData[0]['user_id'] != false &&
              managerData[0]['user_id'] is List &&
              (managerData[0]['user_id'] as List).isNotEmpty) {
            managerUserId = (managerData[0]['user_id'] as List)[0];
            print('Found manager user ID: $managerUserId');
          }
        } catch (e) {
          print('Error getting manager user ID: $e');
        }
      }

      // Build search domain: tasks assigned to this user
      // Match Odoo "Ouvert" (Open) filter behavior
      // Odoo "Ouvert" typically means: active tasks that are not in "Done" or "Cancelled" stages
      List<dynamic> searchDomain = [
        [
          'user_ids',
          'in',
          [userId]
        ],
        ['active', '=', true], // Only active tasks (like Odoo default)
      ];

      // Optional: Filter by manager if you want only manager-created tasks
      // Uncomment if you want ONLY tasks created by manager:
      // if (managerUserId != null) {
      //   searchDomain.add(['create_uid', '=', managerUserId]);
      //   print('Filtering: only tasks created by manager user $managerUserId');
      // }

      print('🔍 Fetching tasks with domain: $searchDomain');
      print(
          '📋 This should match Odoo "Ouvert" (Open) filter: active tasks assigned to user $userId');

      // Search and read tasks assigned to this user and created by manager
      final tasks = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'project.task',
        'search_read',
        [searchDomain],
        {
          'fields': [
            'id',
            'name',
            'description',
            'priority',
            'date_deadline',
            'create_date',
            'write_date',
            'stage_id',
            'user_ids',
            'project_id',
            'partner_id',
            'personal_stage_id',
            'personal_stage_type_id',
            'activity_user_id',
            'create_uid',
            'active' // Add active field to check task status
          ],
          // Match Odoo default ordering: priority desc, sequence, date_deadline asc, id desc
          // But we prioritize new tasks by create_date desc
          'order':
              'create_date desc, priority desc, date_deadline asc, id desc',
          'limit': 50,
          'context': {
            'lang': 'fr_FR',
            // active_test: false would include inactive tasks, but we're filtering active=true in domain
            // This matches Odoo "Ouvert" filter behavior
          }
        }
      ]);

      final tasksCount = tasks is List ? tasks.length : 0;
      print('📊 Found $tasksCount tasks for employee $employeeId');

      // Debug: Print task details to understand what we're getting
      if (tasks is List && tasks.isNotEmpty) {
        print('📋 All tasks details (showing first 10):');
        for (var i = 0; i < (tasks.length > 10 ? 10 : tasks.length); i++) {
          final task = tasks[i];
          if (task is Map) {
            final stageInfo = task['stage_id'];
            final stageName = stageInfo is List && stageInfo.length > 1
                ? stageInfo[1]
                : stageInfo;
            // Extract user IDs from the many2many field
            List<dynamic> assignedUserIds = [];
            if (task['user_ids'] is List) {
              assignedUserIds = task['user_ids'] as List;
            }

            print(
                '  Task ${i + 1}: "${task['name']}" - Assigned to user_ids: $assignedUserIds (current user: $userId) - Stage: $stageName');
          }
        }
        print('📊 Total tasks retrieved from Odoo: ${tasks.length}');
      }

      if (tasks is List) {
        final List<Map<String, dynamic>> validTasks = [];
        for (var item in tasks) {
          if (item is Map<String, dynamic>) {
            // CRITICAL: Verify that this task is actually assigned to the current user
            final taskUserIds = item['user_ids'];
            bool isAssignedToCurrentUser = false;

            // Convert userId to int for comparison
            int targetUserId;
            if (userId is int) {
              targetUserId = userId;
            } else if (userId is String) {
              targetUserId = int.tryParse(userId) ?? -1;
            } else {
              targetUserId = int.tryParse(userId.toString()) ?? -1;
            }

            if (targetUserId == -1) {
              print(
                  '  ⚠️ ERROR: Cannot parse userId: $userId (type: ${userId.runtimeType})');
              continue;
            }

            if (taskUserIds != null && taskUserIds != false) {
              // user_ids is a many2many field, it returns a list of user IDs
              if (taskUserIds is List) {
                for (var uid in taskUserIds) {
                  // Convert uid to int for comparison
                  int uidInt;
                  if (uid is int) {
                    uidInt = uid;
                  } else if (uid is String) {
                    uidInt = int.tryParse(uid) ?? -1;
                  } else if (uid is List && uid.isNotEmpty) {
                    // Sometimes Odoo returns [id, name] format
                    uidInt = uid[0] is int
                        ? uid[0]
                        : int.tryParse(uid[0].toString()) ?? -1;
                  } else {
                    uidInt = int.tryParse(uid.toString()) ?? -1;
                  }

                  if (uidInt == targetUserId) {
                    isAssignedToCurrentUser = true;
                    break;
                  }
                }
              }
            }

            if (!isAssignedToCurrentUser) {
              print(
                  '  ⏭️ Skipping task "${item['name']}" - NOT assigned to user $targetUserId (task user_ids: $taskUserIds, type: ${taskUserIds.runtimeType})');
              continue; // Skip tasks not assigned to current user
            }

            print(
                '  ✅ Task "${item['name']}" is assigned to user $targetUserId');

            // Include all tasks (including "Done") - only filter out "Cancelled" tasks
            // Check both personal_stage_type_id (used for updates) and stage_id (default stage)
            final personalStageTypeId = item['personal_stage_type_id'];
            final stageId = item['stage_id'];
            bool isCancelled = false;

            // Helper function to extract stage name
            String getStageName(dynamic stage) {
              if (stage == null || stage == false) return '';
              if (stage is List && stage.length > 1) {
                return stage[1].toString().toLowerCase();
              }
              return stage.toString().toLowerCase();
            }

            // Check personal_stage_type_id first (used for task updates)
            final personalStageName = getStageName(personalStageTypeId);
            final stageName = getStageName(stageId);

            // Use personal_stage_type_id if available, otherwise use stage_id
            final effectiveStageName =
                personalStageName.isNotEmpty ? personalStageName : stageName;

            // Only filter out "Cancelled" tasks, but keep "Done" tasks visible
            if (effectiveStageName.isNotEmpty) {
              if (effectiveStageName.contains('cancelled') ||
                  effectiveStageName.contains('annulé')) {
                isCancelled = true;
                print(
                    '  ⏭️ Skipping cancelled task: ${item['name']} (Personal Stage: $personalStageName, Stage: $stageName, Effective: $effectiveStageName)');
              }
            }

            // Include all tasks assigned to current user (including "Done"), except "Cancelled"
            if (!isCancelled) {
              // Transform project.task data to match our expected format
              validTasks.add({
                'id': item['id'],
                'name': item['name'],
                'description': item['description'] ?? '',
                'priority': item['priority'],
                'date_deadline': item['date_deadline'],
                'create_date': item['create_date'],
                'write_date': item['write_date'],
                'stage_id': item['stage_id'],
                'user_ids': item['user_ids'],
                'project_id': item['project_id'],
                'partner_id': item['partner_id'],
                'personal_stage_id': item['personal_stage_id'],
                'personal_stage_type_id': item['personal_stage_type_id'] ??
                    item[
                        'stage_id'], // Fallback to stage_id if personal_stage_type_id is null/false
                'activity_user_id': item['activity_user_id'],
                'create_uid': item['create_uid'],
              });
            } // End of if (!isCompletedOrCancelled)
          }
        }
        // Sort by create_date descending (newest first) - double check even though Odoo should do it
        validTasks.sort((a, b) {
          final dateA = a['create_date'];
          final dateB = b['create_date'];
          if (dateA == null || dateB == null) return 0;
          try {
            final dateTimeA = DateTime.parse(dateA.toString());
            final dateTimeB = DateTime.parse(dateB.toString());
            return dateTimeB.compareTo(dateTimeA); // Descending: newest first
          } catch (e) {
            return 0;
          }
        });
        print(
            '✅ Processed ${validTasks.length} tasks assigned to user $userId (filtered: only tasks where user is in user_ids, excluding cancelled, but including done tasks)');
        print(
            '📊 Summary: ${tasks.length} total from Odoo → ${validTasks.length} valid tasks assigned to current user');
        return validTasks;
      } else {
        print('Unexpected response format: $tasks');
        return [];
      }
    } catch (e) {
      print('❌ ERROR fetching tasks for employee $employeeId: $e');
      return [];
    }
  }

  // Update task stage/status
  Future<bool> updateTaskStage({
    required int taskId,
    required String newStage,
  }) async {
    final syncService = SyncService();

    // Check if offline - queue operation if so
    if (!syncService.isConnected) {
      print('📴 Offline: Queueing task update for sync');
      await syncService.queueOperation(
        operationType: SyncService.opTaskUpdate,
        operationData: {
          'taskId': taskId,
          'newStage': newStage,
        },
      );
      return true; // Return success immediately for offline mode
    }

    try {
      print('Updating task $taskId status to $newStage');

      // First, get available stages
      final stages = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'project.task.type',
        'search_read',
        [[]],
        {
          'fields': ['name', 'id']
        }
      ]);

      print('Available stages in Odoo: $stages');

      // Process the raw Odoo stages data
      final List<Map<String, dynamic>> validStages = [];
      if (stages is List) {
        for (var item in stages) {
          if (item is Map<String, dynamic>) {
            validStages.add({
              'id': item['id'],
              'name': item['name'],
            });
          }
        }
      }

      print('Processed ${validStages.length} valid stages for update');

      // Find the stage ID by name - try exact match first, then contains
      int? stageId;
      final newStageLower = newStage.toLowerCase().trim();

      // First try exact match
      for (var stage in validStages) {
        final stageName = stage['name'].toString().toLowerCase().trim();
        if (stageName == newStageLower) {
          stageId = stage['id'] is int
              ? stage['id'] as int
              : int.tryParse(stage['id'].toString());
          print(
              'Found exact matching stage: ${stage['name']} with ID: $stageId');
          break;
        }
      }

      // If no exact match, try contains
      if (stageId == null) {
        for (var stage in validStages) {
          final stageName = stage['name'].toString().toLowerCase().trim();
          print('Checking stage: ${stage['name']} (ID: ${stage['id']})');
          if (stageName.contains(newStageLower) ||
              newStageLower.contains(stageName)) {
            stageId = stage['id'] is int
                ? stage['id'] as int
                : int.tryParse(stage['id'].toString());
            print(
                'Found matching stage (contains): ${stage['name']} with ID: $stageId');
            break;
          }
        }
      }

      if (stageId == null) {
        print('❌ Stage "$newStage" not found in available stages');
        print(
            'Available stages: ${validStages.map((s) => s['name']).toList()}');
        return false;
      }

      print('Mapping "$newStage" to personal stage ID: $stageId');

      // Step 4: Update the task with the correct field name
      final result = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'project.task',
        'write',
        [
          [taskId], // Task ID must be in a list
          {
            'personal_stage_type_id': stageId, // ✅ Use this field
          }
        ],
      ]);

      print('✅ Task $taskId status updated successfully: $result');
      return result == true;
    } catch (e) {
      print('❌ ERROR updating task $taskId status: $e');
      return false;
    }
  }

  // Get available task stages
  Future<List<Map<String, dynamic>>> getAvailableTaskStages() async {
    try {
      print('Fetching available task stages...');

      final stages = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'project.task.type',
        'search_read',
        [[]],
        {
          'fields': ['name', 'id']
        }
      ]);

      print('Found ${stages.length} available stages: $stages');

      if (stages is List) {
        final List<Map<String, dynamic>> validStages = [];
        for (var item in stages) {
          if (item is Map<String, dynamic>) {
            // Transform stage data to match our expected format
            validStages.add({
              'id': item['id'],
              'name': item['name'],
            });
          }
        }
        print('Processed ${validStages.length} valid stages');
        return validStages;
      } else {
        print('Unexpected response format: $stages');
        return [];
      }
    } catch (e) {
      print('❌ ERROR fetching task stages: $e');
      return [];
    }
  }

  // Send task assignment notification
  Future<bool> sendTaskAssignmentNotification({
    required int employeeId,
    required String taskTitle,
    required String taskDescription,
    required String assignedByName,
  }) async {
    // For now, just return true since manager.notification model doesn't exist
    // TODO: Implement proper notification system when manager.notification model is created
    print('Task assignment notification would be sent to employee $employeeId');
    return true;
  }

  // Create task and send notification
  Future<bool> createTaskAndNotify({
    required int employeeId,
    required String title,
    required String description,
    required String priority,
    required DateTime dueDate,
    required String assignedByName,
  }) async {
    try {
      // Create the task in Odoo
      final taskId = await createTask(
        employeeId: employeeId,
        title: title,
        description: description,
        priority: priority,
        dueDate: dueDate,
        assignedByName: assignedByName,
      );

      // Send notification to employee
      final notificationSuccess = await sendTaskAssignmentNotification(
        employeeId: employeeId,
        taskTitle: title,
        taskDescription: description,
        assignedByName: assignedByName,
      );

      print(
          'Task created with ID: $taskId, Notification sent: $notificationSuccess');
      return taskId > 0;
    } catch (e) {
      print('Error creating task and notification: $e');
      return false;
    }
  }

  // Send leave approval notification
  Future<bool> sendLeaveApprovalNotification({
    required int employeeId,
    required String leaveType,
    required String status,
    required String managerName,
  }) async {
    return await sendNotificationToEmployee(
      employeeId: employeeId,
      title: 'Statut de congé mis à jour',
      message: 'Votre demande de $leaveType a été $status par $managerName',
      type: 'leave_approval',
      data: {
        'leave_type': leaveType,
        'status': status,
        'manager_name': managerName,
      },
    );
  }

  // Check if current user is a manager (has subordinates)
  Future<bool> isManager() async {
    try {
      final employeeId = await getCurrentEmployeeId();
      print('Checking manager status for employee ID: $employeeId');

      // Search for employees where parent_id is the current employee
      final subordinatesCount = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'search_count',
        [
          [
            ['parent_id', '=', employeeId]
          ]
        ],
        {}
      ]);

      print('Manager check - subordinates count: $subordinatesCount');
      return subordinatesCount > 0;
    } catch (e) {
      print('Error checking if manager: $e');
      print('User may not have an employee record - defaulting to non-manager');
      return false;
    }
  }

  // Get employee documents from documents.document model
  Future<List<Map<String, dynamic>>> getEmployeeDocuments() async {
    print('📄 Fetching employee documents from documents.document...');

    try {
      final employeeId = await getCurrentEmployeeId();
      print('📄 Employee ID: $employeeId');
      final currentUserId = _userId;

      // Try to get the partner of the current user (used by Documents app)
      int? partnerId;
      try {
        final userRes = await _callRPC('object', 'execute_kw', [
          database,
          _userId,
          _password,
          'res.users',
          'read',
          [currentUserId],
          {
            'fields': ['partner_id']
          }
        ]);
        if (userRes is List && userRes.isNotEmpty) {
          final u = Map<String, dynamic>.from(userRes.first);
          if (u['partner_id'] is List && u['partner_id'].isNotEmpty) {
            partnerId = u['partner_id'][0] as int;
          }
        }
      } catch (_) {
        // ignore partner resolution errors; we'll still query by other criteria
      }

      // Build domain correctly using operator tokens. Base condition: link to employee
      final List<dynamic> baseAnd = [
        '&',
        ['res_model', '=', 'hr.employee'],
        ['res_id', '=', employeeId],
      ];

      final ownerCond =
          currentUserId != null ? ['owner_id', '=', currentUserId] : null;
      final partnerCond =
          partnerId != null ? ['partner_id', '=', partnerId] : null;

      final List<dynamic> domain = <dynamic>[];
      if (ownerCond != null && partnerCond != null) {
        domain
          ..add('|')
          ..add('|')
          ..addAll(baseAnd)
          ..add(ownerCond)
          ..add(partnerCond);
      } else if (ownerCond != null) {
        domain
          ..add('|')
          ..addAll(baseAnd)
          ..add(ownerCond);
      } else if (partnerCond != null) {
        domain
          ..add('|')
          ..addAll(baseAnd)
          ..add(partnerCond);
      } else {
        domain.addAll(baseAnd);
      }

      final documents = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'documents.document',
        'search_read',
        [domain],
        {
          'fields': [
            'id',
            'name',
            'display_name',
            'attachment_name',
            'attachment_id',
            'attachment_type',
            'mimetype',
            'create_date',
            'write_date',
            'description',
            'checksum',
            'res_model',
            'res_id',
            'owner_id',
            'partner_id',
            'company_id',
            'folder_id',
          ],
          'order': 'id desc',
          'limit': 1000,
          'context': {'lang': 'fr_FR'}
        }
      ]);

      print('📄 Found ${documents is List ? documents.length : 0} documents');

      if (documents is List) {
        final validDocuments = <Map<String, dynamic>>[];
        for (var doc in documents) {
          if (doc is Map<String, dynamic>) {
            validDocuments.add(Map<String, dynamic>.from(doc));
          }
        }
        print('📄 Valid documents: ${validDocuments.length}');
        return validDocuments;
      }

      return [];
    } catch (e) {
      print('📄 ❌ Error fetching employee documents: $e');
      return [];
    }
  }

  // Download document content
  Future<String?> getDocumentContent(int attachmentId) async {
    try {
      final result = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'ir.attachment',
        'read',
        [attachmentId],
        {
          'fields': ['datas'],
        }
      ]);

      if (result is List && result.isNotEmpty) {
        final data = Map<String, dynamic>.from(result.first);
        return data['datas']?.toString();
      }

      return null;
    } catch (e) {
      print('Error downloading document: $e');
      return null;
    }
  }

  // Find first attachment for a given documents.document record
  Future<int?> getFirstAttachmentIdForDocument(int documentId) async {
    try {
      final attachments = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'ir.attachment',
        'search_read',
        [
          [
            ['res_model', '=', 'documents.document'],
            ['res_id', '=', documentId],
          ]
        ],
        {
          'fields': ['id'],
          'order': 'create_date desc',
          'limit': 1,
        }
      ]);

      if (attachments is List && attachments.isNotEmpty) {
        final first = Map<String, dynamic>.from(attachments.first);
        final id = first['id'];
        if (id is int) return id;
      }
      return null;
    } catch (e) {
      print('Error searching attachment for document $documentId: $e');
      return null;
    }
  }

  // Create a document and upload an attachment, linking both
  Future<bool> createDocumentWithAttachment({
    required String name,
    required String mimeType,
    required String base64Data,
    int? folderId,
  }) async {
    try {
      // Create document record
      final Map<String, dynamic> vals = {
        'name': name,
      };
      if (folderId != null) vals['folder_id'] = folderId;

      final docId = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'documents.document',
        'create',
        [vals],
      ]);

      if (docId is! int) {
        throw Exception('Document creation failed');
      }

      // Create attachment linked to the new document
      final attachmentId = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'ir.attachment',
        'create',
        [
          {
            'name': name,
            'datas': base64Data,
            'mimetype': mimeType,
            'res_model': 'documents.document',
            'res_id': docId,
          }
        ],
      ]);

      if (attachmentId is! int) {
        throw Exception('Attachment creation failed');
      }

      // Link attachment to document (if field is present)
      try {
        await _callRPC('object', 'execute_kw', [
          database,
          _userId,
          _password,
          'documents.document',
          'write',
          [
            [docId],
            {
              'attachment_id': attachmentId,
              'attachment_name': name,
            }
          ],
        ]);
      } catch (_) {
        // if write fails (field missing), ignore
      }

      return true;
    } catch (e) {
      print('Error creating document with attachment: $e');
      return false;
    }
  }

  // Get leave balance from hr.leave.employee.type.report model
  Future<Map<String, dynamic>> getLeaveBalance() async {
    print('📊 Loading leave balance from hr.leave.employee.type.report...');
    final employeeId = await getCurrentEmployeeId();
    print('📊 Employee ID: $employeeId');

    try {
      // Fetch balance data from hr.leave.employee.type.report
      print('📊 Fetching from hr.leave.employee.type.report...');
      final reportData = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.leave.employee.type.report',
        'search_read',
        [
          [
            ['employee_id', '=', employeeId]
          ]
        ],
        {
          'fields': [
            'leave_type',
            'number_of_days',
            'number_of_hours',
            'state',
            'holiday_status'
          ],
          'order': 'date_from DESC, employee_id',
          'limit': 1000,
          'context': {'lang': 'fr_FR'}
        }
      ]);

      print('📊 Report response type: ${reportData.runtimeType}');
      print('📊 Report count: ${reportData is List ? reportData.length : 0}');

      Map<String, double> balance = {};

      // Process report data
      if (reportData is List) {
        for (var record in reportData) {
          if (record is Map && record.containsKey('leave_type')) {
            var leaveType = record['leave_type'];
            String typeName = 'Inconnu';

            // Extract leave type name
            if (leaveType is List && leaveType.length >= 2) {
              typeName = leaveType[1].toString();
            } else if (leaveType is String) {
              typeName = leaveType;
            } else if (leaveType is Map && leaveType.containsKey('name')) {
              typeName = leaveType['name'].toString();
            }

            // Get number_of_days
            double days = 0.0;
            if (record.containsKey('number_of_days')) {
              var numDays = record['number_of_days'];
              if (numDays is num) {
                days = numDays.toDouble();
              } else if (numDays is String) {
                days = double.tryParse(numDays) ?? 0.0;
              }
            }

            // The report should already contain the balance (could be positive or negative)
            // If multiple records exist for the same type, sum them
            balance[typeName] = (balance[typeName] ?? 0.0) + days;

            print(
                '📊 Report record: $typeName = $days days. Current balance: ${balance[typeName]}');
          }
        }
      }

      // Always fetch all leave types and ensure they're in the balance map
      // This ensures all types are displayed even if they have 0 balance
      print('📊 Fetching all leave types to ensure complete display...');
      try {
        final leaveTypes = await _callRPC('object', 'execute_kw', [
          database,
          _userId,
          _password,
          'hr.leave.type',
          'search_read',
          [[]],
          {
            'fields': ['id', 'name', 'active'],
            'context': {'lang': 'fr_FR'}
          }
        ]);

        if (leaveTypes is List) {
          for (var type in leaveTypes) {
            if (type is Map && type.containsKey('name')) {
              String typeName = type['name'].toString();
              // Only add if not already in balance (to preserve actual values from report)
              // Or if it's active, always include it
              bool isActive = type['active'] != false;
              if (!balance.containsKey(typeName) && isActive) {
                balance[typeName] = 0.0;
                print(
                    '📊 Added $typeName = 0.0 (not in report, ensuring display)');
              }
            }
          }
        }
      } catch (e) {
        print('📊 ⚠️ Could not fetch leave types: $e');
      }

      print('📊 Final balance from report: $balance');
      print('📊 Total leave types in balance: ${balance.length}');
      return balance;
    } catch (e) {
      print('📊 ❌ Error in getLeaveBalance: $e');

      // Fallback to fetching from allocations if report doesn't exist
      print(
          '📊 ⚠️ Report not available, fetching balance directly from allocations...');
      return await _getLeaveBalanceFallback();
    }
  }

  // Fallback method - fetch balance directly from Odoo (no manual calculation)
  Future<Map<String, dynamic>> _getLeaveBalanceFallback() async {
    print(
        '📊 Fetching leave balance directly from hr.leave.allocation (calculated by Odoo)...');
    final employeeId = await getCurrentEmployeeId();

    try {
      // Get leave allocations with remaining balance calculated by Odoo
      final allocations = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.leave.allocation',
        'search_read',
        [
          [
            ['employee_id', '=', employeeId],
            ['state', '=', 'validate']
          ]
        ],
        {
          'fields': [
            'holiday_status_id',
            'remaining_days', // Directly get remaining days calculated by Odoo
            'virtual_remaining_leaves', // Alternative field
            'number_of_days', // Total allocated days (fallback)
            'leaves_taken' // Days taken (fallback)
          ],
          'limit': 1000,
          'context': {'lang': 'fr_FR'}
        }
      ]);

      Map<String, double> balance = {};

      if (allocations is List) {
        for (var allocation in allocations) {
          if (allocation is Map &&
              allocation.containsKey('holiday_status_id')) {
            var statusId = allocation['holiday_status_id'];
            String typeName;

            if (statusId is List && statusId.length >= 2) {
              typeName = statusId[1].toString();
            } else if (statusId is String) {
              typeName = statusId;
            } else {
              continue;
            }

            // Try to get remaining_days first (calculated by Odoo)
            double remainingDays = 0.0;
            if (allocation.containsKey('remaining_days')) {
              var remDays = allocation['remaining_days'];
              if (remDays is num) {
                remainingDays = remDays.toDouble();
              } else if (remDays is String) {
                remainingDays = double.tryParse(remDays) ?? 0.0;
              }
            }
            // If remaining_days not available, try virtual_remaining_leaves
            else if (allocation.containsKey('virtual_remaining_leaves')) {
              var virtRem = allocation['virtual_remaining_leaves'];
              if (virtRem is num) {
                remainingDays = virtRem.toDouble();
              } else if (virtRem is String) {
                remainingDays = double.tryParse(virtRem) ?? 0.0;
              }
            }
            // If neither available, use number_of_days - leaves_taken (calculated by Odoo)
            else if (allocation.containsKey('number_of_days')) {
              double allocated = 0.0;
              var allocDays = allocation['number_of_days'];
              if (allocDays is num) {
                allocated = allocDays.toDouble();
              } else if (allocDays is String) {
                allocated = double.tryParse(allocDays) ?? 0.0;
              }

              double taken = 0.0;
              if (allocation.containsKey('leaves_taken')) {
                var takenDays = allocation['leaves_taken'];
                if (takenDays is num) {
                  taken = takenDays.toDouble();
                } else if (takenDays is String) {
                  taken = double.tryParse(takenDays) ?? 0.0;
                }
              }

              remainingDays = allocated - taken;
            }

            balance[typeName] = remainingDays;
            print(
                '📊 Allocation: $typeName = $remainingDays days (fetched from Odoo, not calculated)');
          }
        }
      }

      // Also get all active leave types to ensure they're all displayed
      try {
        final leaveTypes = await _callRPC('object', 'execute_kw', [
          database,
          _userId,
          _password,
          'hr.leave.type',
          'search_read',
          [[]],
          {
            'fields': ['id', 'name', 'active'],
            'context': {'lang': 'fr_FR'}
          }
        ]);

        if (leaveTypes is List) {
          for (var type in leaveTypes) {
            if (type is Map && type.containsKey('name')) {
              bool isActive = type['active'] != false;
              if (isActive) {
                String typeName = type['name'].toString();
                // Only add if not already in balance (preserve values from allocations)
                if (!balance.containsKey(typeName)) {
                  balance[typeName] = 0.0;
                }
              }
            }
          }
        }
      } catch (e) {
        print('📊 ⚠️ Could not fetch leave types: $e');
      }

      print(
          '📊 Final balance (fetched from Odoo, not manually calculated): $balance');
      return balance;
    } catch (e) {
      print('📊 ❌ Error in fallback: $e');
      return {};
    }
  }

  // Get leave requests with all details
  Future<List<Map<String, dynamic>>> getLeaveRequests() async {
    print('📋 === FETCHING LEAVE REQUESTS ===');
    final employeeId = await getCurrentEmployeeId();
    print('📋 Employee ID: $employeeId');
    print('📋 User ID: $_userId');

    try {
      print('📋 Making RPC call to hr.leave.search_read...');
      print('📋 Filter: employee_id = $employeeId');

      // First, try to search without any filters to see if model exists
      print('📋 Testing if hr.leave model exists...');
      try {
        final testSearch = await _callRPC('object', 'execute_kw', [
          database,
          _userId,
          _password,
          'hr.leave',
          'search',
          [[]], // Empty domain to search all
          {'limit': 1}
        ]);
        print(
            '📋 Test search result: $testSearch (count: ${testSearch is List ? testSearch.length : 'not a list'})');
      } catch (e) {
        print('📋 ⚠️ Test search failed: $e');
      }

      final requests = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.leave',
        'search_read',
        [
          [
            ['employee_id', '=', employeeId]
          ]
        ],
        {
          'fields': [
            'id',
            'date_from',
            'date_to',
            'holiday_status_id',
            'state',
            'request_date_from',
            'request_date_to',
            'name',
            'employee_id',
            'number_of_days',
            'request_unit_half'
          ],
          'order': 'request_date_from desc',
          'limit': 1000,
          'context': {'lang': 'fr_FR'}
        }
      ]);

      // Alternative: try with employee_id as a list/tuple
      if (requests is List && requests.isEmpty) {
        print(
            '📋 No results with direct employee_id match, trying alternative format...');
        try {
          final altRequests = await _callRPC('object', 'execute_kw', [
            database,
            _userId,
            _password,
            'hr.leave',
            'search_read',
            [
              [
                [
                  'employee_id',
                  '=',
                  [employeeId, '']
                ]
              ]
            ],
            {
              'fields': [
                'id',
                'date_from',
                'date_to',
                'holiday_status_id',
                'state',
                'request_date_from',
                'request_date_to',
                'name',
                'employee_id',
                'number_of_days',
                'request_unit_half'
              ],
              'order': 'request_date_from desc',
              'limit': 1000,
              'context': {'lang': 'fr_FR'}
            }
          ]);
          print(
              '📋 Alternative format result: ${altRequests is List ? altRequests.length : 'not a list'} items');
          if (altRequests is List && altRequests.isNotEmpty) {
            print('📋 Using alternative format results');
            final List<Map<String, dynamic>> validRequests = [];
            for (var i = 0; i < altRequests.length; i++) {
              var item = altRequests[i];
              if (item is Map) {
                validRequests.add(Map<String, dynamic>.from(item));
              }
            }
            return validRequests;
          }
        } catch (e) {
          print('📋 Alternative format also failed: $e');
        }
      }

      print('📋 Raw response type: ${requests.runtimeType}');
      print('📋 Raw response: $requests');

      if (requests is List) {
        print('📋 Response is a List with ${requests.length} items');
        final List<Map<String, dynamic>> validRequests = [];
        for (var i = 0; i < requests.length; i++) {
          var item = requests[i];
          print('📋 Item $i type: ${item.runtimeType}');
          if (item is Map) {
            print('📋 Item $i is a Map: ${item.keys.toList()}');
            validRequests.add(Map<String, dynamic>.from(item));
          } else {
            print('📋 ⚠️ Item $i is not a Map, skipping: $item');
          }
        }
        print('📋 Returning ${validRequests.length} valid requests');
        return validRequests;
      } else {
        print('📋 ⚠️ Response is not a List: ${requests.runtimeType}');
      }
      print('📋 Returning empty list');
      return [];
    } catch (e, stackTrace) {
      print('📋 ❌ Error fetching leave requests: $e');
      print('📋 Stack trace: $stackTrace');
      return [];
    }
  }

  // Get ALL employees' leave requests (not just current user)
  Future<List<Map<String, dynamic>>> getAllLeaveRequests({
    String? state,
    int? year,
  }) async {
    print('Fetching all employees leave requests...');
    print('  State filter: $state');
    print('  Year filter: $year');

    List<dynamic> domain = [];

    // Filter by state if provided
    if (state != null) {
      domain.add(['state', '=', state]);
    }

    // Filter by year if provided
    if (year != null) {
      domain.add(['date_from', '>=', '$year-01-01']);
      domain.add(['date_from', '<=', '$year-12-31']);
    }

    // If no filters provided, get all requests
    if (domain.isEmpty) {
      domain = [
        ['id', '>', 0]
      ]; // Domain that matches all records
    }

    try {
      final requests = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.leave',
        'search_read',
        [domain],
        {
          'fields': [
            'id',
            'date_from',
            'date_to',
            'holiday_status_id',
            'state',
            'request_date_from',
            'request_date_to',
            'name',
            'employee_id',
            'number_of_days'
          ],
          'context': {'lang': 'fr_FR'}
        }
      ]);

      print('Fetched ${requests is List ? requests.length : 0} leave requests');
      print('Domain used: $domain');
      print('Raw response: $requests');

      if (requests is List) {
        final List<Map<String, dynamic>> validRequests = [];
        for (var item in requests) {
          if (item is Map<String, dynamic>) {
            validRequests.add(item);
          } else {
            print(
                '⚠️ Warning: Skipping non-map item in all requests: ${item.runtimeType} - $item');
          }
        }
        return validRequests;
      } else {
        print(
            '⚠️ Warning: requests is not a List, got ${requests.runtimeType}: $requests');
      }
      return [];
    } catch (e) {
      print('Error fetching all leave requests: $e');
      return [];
    }
  }

  // Get leave types
  Future<List<Map<String, dynamic>>> getLeaveTypes() async {
    print('========================================');
    print('FETCHING LEAVE TYPES');
    print('========================================');

    final syncService = SyncService();

    // Check if offline - return cached leave types if available
    if (!syncService.isConnected) {
      print('📴 Offline: Checking for cached leave types...');
      if (_cachedLeaveTypes != null && _cachedLeaveTypesAt != null) {
        final cacheAge = DateTime.now().difference(_cachedLeaveTypesAt!);
        if (cacheAge < Duration(hours: 24)) {
          print(
              '✅ Using cached leave types (${_cachedLeaveTypes!.length} types, age: ${cacheAge.inMinutes} minutes)');
          return _cachedLeaveTypes!;
        }
      }
      print('⚠️ Offline and no cached leave types available');
      // Return empty list instead of throwing exception to prevent crash
      return [];
    }

    // Check cache first (even when online, to avoid unnecessary calls)
    if (_cachedLeaveTypes != null && _cachedLeaveTypesAt != null) {
      final cacheAge = DateTime.now().difference(_cachedLeaveTypesAt!);
      if (cacheAge < _defaultCacheTtl) {
        print(
            '✅ Using cached leave types (${_cachedLeaveTypes!.length} types)');
        return _cachedLeaveTypes!;
      }
    }

    List<Map<String, dynamic>> types = <Map<String, dynamic>>[];

    try {
      print('Step 1: Using search_read with French context...');
      final raw = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.leave.type',
        'search_read',
        [
          [] // No filter
        ],
        {
          'fields': ['id', 'name'],
          'limit': 100,
          'context': {'lang': 'fr_FR'} // ✅ Request French translations
        }
      ]);

      print('Raw response type: ${raw.runtimeType}');
      print('Raw response: $raw');

      if (raw is List && raw.isNotEmpty) {
        print('Processing ${raw.length} items...');

        for (var item in raw) {
          print('Item type: ${item.runtimeType}, value: $item');

          // Handle if item is already a Map
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            if (map.containsKey('id') && map.containsKey('name')) {
              types.add(map);
              print('  ✓ Added: ${map['name']} (ID: ${map['id']})');
            }
          }
          // Skip non-map items (these might be relation fields returned incorrectly)
        }

        print('Successfully processed ${types.length} leave types');
      }
    } catch (e) {
      print('ERROR in search_read: $e');

      // Fallback: try with basic search + read with French context
      try {
        print('Step 2: Trying search + read with French context...');
        final ids = await _callRPC('object', 'execute', [
          database,
          _userId,
          _password,
          'hr.leave.type',
          'search',
          [], // No domain
          0, // offset
          100 // limit
        ]);

        print('Found IDs: $ids');

        if (ids is List && ids.isNotEmpty) {
          // Filter to only integers
          final validIds = ids.whereType<int>().toList();
          print('Valid IDs: $validIds');

          if (validIds.isNotEmpty) {
            // Use execute_kw for read to pass context
            final records = await _callRPC('object', 'execute_kw', [
              database,
              _userId,
              _password,
              'hr.leave.type',
              'read',
              [validIds],
              {
                'fields': ['id', 'name'],
                'context': {'lang': 'fr_FR'} // ✅ Request French translations
              }
            ]);

            print('Read result: $records');

            if (records is List) {
              for (var record in records) {
                if (record is Map) {
                  types.add(Map<String, dynamic>.from(record));
                }
              }
            }
          }
        }
      } catch (e2) {
        print('ERROR in search+read: $e2');

        // Last resort: legacy model with French context
        try {
          print(
              'Step 3: Trying legacy hr.holidays.status with French context...');
          final legacyIds = await _callRPC('object', 'execute', [
            database,
            _userId,
            _password,
            'hr.holidays.status',
            'search',
            [],
            0,
            100
          ]);

          if (legacyIds is List && legacyIds.isNotEmpty) {
            final validIds = legacyIds.whereType<int>().toList();

            if (validIds.isNotEmpty) {
              final records = await _callRPC('object', 'execute_kw', [
                database,
                _userId,
                _password,
                'hr.holidays.status',
                'read',
                [validIds],
                {
                  'fields': ['id', 'name'],
                  'context': {'lang': 'fr_FR'} // ✅ Request French translations
                }
              ]);

              if (records is List) {
                for (var record in records) {
                  if (record is Map) {
                    types.add(Map<String, dynamic>.from(record));
                  }
                }
              }
            }
          }
        } catch (e3) {
          print('ERROR in legacy: $e3');
        }
      }
    }

    print('========================================');
    print('Total leave types fetched: ${types.length}');

    if (types.isNotEmpty) {
      print('Leave types before filtering:');
      for (var type in types) {
        print('  - ID: ${type['id']}, Name: ${type['name']}');
      }
    }

    // Filter out "Heures supplémentaires"
    final beforeFilter = types.length;
    types = types.where((t) {
      final name = (t['name'] ?? '').toString().trim().toLowerCase();
      return name != 'heures supplémentaires';
    }).toList();

    print(
        'After filtering: ${types.length} (removed ${beforeFilter - types.length})');
    print('========================================');

    // Cache the leave types
    if (types.isNotEmpty) {
      _cachedLeaveTypes = types;
      _cachedLeaveTypesAt = DateTime.now();
      print('✅ Cached ${types.length} leave types');
    }

    if (types.isEmpty) {
      // If we have cached types, use them even if they're old
      if (_cachedLeaveTypes != null && _cachedLeaveTypes!.isNotEmpty) {
        print('⚠️ No new leave types found, using cached types');
        return _cachedLeaveTypes!;
      }
      throw Exception(
          'No leave types available. Please check Odoo configuration and user permissions');
    }

    return types;
  }

  // Create leave request - UPDATED to use leave type ID directly
  Future<int> createLeaveRequest({
    required int leaveTypeId,
    required DateTime dateFrom,
    required DateTime dateTo,
    String? reason,
    bool? isHalfDay, // Optional: specify if it's a half-day leave
  }) async {
    final syncService = SyncService();

    // Check if offline - queue operation if so
    if (!syncService.isConnected) {
      print('📴 Offline: Queueing leave request for sync');
      final queueId = await syncService.queueOperation(
        operationType: SyncService.opLeaveRequest,
        operationData: {
          'leaveTypeId': leaveTypeId,
          'dateFrom': dateFrom.toIso8601String(),
          'dateTo': dateTo.toIso8601String(),
          'reason': reason,
          'isHalfDay': isHalfDay,
        },
      );
      return queueId; // Return queue ID as temporary ID for offline mode
    }

    final employeeId = await getCurrentEmployeeId();

    // Normalize dates to start/end of day in local timezone
    final normalizedDateFrom = DateTime(dateFrom.year, dateFrom.month,
        dateFrom.day, 0, 0, 0 // Start of day: 00:00:00
        );

    final normalizedDateTo = DateTime(dateTo.year, dateTo.month, dateTo.day, 23,
        59, 59 // End of day: 23:59:59
        );

    // Format dates in Odoo's expected format: 'YYYY-MM-DD HH:MM:SS'
    String formatOdooDateTime(DateTime dt) {
      return '${dt.year.toString().padLeft(4, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}:'
          '${dt.second.toString().padLeft(2, '0')}';
    }

    final formattedDateFrom = formatOdooDateTime(normalizedDateFrom);
    final formattedDateTo = formatOdooDateTime(normalizedDateTo);

    // Check if the leave type name contains "demi" to auto-detect half-day
    String? leaveTypeName;
    bool autoDetectHalfDay = false;

    try {
      // Get leave type name to check if it's a half-day type
      final leaveTypeInfo = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.leave.type',
        'read',
        [
          [leaveTypeId]
        ],
        {
          'fields': ['name']
        }
      ]);

      if (leaveTypeInfo is List && leaveTypeInfo.isNotEmpty) {
        final typeData = leaveTypeInfo[0];
        if (typeData is Map && typeData.containsKey('name')) {
          leaveTypeName = typeData['name'].toString();
          final typeNameLower = leaveTypeName.toLowerCase();
          autoDetectHalfDay =
              typeNameLower.contains('demi') || typeNameLower.contains('half');
        }
      }
    } catch (e) {
      print('⚠️ Could not fetch leave type name: $e');
    }

    // Determine if it's a half-day: explicit parameter takes precedence, then auto-detect
    final shouldBeHalfDay = isHalfDay ?? autoDetectHalfDay;

    // If it's a half-day and dates are the same day, it's a single half-day
    final isSameDay = dateFrom.year == dateTo.year &&
        dateFrom.month == dateTo.month &&
        dateFrom.day == dateTo.day;

    print('Creating leave request with:');
    print('  Employee ID: $employeeId');
    print('  Leave Type ID: $leaveTypeId');
    print('  Leave Type Name: $leaveTypeName');
    print('  Date From (original): $dateFrom');
    print('  Date From (normalized): $normalizedDateFrom');
    print('  Date From (formatted): $formattedDateFrom');
    print('  Date To (original): $dateTo');
    print('  Date To (normalized): $normalizedDateTo');
    print('  Date To (formatted): $formattedDateTo');
    print('  Is Same Day: $isSameDay');
    print('  Is Half Day (explicit): $isHalfDay');
    print('  Auto-detect Half Day: $autoDetectHalfDay');
    print('  Should be Half Day: $shouldBeHalfDay');
    print('  Reason: $reason');

    try {
      // Build leave data
      final leaveData = {
        'employee_id': employeeId,
        'holiday_status_id': leaveTypeId,
        'request_date_from': formattedDateFrom,
        'request_date_to': formattedDateTo,
        'name': reason ?? 'Demande de congé',
      };

      // Add request_unit_half if it's a half-day and same day
      if (shouldBeHalfDay && isSameDay) {
        leaveData['request_unit_half'] = true;
        print('✅ Adding request_unit_half: true');
      }

      final leaveId = await _callRPC('object', 'execute',
          [database, _userId, _password, 'hr.leave', 'create', leaveData]);

      print('Leave request created successfully with ID: $leaveId');
      return leaveId;
    } catch (e) {
      print('ERROR creating leave request: $e');
      rethrow;
    }
  }

  // Get holidays for calendar eligibility
  Future<List<DateTime>> getHolidays(int year) async {
    final holidays = await _callRPC('object', 'execute', [
      database,
      _userId,
      _password,
      'resource.calendar.leaves',
      'search_read',
      [
        ['date_from', '>=', '$year-01-01'],
        ['date_to', '<=', '$year-12-31']
      ],
      ['date_from', 'date_to']
    ]);

    List<DateTime> holidayDates = [];
    for (var holiday in holidays) {
      DateTime from =
          DateTime.parse(holiday['date_from'].toString().split(' ')[0]);
      DateTime to = DateTime.parse(holiday['date_to'].toString().split(' ')[0]);

      // Add all dates in the range
      DateTime current = from;
      while (!current.isAfter(to)) {
        holidayDates.add(current);
        current = current.add(const Duration(days: 1));
      }
    }

    return holidayDates;
  }

  // Get approved leaves for calendar display - ALL COMPANY EMPLOYEES
  Future<List<Map<String, dynamic>>> getApprovedLeaves(int year) async {
    print('Loading approved leaves for year $year... (ALL COMPANY EMPLOYEES)');

    print('Fetching approved leave requests for all employees...');
    print('  State filter: validate');
    print('  Year filter: $year');

    try {
      final raw = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.leave',
        'search_read',
        [
          [
            ['state', '=', 'validate'], // Only approved leaves
            ['date_from', '>=', '$year-01-01'],
            ['date_to', '<=', '$year-12-31']
          ]
        ],
        {
          'fields': [
            'date_from',
            'date_to',
            'holiday_status_id',
            'name',
            'employee_id'
          ],
          'limit': 1000,
          'context': {'lang': 'fr_FR'}
        }
      ]);

      print('Fetched ${raw is List ? raw.length : 0} leave requests');
      print('Raw response type: ${raw.runtimeType}');
      if (raw is List && raw.isNotEmpty) {
        print('First item type: ${raw.first.runtimeType}');
        print('First item: ${raw.first}');
      }

      List<Map<String, dynamic>> leaves = [];

      if (raw is List && raw.isNotEmpty) {
        for (var i = 0; i < raw.length; i++) {
          var item = raw[i];
          print('Processing item $i: ${item.runtimeType}');
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            print('  Map keys: ${map.keys.toList()}');
            if (map.containsKey('date_from') && map.containsKey('date_to')) {
              leaves.add(map);
              print(
                  '  ✓ Added leave: ${map['date_from']} to ${map['date_to']}');
            } else {
              print('  ✗ Missing date fields');
            }
          } else {
            print('  ✗ Not a Map: $item');
          }
        }
      }

      print('Loaded ${leaves.length} approved leaves for all employees');
      return leaves;
    } catch (e) {
      print('Error fetching approved leave requests: $e');
      return [];
    }
  }

  // Get pending leaves for calendar display - ALL COMPANY EMPLOYEES
  Future<List<Map<String, dynamic>>> getPendingLeaves(int year) async {
    print('Loading pending leaves for year $year... (ALL COMPANY EMPLOYEES)');

    print('Fetching pending leave requests for all employees...');
    print('  State filter: confirm, draft, validate1');
    print('  Year filter: $year');

    try {
      final raw = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.leave',
        'search_read',
        [
          [
            [
              'state',
              'in',
              ['draft', 'confirm', 'validate1']
            ], // Pending states
            ['date_from', '>=', '$year-01-01'],
            ['date_to', '<=', '$year-12-31']
          ]
        ],
        {
          'fields': [
            'date_from',
            'date_to',
            'holiday_status_id',
            'name',
            'employee_id',
            'state'
          ],
          'limit': 1000,
          'context': {'lang': 'fr_FR'}
        }
      ]);

      print('Fetched ${raw is List ? raw.length : 0} leave requests');
      print('Raw response type: ${raw.runtimeType}');
      if (raw is List && raw.isNotEmpty) {
        print('First item type: ${raw.first.runtimeType}');
        print('First item: ${raw.first}');
      }

      List<Map<String, dynamic>> leaves = [];

      if (raw is List && raw.isNotEmpty) {
        for (var i = 0; i < raw.length; i++) {
          var item = raw[i];
          print('Processing item $i: ${item.runtimeType}');
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            print('  Map keys: ${map.keys.toList()}');
            if (map.containsKey('date_from') && map.containsKey('date_to')) {
              leaves.add(map);
              print(
                  '  ✓ Added leave: ${map['date_from']} to ${map['date_to']}');
            } else {
              print('  ✗ Missing date fields');
            }
          } else {
            print('  ✗ Not a Map: $item');
          }
        }
      }

      print('Loaded ${leaves.length} pending leaves for all employees');
      return leaves;
    } catch (e) {
      print('Error fetching pending leave requests: $e');
      return [];
    }
  }

  // Get Moroccan public holidays for a given year
  Future<List<DateTime>> getMoroccanHolidays(int year) async {
    List<DateTime> holidays = [];

    // Fixed holidays (same date every year)
    holidays.addAll([
      DateTime(year, 1, 1), // New Year's Day
      DateTime(year, 1, 11), // Independence Manifesto Day
      DateTime(year, 5, 1), // Labor Day
      DateTime(year, 7, 30), // Throne Day
      DateTime(year, 8, 14), // Oued Ed-Dahab Day
      DateTime(year, 8, 20), // Revolution Day
      DateTime(year, 8, 21), // Youth Day
      DateTime(year, 11, 6), // Green March Day
      DateTime(year, 11, 18), // Independence Day
    ]);

    // Islamic holidays (approximate dates - these change each year)
    // Note: For production, you should use a proper Islamic calendar library
    // These are approximate dates for 2024-2025
    if (year == 2024) {
      holidays.addAll([
        DateTime(2024, 3, 11), // Ramadan start (approximate)
        DateTime(2024, 4, 10), // Eid al-Fitr (approximate)
        DateTime(2024, 6, 16), // Eid al-Adha (approximate)
        DateTime(2024, 7, 7), // Islamic New Year (approximate)
        DateTime(2024, 9, 15), // Prophet's Birthday (approximate)
      ]);
    } else if (year == 2025) {
      holidays.addAll([
        DateTime(2025, 3, 1), // Ramadan start (approximate)
        DateTime(2025, 3, 30), // Eid al-Fitr (approximate)
        DateTime(2025, 6, 6), // Eid al-Adha (approximate)
        DateTime(2025, 6, 26), // Islamic New Year (approximate)
        DateTime(2025, 9, 5), // Prophet's Birthday (approximate)
      ]);
    }

    return holidays;
  }

  // Check if date is eligible for leave
  Future<bool> isDateEligible(DateTime date) async {
    // Check if it's weekend
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return false;
    }

    // Check if it's in the past
    if (date.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      return false;
    }

    // Check if it's a holiday
    final holidays = await getHolidays(date.year);
    return !holidays.any((holiday) =>
        holiday.year == date.year &&
        holiday.month == date.month &&
        holiday.day == date.day);
  }

  // Get all employees (for HR)
  Future<List<Map<String, dynamic>>> getAllEmployees() async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      final employees = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'search_read',
        [
          [] // No filters - get all employees
        ],
        {
          'fields': [
            'id',
            'name',
            'job_id',
            'work_email',
            'work_phone',
            'department_id',
            'parent_id',
            'image_1920',
          ],
          'order': 'name asc',
        }
      ]);

      if (employees is List) {
        final List<Map<String, dynamic>> validEmployees = [];
        for (var item in employees) {
          if (item is Map<String, dynamic>) {
            validEmployees.add(item);
          } else {
            print(
                '⚠️ Warning: Skipping non-map item in employees: ${item.runtimeType} - $item');
          }
        }
        return validEmployees;
      } else {
        print(
            '⚠️ Warning: employees is not a List, got ${employees.runtimeType}: $employees');
      }
      return [];
    } catch (e) {
      print('Error fetching all employees: $e');
      return [];
    }
  }

  // Get direct reports for the current manager
  Future<List<Map<String, dynamic>>> getDirectReports(
      {bool useCache = true}) async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      // Serve from cache if available and fresh
      if (useCache &&
          _cachedDirectReports != null &&
          _cachedDirectReportsAt != null &&
          DateTime.now().difference(_cachedDirectReportsAt!) <
              _defaultCacheTtl) {
        return _cachedDirectReports!;
      }

      final employeeId = await getCurrentEmployeeId();
      print('🔍 Getting direct reports for manager: $employeeId');

      // First, let's debug the current employee details
      final currentEmployee = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'read',
        [employeeId],
        {
          'fields': ['id', 'name', 'parent_id', 'job_id', 'department_id']
        }
      ]);

      print('👤 Current employee details: $currentEmployee');

      // Get employees where parent_id is the current employee
      final directReports = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'search_read',
        [
          [
            ['parent_id', '=', employeeId]
          ]
        ],
        {
          'fields': [
            'id',
            'name',
            'job_id',
            'work_email',
            'work_phone',
            'department_id',
            'parent_id',
            'image_1920',
          ],
          'order': 'name asc',
        }
      ]);

      print(
          '📊 Direct reports found: ${directReports is List ? directReports.length : 0}');
      print('📋 Direct reports data: $directReports');

      // If no direct reports found, let's try to find all employees to debug
      if (directReports is List && directReports.isEmpty) {
        print('🔄 No direct reports found, checking all employees...');

        final allEmployees = await _callRPC('object', 'execute_kw', [
          database,
          _userId,
          _password,
          'hr.employee',
          'search_read',
          [[]], // No filter
          {
            'fields': ['id', 'name', 'parent_id', 'job_id'],
            'limit': 20,
          }
        ]);

        print('👥 All employees (first 20): $allEmployees');

        // Check if any employees have this manager as parent
        if (allEmployees is List) {
          for (var emp in allEmployees) {
            if (emp is Map && emp['parent_id'] is List) {
              final parentId = emp['parent_id'][0];
              print(
                  '🔍 Employee ${emp['name']} has parent_id: $parentId (looking for: $employeeId)');
            }
          }
        }
      }

      if (directReports is List) {
        final List<Map<String, dynamic>> validReports = [];
        for (var item in directReports) {
          if (item is Map<String, dynamic>) {
            validReports.add(item);
          } else {
            print(
                '⚠️ Warning: Skipping non-map item in direct reports: ${item.runtimeType} - $item');
          }
        }
        // cache
        _cachedDirectReports = validReports;
        _cachedDirectReportsAt = DateTime.now();
        return validReports;
      } else {
        print(
            '⚠️ Warning: directReports is not a List, got ${directReports.runtimeType}: $directReports');
      }
      return [];
    } catch (e) {
      print('❌ Error fetching direct reports: $e');
      return [];
    }
  }

  // Get all employees under Mitchell's management hierarchy (CEO view)
  Future<List<Map<String, dynamic>>> getAllEmployeesUnderManagement(
      {bool useCache = true}) async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      // Serve from cache if available and fresh
      if (useCache &&
          _cachedAllManagedEmployees != null &&
          _cachedAllManagedEmployeesAt != null &&
          DateTime.now().difference(_cachedAllManagedEmployeesAt!) <
              _defaultCacheTtl) {
        return _cachedAllManagedEmployees!;
      }

      // Get all employees (since Mitchell is CEO/Manager of managers)
      final employees = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'search_read',
        [
          [] // No filters - get all employees (CEO can see everyone)
        ],
        {
          'fields': [
            'id',
            'name',
            'job_id',
            'work_email',
            'work_phone',
            'department_id',
            'parent_id',
            'image_1920',
          ],
          'order': 'name asc',
        }
      ]);

      if (employees is List) {
        final List<Map<String, dynamic>> validEmployees = [];
        for (var item in employees) {
          if (item is Map<String, dynamic>) {
            validEmployees.add(item);
          } else {
            print(
                '⚠️ Warning: Skipping non-map item in all employees: ${item.runtimeType} - $item');
          }
        }
        // cache
        _cachedAllManagedEmployees = validEmployees;
        _cachedAllManagedEmployeesAt = DateTime.now();
        return validEmployees;
      } else {
        print(
            '⚠️ Warning: employees is not a List, got ${employees.runtimeType}: $employees');
      }
      return [];
    } catch (e) {
      print('Error fetching all employees under management: $e');
      return [];
    }
  }

  // Debug method to check employee hierarchy
  Future<void> debugEmployeeHierarchy() async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      final employeeId = await getCurrentEmployeeId();
      print('🔍 DEBUG: Current employee ID: $employeeId');

      // Get current employee details
      final currentEmployee = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'read',
        [employeeId],
        {
          'fields': ['id', 'name', 'parent_id', 'user_id', 'job_id']
        }
      ]);

      print('👤 Current employee: $currentEmployee');

      // Get all employees to see hierarchy
      final allEmployees = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'search_read',
        [[]],
        {
          'fields': ['id', 'name', 'parent_id', 'user_id', 'job_id']
        }
      ]);

      print('👥 All employees: $allEmployees');

      // Check if any employees have this user as parent
      final subordinates = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'search_read',
        [
          [
            ['parent_id', '=', employeeId]
          ]
        ],
        {
          'fields': ['id', 'name', 'parent_id', 'user_id', 'job_id']
        }
      ]);

      print('👨‍👩‍👧‍👦 Direct subordinates: $subordinates');
    } catch (e) {
      print('❌ Error debugging hierarchy: $e');
    }
  }

  // Debug method to understand why Othman's leave requests don't appear in manager view
  Future<void> debugOthmanConfiguration() async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      final employeeId = await getCurrentEmployeeId();
      print('🔍 === DEBUGGING OTHMAN CONFIGURATION ===');
      print('Manager Employee ID: $employeeId');

      // Get manager details
      final managerDetails = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'read',
        [employeeId],
        {
          'fields': ['id', 'name', 'department_id', 'parent_id', 'job_id']
        }
      ]);

      print('👤 Manager details: $managerDetails');

      // Search for Othman specifically
      final othmanEmployees = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'search_read',
        [
          [
            ['name', 'ilike', 'othman']
          ]
        ],
        {
          'fields': [
            'id',
            'name',
            'department_id',
            'parent_id',
            'job_id',
            'user_id'
          ]
        }
      ]);

      print('🔍 Othman employees found: $othmanEmployees');

      if (othmanEmployees is List && othmanEmployees.isNotEmpty) {
        final othman = othmanEmployees.first;
        print('👤 Othman details:');
        print('  - ID: ${othman['id']}');
        print('  - Name: ${othman['name']}');
        print('  - Department: ${othman['department_id']}');
        print('  - Parent: ${othman['parent_id']}');
        print('  - Job: ${othman['job_id']}');
        print('  - User ID: ${othman['user_id']}');

        // Check if Othman has Mitchell as parent
        final othmanParentId = othman['parent_id'];
        if (othmanParentId is List && othmanParentId.isNotEmpty) {
          final parentId = othmanParentId[0];
          print('🔍 Othman parent ID: $parentId');
          print('🔍 Manager ID: $employeeId');
          print('🔍 Are they the same? ${parentId == employeeId}');
        }

        // Check if they're in the same department
        final managerDept = managerDetails[0]['department_id'];
        final othmanDept = othman['department_id'];
        print('🔍 Manager department: $managerDept');
        print('🔍 Othman department: $othmanDept');

        if (managerDept is List && othmanDept is List) {
          print('🔍 Same department? ${managerDept[0] == othmanDept[0]}');
        }

        // Get Othman's pending leave requests
        final othmanLeaves = await _callRPC('object', 'execute_kw', [
          database,
          _userId,
          _password,
          'hr.leave',
          'search_read',
          [
            [
              ['employee_id', '=', othman['id']],
              ['state', '=', 'confirm']
            ]
          ],
          {
            'fields': [
              'id',
              'employee_id',
              'name',
              'state',
              'request_date_from',
              'request_date_to'
            ]
          }
        ]);

        print('📋 Othman pending leaves: $othmanLeaves');
      }

      // Check all pending leave requests
      final allPendingLeaves = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.leave',
        'search_read',
        [
          [
            ['state', '=', 'confirm']
          ]
        ],
        {
          'fields': ['id', 'employee_id', 'name', 'state', 'request_date_from'],
          'limit': 20
        }
      ]);

      print('📋 All pending leave requests:');
      if (allPendingLeaves is List) {
        for (var leave in allPendingLeaves) {
          if (leave is Map<String, dynamic>) {
            final empId = leave['employee_id'];
            final leaveName = leave['name'];
            final state = leave['state'];
            print('  - Leave: $leaveName, Employee: $empId, State: $state');
          }
        }
      }

      print('🔍 === END OTHMAN DEBUGGING ===');
    } catch (e) {
      print('❌ Error in debugOthmanConfiguration: $e');
    }
  }

  // Alternative method to get team members by department or other criteria
  Future<List<Map<String, dynamic>>> getTeamMembersAlternative() async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      final employeeId = await getCurrentEmployeeId();
      print('🔍 Alternative: Manager Employee ID: $employeeId');

      // Get current employee's department
      final currentEmployee = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'read',
        [employeeId],
        {
          'fields': ['id', 'name', 'department_id', 'parent_id']
        }
      ]);

      print('👤 Current employee details: $currentEmployee');

      if (currentEmployee.isNotEmpty) {
        final departmentId = currentEmployee[0]['department_id'];
        print('🏢 Department ID: $departmentId');

        // Try to get employees from same department (excluding self)
        final departmentEmployees = await _callRPC('object', 'execute_kw', [
          database,
          _userId,
          _password,
          'hr.employee',
          'search_read',
          [
            [
              ['department_id', '=', departmentId],
              ['id', '!=', employeeId] // Exclude self
            ]
          ],
          {
            'fields': [
              'id',
              'name',
              'job_id',
              'work_email',
              'work_phone',
              'image_1920',
              'department_id',
            ]
          }
        ]);

        print(
            '👥 Department employees found: ${departmentEmployees is List ? departmentEmployees.length : 0}');
        print('📋 Department employees: $departmentEmployees');

        if (departmentEmployees is List) {
          // Additional safety check - ensure all items are Maps
          final List<Map<String, dynamic>> validMembers = [];
          for (var item in departmentEmployees) {
            if (item is Map<String, dynamic>) {
              validMembers.add(item);
            } else {
              print(
                  '⚠️ Warning: Skipping non-map item in department employees: ${item.runtimeType} - $item');
            }
          }
          return validMembers;
        } else {
          print(
              '⚠️ Warning: departmentEmployees is not a List, got ${departmentEmployees.runtimeType}: $departmentEmployees');
        }
      }

      return [];
    } catch (e) {
      print('❌ Error fetching team members (alternative): $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTeamMembers(
      {bool useCache = true}) async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      if (useCache &&
          _cachedTeamMembers != null &&
          _cachedTeamMembersAt != null &&
          DateTime.now().difference(_cachedTeamMembersAt!) < _defaultCacheTtl) {
        return _cachedTeamMembers!;
      }

      // First get current employee ID
      final employeeId = await getCurrentEmployeeId();
      print('🔍 Manager Employee ID: $employeeId');

      // Get subordinates
      final subordinates = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.employee',
        'search_read',
        [
          [
            ['parent_id', '=', employeeId]
          ]
        ],
        {
          'fields': [
            'id',
            'name',
            'job_id',
            'work_email',
            'work_phone',
            'image_1920',
            'department_id',
          ]
        }
      ]);

      print(
          '📊 Subordinates found: ${subordinates is List ? subordinates.length : 0}');
      print('📋 Subordinates data: $subordinates');

      if (subordinates is List) {
        // Additional safety check - ensure all items are Maps
        final List<Map<String, dynamic>> validMembers = [];
        for (var item in subordinates) {
          if (item is Map<String, dynamic>) {
            validMembers.add(item);
          } else {
            print(
                '⚠️ Warning: Skipping non-map item in team members: ${item.runtimeType} - $item');
          }
        }
        _cachedTeamMembers = validMembers;
        _cachedTeamMembersAt = DateTime.now();
        return validMembers;
      } else {
        print(
            '⚠️ Warning: subordinates is not a List, got ${subordinates.runtimeType}: $subordinates');
      }
      return [];
    } catch (e) {
      print('❌ Error fetching team members: $e');
      return [];
    }
  }

  // Get pending leave requests for manager's approval
  Future<List<Map<String, dynamic>>> getPendingTeamLeaveRequests(
      {bool useCache = true}) async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      if (useCache &&
          _cachedPendingTeamLeaves != null &&
          _cachedPendingTeamLeavesAt != null &&
          DateTime.now().difference(_cachedPendingTeamLeavesAt!) <
              _defaultCacheTtl) {
        return _cachedPendingTeamLeaves!;
      }

      final employeeId = await getCurrentEmployeeId();
      print('🔍 Searching pending leaves for manager: $employeeId');

      // Get pending leave requests for team members
      final requests = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.leave',
        'search_read',
        [
          [
            ['state', '=', 'confirm'], // Pending status
            ['employee_id.parent_id', '=', employeeId] // Manager's subordinates
          ]
        ],
        {
          'fields': [
            'id',
            'employee_id',
            'holiday_status_id',
            'request_date_from',
            'request_date_to',
            'number_of_days',
            'state',
            'name',
          ],
          'order': 'create_date desc',
          'limit': 50,
        }
      ]);

      print(
          '📊 Pending requests found: ${requests is List ? requests.length : 0}');

      if (requests is List) {
        // Additional safety check - ensure all items are Maps
        final List<Map<String, dynamic>> validRequests = [];
        for (var item in requests) {
          if (item is Map<String, dynamic>) {
            validRequests.add(item);
          } else {
            print(
                '⚠️ Warning: Skipping non-map item in requests: ${item.runtimeType} - $item');
          }
        }
        _cachedPendingTeamLeaves = validRequests;
        _cachedPendingTeamLeavesAt = DateTime.now();
        return validRequests;
      } else {
        print(
            '⚠️ Warning: requests is not a List, got ${requests.runtimeType}: $requests');
      }
      return [];
    } catch (e) {
      print('❌ Error fetching pending team leave requests: $e');
      return [];
    }
  }

  // Approve leave request
  Future<bool> approveLeaveRequest(int leaveId) async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.leave',
        'action_approve',
        [
          [leaveId]
        ],
      ]);
      return true;
    } catch (e) {
      print('Error approving leave request: $e');
      return false;
    }
  }

  // Refuse leave request
  Future<bool> refuseLeaveRequest(int leaveId) async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.leave',
        'action_refuse',
        [
          [leaveId]
        ],
      ]);
      return true;
    } catch (e) {
      print('Error refusing leave request: $e');
      return false;
    }
  }

  // Get team statistics
  Future<Map<String, dynamic>> getTeamStatistics() async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      final employeeId = await getCurrentEmployeeId();
      print('📊 Getting team statistics for employee: $employeeId');

      // Get team size - for CEO/Manager of managers, get all employees under management
      // For regular managers, get direct reports only
      var teamMembers = await getAllEmployeesUnderManagement();
      var teamSize = teamMembers.length;
      print('👥 Team size (all employees under management): $teamSize');

      // If no employees found with full hierarchy, fall back to direct reports
      if (teamSize == 0) {
        print(
            '🔄 No employees found with full hierarchy, trying direct reports...');
        teamMembers = await getTeamMembers();
        teamSize = teamMembers.length;
        print('👥 Team size (direct reports): $teamSize');
      }

      // If still no team members found, try department method
      if (teamSize == 0) {
        print('🔄 Trying alternative department method...');
        teamMembers = await getTeamMembersAlternative();
        teamSize = teamMembers.length;
        print('👥 Team size (department method): $teamSize');
      }

      // Get pending approvals - try both methods
      var pendingRequests = await getPendingTeamLeaveRequests();
      var pendingCount = pendingRequests.length;
      print('⏳ Pending approvals (parent_id method): $pendingCount');

      // If no pending requests found and we have team members from department method
      if (pendingCount == 0 && teamMembers.isNotEmpty) {
        print('🔄 Trying alternative pending requests method...');
        // Get all pending requests and filter by team member IDs
        final allPendingRequests = await _callRPC('object', 'execute_kw', [
          database,
          _userId,
          _password,
          'hr.leave',
          'search_read',
          [
            [
              ['state', '=', 'confirm'] // Pending status
            ]
          ],
          {
            'fields': [
              'id',
              'employee_id',
              'holiday_status_id',
              'request_date_from',
              'request_date_to',
              'number_of_days',
              'state',
              'name',
            ],
            'order': 'create_date desc',
            'limit': 50,
          }
        ]);

        if (allPendingRequests is List) {
          final teamMemberIds = teamMembers
              .where((member) => member['id'] != null)
              .map((member) => member['id'])
              .toList();

          // Filter valid requests and handle null/type issues
          final List<Map<String, dynamic>> validRequests = [];
          for (var request in allPendingRequests) {
            if (request is Map<String, dynamic>) {
              try {
                final employeeId = request['employee_id'];
                if (employeeId is List &&
                    employeeId.isNotEmpty &&
                    teamMemberIds.contains(employeeId[0])) {
                  validRequests.add(request);
                }
              } catch (e) {
                print('⚠️ Warning: Error processing request: $e');
                print('Request data: $request');
              }
            } else {
              print(
                  '⚠️ Warning: Skipping non-map request: ${request.runtimeType} - $request');
            }
          }

          pendingRequests = validRequests;
          pendingCount = pendingRequests.length;
          print('⏳ Pending approvals (department method): $pendingCount');
        } else {
          print(
              '⚠️ Warning: allPendingRequests is not a List, got ${allPendingRequests.runtimeType}: $allPendingRequests');
          pendingRequests = [];
          pendingCount = 0;
        }
      }

      // TEMPORARY: If still no pending requests, show ALL pending requests for debugging
      if (pendingCount == 0) {
        print('🔄 TEMPORARY: Showing ALL pending requests for debugging...');
        final allPendingRequests = await _callRPC('object', 'execute_kw', [
          database,
          _userId,
          _password,
          'hr.leave',
          'search_read',
          [
            [
              ['state', '=', 'confirm'] // Pending status
            ]
          ],
          {
            'fields': [
              'id',
              'employee_id',
              'holiday_status_id',
              'request_date_from',
              'request_date_to',
              'number_of_days',
              'state',
              'name',
            ],
            'order': 'create_date desc',
            'limit': 50,
          }
        ]);

        if (allPendingRequests is List) {
          // Additional safety check - ensure all items are Maps
          final List<Map<String, dynamic>> validRequests = [];
          for (var item in allPendingRequests) {
            if (item is Map<String, dynamic>) {
              validRequests.add(item);
            } else {
              print(
                  '⚠️ Warning: Skipping non-map item in all pending requests: ${item.runtimeType} - $item');
            }
          }
          pendingRequests = validRequests;
          pendingCount = pendingRequests.length;
          print('⏳ TEMPORARY: All pending approvals: $pendingCount');
        }
      }

      // Get approved this week
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

      final approvedThisWeek = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.leave',
        'search_count',
        [
          [
            ['state', '=', 'validate'],
            ['employee_id.parent_id', '=', employeeId],
            ['create_date', '>=', startOfWeek.toIso8601String()],
          ]
        ],
      ]);

      // Calculate team productivity (approval rate over last 30 days)
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final totalRequests = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.leave',
        'search_count',
        [
          [
            ['employee_id.parent_id', '=', employeeId],
            ['create_date', '>=', thirtyDaysAgo.toIso8601String()],
          ]
        ],
      ]);

      final approvedRequests = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.leave',
        'search_count',
        [
          [
            ['state', '=', 'validate'],
            ['employee_id.parent_id', '=', employeeId],
            ['create_date', '>=', thirtyDaysAgo.toIso8601String()],
          ]
        ],
      ]);

      // Calculate productivity percentage
      double productivity = 0;
      if (totalRequests != null && totalRequests > 0) {
        productivity = ((approvedRequests ?? 0) / totalRequests * 100);
      } else {
        productivity = 95.0; // Default if no data
      }

      final result = {
        'team_size': teamSize,
        'pending_approvals': pendingCount,
        'approved_this_week': approvedThisWeek ?? 0,
        'team_productivity': productivity.toInt(),
        'team_members': teamMembers,
        'pending_requests': pendingRequests,
      };

      print(
          '✅ Team statistics result: team_size=${result['team_size']}, pending=${result['pending_approvals']}, approved=${result['approved_this_week']}, productivity=${result['team_productivity']}%');
      print(
          '🔍 Team members type: ${result['team_members'].runtimeType}, count: ${(result['team_members'] as List).length}');
      print(
          '🔍 Pending requests type: ${result['pending_requests'].runtimeType}, count: ${(result['pending_requests'] as List).length}');

      // Additional validation before returning
      if (result['team_members'] is List) {
        for (int i = 0; i < (result['team_members'] as List).length; i++) {
          final member = (result['team_members'] as List)[i];
          if (member is! Map<String, dynamic>) {
            print(
                '⚠️ CRITICAL: Team member at index $i is not a Map: ${member.runtimeType} - $member');
          }
        }
      }

      if (result['pending_requests'] is List) {
        for (int i = 0; i < (result['pending_requests'] as List).length; i++) {
          final request = (result['pending_requests'] as List)[i];
          if (request is! Map<String, dynamic>) {
            print(
                '⚠️ CRITICAL: Pending request at index $i is not a Map: ${request.runtimeType} - $request');
          }
        }
      }

      return result;
    } catch (e) {
      print('Error fetching team statistics: $e');
      print('Error details: ${e.toString()}');

      // Try to return partial data if possible
      try {
        var teamMembers = await getTeamMembers();
        var teamSize = teamMembers.length;

        if (teamSize == 0) {
          teamMembers = await getTeamMembersAlternative();
          teamSize = teamMembers.length;
        }

        return {
          'team_size': teamSize,
          'pending_approvals': 0,
          'approved_this_week': 0,
          'team_productivity': 0,
          'team_members': teamMembers,
          'pending_requests': [],
        };
      } catch (fallbackError) {
        print('Fallback also failed: $fallbackError');
        return {
          'team_size': 0,
          'pending_approvals': 0,
          'approved_this_week': 0,
          'team_productivity': 0,
          'team_members': [],
          'pending_requests': [],
        };
      }
    }
  }

  // Method to discover available models
  Future<List<String>> getAvailableModels() async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      // Get all models that start with 'hr.' (HR related)
      final models = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'ir.model', // Model that contains all models
        'search_read',
        [
          [
            ['model', 'like', 'hr.%']
          ] // Filter: models starting with 'hr.'
        ],
        {
          'fields': ['model', 'name'],
          'order': 'model asc',
        }
      ]);

      if (models is List) {
        final List<String> modelNames = [];
        for (var model in models) {
          if (model is Map<String, dynamic> && model['model'] != null) {
            modelNames.add(model['model'].toString());
          }
        }
        return modelNames;
      }
      return [];
    } catch (e) {
      print('Error fetching models: $e');
      return [];
    }
  }

  // Method to get fields of a specific model
  Future<List<Map<String, dynamic>>> getModelFields(String modelName) async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      final fields = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'ir.model.fields', // Model that contains all fields
        'search_read',
        [
          [
            ['model', '=', modelName]
          ] // Filter: fields for specific model
        ],
        {
          'fields': ['name', 'field_description', 'ttype', 'required'],
          'order': 'name asc',
        }
      ]);

      if (fields is List) {
        final List<Map<String, dynamic>> fieldList = [];
        for (var field in fields) {
          if (field is Map<String, dynamic>) {
            fieldList.add(field);
          }
        }
        return fieldList;
      }
      return [];
    } catch (e) {
      print('Error fetching fields for $modelName: $e');
      return [];
    }
  }

  // Logout
  Future<void> logout() async {
    _userId = null;
    _password = null;
  }

  // Check if user is authenticated
  bool get isAuthenticated => _userId != null && _password != null;

  // Request salary certificate
  Future<bool> requestSalaryCertificate({
    required String type, // 'monthly' or 'annual'
    int? fiscalYear,
    bool withDetail = false,
  }) async {
    print('Requesting salary certificate: $type');

    try {
      final employeeId = await getCurrentEmployeeId();

      final requestData = {
        'employee_id': employeeId,
        'document_type': 'salary_certificate',
        'certificate_type': type,
        'fiscal_year': fiscalYear,
        'with_detail': withDetail,
        'request_date': _formatDateForOdoo(DateTime.now()),
        'status': 'pending',
      };

      final result = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.document.request', // Custom model in Odoo
        'create',
        [requestData],
        {
          'context': {'lang': 'fr_FR'}
        }
      ]);

      print('Salary certificate request result: $result');
      return result != null;
    } catch (e) {
      print('Error requesting salary certificate: $e');
      return false;
    }
  }

  // Request work certificate
  Future<bool> requestWorkCertificate() async {
    print('Requesting work certificate');

    try {
      final employeeId = await getCurrentEmployeeId();

      final requestData = {
        'employee_id': employeeId,
        'document_type': 'work_certificate',
        'request_date': _formatDateForOdoo(DateTime.now()),
        'status': 'pending',
      };

      final result = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.document.request',
        'create',
        [requestData],
        {
          'context': {'lang': 'fr_FR'}
        }
      ]);

      print('Work certificate request result: $result');
      return result != null;
    } catch (e) {
      print('Error requesting work certificate: $e');
      return false;
    }
  }

  // Request payslip
  Future<bool> requestPayslip({
    int? month,
    int? year,
  }) async {
    print(
        'Requesting payslip for ${month ?? 'current'}/${year ?? DateTime.now().year}');

    try {
      final employeeId = await getCurrentEmployeeId();

      final requestData = {
        'employee_id': employeeId,
        'document_type': 'payslip',
        'month': month ?? DateTime.now().month,
        'year': year ?? DateTime.now().year,
        'request_date': _formatDateForOdoo(DateTime.now()),
        'status': 'pending',
      };

      final result = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.document.request',
        'create',
        [requestData],
        {
          'context': {'lang': 'fr_FR'}
        }
      ]);

      print('Payslip request result: $result');
      return result != null;
    } catch (e) {
      print('Error requesting payslip: $e');
      return false;
    }
  }

  // Request mission order
  Future<bool> requestMissionOrder({
    required String type, // 'trip' or 'expense'
    String? description,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    print('Requesting mission order: $type');

    try {
      final employeeId = await getCurrentEmployeeId();

      final requestData = {
        'employee_id': employeeId,
        'document_type': 'mission_order',
        'mission_type': type,
        'description': description ?? 'Demande d\'ordre de mission',
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'request_date': _formatDateForOdoo(DateTime.now()),
        'status': 'pending',
      };

      final result = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.document.request',
        'create',
        [requestData],
        {
          'context': {'lang': 'fr_FR'}
        }
      ]);

      print('Mission order request result: $result');
      return result != null;
    } catch (e) {
      print('Error requesting mission order: $e');
      return false;
    }
  }

  // Helper method to make XML-RPC calls
  Future<dynamic> _callRPC(String service, String method, List params) async {
    final xmlBody = _buildXMLRPC(method, params);

    final response = await http.post(
      Uri.parse('$baseUrl/xmlrpc/2/$service'),
      headers: {
        'Content-Type': 'text/xml',
        'User-Agent': 'Flutter-Odoo-Client',
      },
      body: xmlBody,
    );

    if (response.statusCode == 200) {
      return _parseXMLRPCResponse(response.body);
    } else {
      throw Exception(
          'RPC call failed: ${response.statusCode} - ${response.body}');
    }
  }

  // Build XML-RPC request
  String _buildXMLRPC(String method, List params) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0"');
    builder.element('methodCall', nest: () {
      builder.element('methodName', nest: method);
      builder.element('params', nest: () {
        for (var param in params) {
          builder.element('param', nest: () {
            builder.element('value', nest: () {
              _buildValue(builder, param);
            });
          });
        }
      });
    });

    return builder.buildDocument().toXmlString();
  }

  // Build XML value based on type
  void _buildValue(XmlBuilder builder, dynamic value) {
    if (value is String) {
      builder.element('string', nest: value);
    } else if (value is int) {
      builder.element('int', nest: value.toString());
    } else if (value is double) {
      builder.element('double', nest: value.toString());
    } else if (value is bool) {
      builder.element('boolean', nest: value ? '1' : '0');
    } else if (value is List) {
      builder.element('array', nest: () {
        builder.element('data', nest: () {
          for (var item in value) {
            builder.element('value', nest: () {
              _buildValue(builder, item);
            });
          }
        });
      });
    } else if (value is Map) {
      builder.element('struct', nest: () {
        for (var entry in value.entries) {
          builder.element('member', nest: () {
            builder.element('name', nest: entry.key);
            builder.element('value', nest: () {
              _buildValue(builder, entry.value);
            });
          });
        }
      });
    } else {
      builder.element('string', nest: value.toString());
    }
  }

  // Parse XML-RPC response
  dynamic _parseXMLRPCResponse(String xmlString) {
    try {
      final document = XmlDocument.parse(xmlString);

      // Check for faults
      final fault = document.findAllElements('fault').firstOrNull;
      if (fault != null) {
        final faultValue = fault.findAllElements('value').firstOrNull;
        if (faultValue != null) {
          final faultStruct = _parseValue(faultValue);

          // Extract the full error message
          String errorMessage = 'XML-RPC fault occurred';

          if (faultStruct is Map) {
            // Try to get faultString or message
            final faultString =
                faultStruct['faultString'] ?? faultStruct['message'] ?? '';

            // Check if there's a traceback (common in Odoo errors)
            if (faultString is String && faultString.contains('Traceback')) {
              // Try to extract just the actual error message from the traceback
              // In Python tracebacks, the actual exception is at the end
              final lines = faultString.split('\n');

              // Find the last non-empty line which usually contains the actual error
              String? lastErrorLine;
              for (int i = lines.length - 1; i >= 0; i--) {
                final line = lines[i].trim();
                if (line.isNotEmpty &&
                    !line.startsWith('File') &&
                    !line.contains('line')) {
                  lastErrorLine = line;
                  break;
                }
              }

              // If we found a line with the actual error, use it
              if (lastErrorLine != null && lastErrorLine.isNotEmpty) {
                errorMessage = lastErrorLine;
              } else {
                // Fallback: show last 3 lines
                final lastLines =
                    lines.where((l) => l.trim().isNotEmpty).take(3).join('\n');
                errorMessage = lastLines;
              }
            } else if (faultString is String) {
              errorMessage = faultString;
            } else {
              // If faultString is a Map (structured error), try to extract readable message
              final faultCode = faultStruct['faultCode'] ?? '';
              errorMessage =
                  'XML-RPC fault (Code: $faultCode): ${faultStruct.toString()}';
            }
          }

          print('Full fault structure: $faultStruct');
          print('Extracted error message: $errorMessage');
          throw Exception(errorMessage);
        }
        throw Exception('XML-RPC fault occurred');
      }

      // Parse response
      final params = document.findAllElements('params').firstOrNull;
      if (params != null) {
        final param = params.findAllElements('param').firstOrNull;
        if (param != null) {
          return _parseValue(param.findAllElements('value').first);
        }
      }

      return null;
    } catch (e) {
      if (e.toString().contains('XML-RPC fault')) {
        rethrow;
      }
      throw Exception('Failed to parse XML-RPC response: $e');
    }
  }

  // Parse XML value
  dynamic _parseValue(XmlElement valueElement) {
    final children = valueElement.children;
    if (children.isEmpty) return null;

    final child = children.first;
    if (child is XmlElement) {
      switch (child.name.local) {
        case 'string':
          return child.innerText;
        case 'int':
        case 'i4':
          return int.parse(child.innerText);
        case 'double':
          return double.parse(child.innerText);
        case 'boolean':
          return child.innerText == '1';
        case 'array':
          final data = child.findAllElements('data').firstOrNull;
          if (data != null) {
            return data
                .findAllElements('value')
                .map((v) => _parseValue(v))
                .toList();
          }
          return [];
        case 'struct':
          final Map<String, dynamic> result = {};
          for (var member in child.findAllElements('member')) {
            final name = member.findAllElements('name').first.innerText;
            final value = _parseValue(member.findAllElements('value').first);
            result[name] = value;
          }
          return result;
      }
    }

    return child.innerText;
  }

  // Attendance Methods

  // Get last attendance record
  Future<Map<String, dynamic>?> getLastAttendance() async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      final employeeId = await getCurrentEmployeeId();

      final lastAttendance = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.attendance',
        'search_read',
        [
          [
            ['employee_id', '=', employeeId],
          ]
        ],
        {
          'fields': ['check_in', 'check_out', 'employee_id'],
          'order': 'check_in desc',
          'limit': 1,
        }
      ]);

      if (lastAttendance is List && lastAttendance.isNotEmpty) {
        final attendance = lastAttendance[0];
        return {
          'action': attendance['check_out'] == false ? 'check_in' : 'check_out',
          'check_in': attendance['check_in'],
          'check_out': attendance['check_out'],
          'employee_id': attendance['employee_id'],
        };
      }

      return null;
    } catch (e) {
      print('Error fetching last attendance: $e');
      return null;
    }
  }

// Query an existing attendance record to see what auth_method and type_att values are actually used
  Future<Map<String, String?>> getAttendanceFieldValues() async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      // Get any existing attendance record
      final result = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.attendance',
        'search_read',
        [[]],
        {
          'fields': ['auth_method', 'type_att'],
          'limit': 1,
        }
      ]);

      Map<String, String?> fieldValues = {};

      if (result is List && result.isNotEmpty) {
        final record = result[0];
        if (record is Map) {
          if (record['auth_method'] != null) {
            final authMethod = record['auth_method'].toString();
            print('✅ Found existing auth_method in DB: $authMethod');
            fieldValues['auth_method'] = authMethod;
          }
          if (record['type_att'] != null) {
            final typeAtt = record['type_att'].toString();
            print('✅ Found existing type_att in DB: $typeAtt');
            fieldValues['type_att'] = typeAtt;
          }
        }
      }
      return fieldValues;
    } catch (e) {
      print('⚠️ Could not fetch sample field values: $e');
      return {};
    }
  }

// Get valid auth_method values from the hr.attendance model
  Future<List<String>?> getAuthMethodValues() async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    // First, try to get auth_method from an existing record
    final fieldValues = await getAttendanceFieldValues();
    final sampleAuthMethod = fieldValues['auth_method'];

    // Valid auth_method values from Odoo hr.attendance model:
    // Based on the selection field in Odoo, valid values are:
    // visage (Face), pin (PIN Code), qr (QR Code), pointeur (Pointer), nfc (NFC)
    final validValues = ['pointeur', 'visage', 'pin', 'qr', 'nfc'];

    print('ℹ️ Valid auth_method values: $validValues');
    if (sampleAuthMethod != null) {
      print('💡 Using auth_method from sample record: $sampleAuthMethod');
      return [
        sampleAuthMethod,
        ...validValues.where((v) => v != sampleAuthMethod)
      ];
    }

    return validValues;
  }

// Get punching entities (entite_id)
  Future<List<Map<String, dynamic>>> getPunchingEntities() async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    final syncService = SyncService();

    // Check if offline - return cached data if available
    if (!syncService.isConnected) {
      if (_cachedPunchingEntities != null &&
          _cachedPunchingEntitiesAt != null) {
        final cacheAge = DateTime.now().difference(_cachedPunchingEntitiesAt!);
        if (cacheAge < Duration(hours: 24)) {
          print('📴 Offline: Using cached punching entities');
          return _cachedPunchingEntities!;
        }
      }
      // If no cache available offline, return empty list (will use null entiteId)
      print(
          '📴 Offline: No cached entities available, will proceed without entity');
      return [];
    }

    // Check cache first if available and fresh
    if (_cachedPunchingEntities != null && _cachedPunchingEntitiesAt != null) {
      final cacheAge = DateTime.now().difference(_cachedPunchingEntitiesAt!);
      if (cacheAge < _defaultCacheTtl) {
        print('✅ Using cached punching entities');
        return _cachedPunchingEntities!;
      }
    }

    try {
      print('🔍 Fetching entities from model: entite.pointage');

      final result = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'entite.pointage',
        'search_read',
        [],
        {
          'fields': ['id', 'name'],
          'order': 'name asc',
        }
      ]);

      print('Raw result type: ${result.runtimeType}');
      print('Raw result: $result');

      if (result == null) {
        throw Exception('No response from server');
      }

      // Convert the result to proper List<Map<String, dynamic>>
      List<Map<String, dynamic>> entities = [];

      if (result is List) {
        for (var item in result) {
          if (item is Map) {
            // Convert Map<dynamic, dynamic> to Map<String, dynamic>
            entities.add(Map<String, dynamic>.from(item));
          }
        }
      }

      if (entities.isEmpty) {
        print('⚠️ No entities found in database');
        // Don't throw exception, just return empty list
        // The punch in/out will work without entity
        return [];
      }

      // Cache the entities
      _cachedPunchingEntities = entities;
      _cachedPunchingEntitiesAt = DateTime.now();

      print('✅ Found ${entities.length} entities');
      print('📋 Entities: $entities');
      return entities;
    } catch (e) {
      print('❌ Error fetching entities: $e');
      // If we have cached entities, return them even if stale
      if (_cachedPunchingEntities != null &&
          _cachedPunchingEntities!.isNotEmpty) {
        print('⚠️ Using stale cached entities due to error');
        return _cachedPunchingEntities!;
      }
      // Return empty list instead of throwing - allows punch in/out to proceed
      return [];
    }
  }

  // Punch in (Check in)
  Future<bool> punchIn({
    required double latitude,
    required double longitude,
    required DateTime checkIn,
    int? entiteId,
  }) async {
    final syncService = SyncService();

    // Check if offline - queue operation if so
    if (!syncService.isConnected) {
      print('📴 Offline: Queueing punch in for sync');
      await syncService.queueOperation(
        operationType: SyncService.opAttendancePunchIn,
        operationData: {
          'latitude': latitude,
          'longitude': longitude,
          'checkIn': checkIn.toIso8601String(),
          'entiteId': entiteId,
        },
      );
      return true; // Return success immediately for offline mode
    }

    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      final employeeId = await getCurrentEmployeeId();

      print('=== PUNCH IN ATTEMPT ===');
      print('Employee ID: $employeeId');
      print('Latitude: $latitude');
      print('Longitude: $longitude');

      // Check for open attendance first
      try {
        final openAttendance = await _callRPC('object', 'execute_kw', [
          database,
          _userId,
          _password,
          'hr.attendance',
          'search_read',
          [
            [
              ['employee_id', '=', employeeId],
              ['check_out', '=', false],
            ]
          ],
          {
            'fields': ['id', 'check_in'],
            'limit': 1,
          }
        ]);

        if (openAttendance is List && openAttendance.isNotEmpty) {
          print('ERROR: Open attendance found: ${openAttendance[0]}');
          throw Exception('You must check out before checking in again.');
        }
        print('✓ No open attendance found');
      } catch (e) {
        if (e.toString().contains('check out before')) rethrow;
        print('Warning: Could not verify open attendance: $e');
      }

      // Get entity ID
      int? finalEntiteId = entiteId;
      if (finalEntiteId == null) {
        final entities = await getPunchingEntities();
        if (entities.isEmpty) {
          throw Exception('No punching entity available.');
        }
        finalEntiteId = entities[0]['id'];
        print('Using entity ID: $finalEntiteId');
      }

      // Get valid auth_method values (or use defaults)
      final authMethodValues = await getAuthMethodValues();
      print('🔍 Available auth_method values: $authMethodValues');

      // Try to determine the correct auth_method value
      String? authMethodValue;
      if (authMethodValues != null && authMethodValues.isNotEmpty) {
        // Try pointeur first (manual method, commonly used)
        if (authMethodValues.contains('pointeur')) {
          authMethodValue = 'pointeur';
        } else if (authMethodValues.contains('qr')) {
          authMethodValue = 'qr';
        } else if (authMethodValues.contains('pin')) {
          authMethodValue = 'pin';
        } else if (authMethodValues.contains('visage')) {
          authMethodValue = 'visage';
        } else if (authMethodValues.contains('nfc')) {
          authMethodValue = 'nfc';
        } else {
          // Use the first available value
          authMethodValue = authMethodValues.first;
        }
      } else {
        // Fallback to pointeur (most common based on existing records)
        authMethodValue = 'pointeur';
      }
      print('Using auth_method: $authMethodValue');

      // Format check-in time in UTC
      final checkInUtc = checkIn.toUtc(); // Convert to UTC first
      final checkInFormatted = '${checkInUtc.year.toString().padLeft(4, '0')}-'
          '${checkInUtc.month.toString().padLeft(2, '0')}-'
          '${checkInUtc.day.toString().padLeft(2, '0')} '
          '${checkInUtc.hour.toString().padLeft(2, '0')}:'
          '${checkInUtc.minute.toString().padLeft(2, '0')}:'
          '${checkInUtc.second.toString().padLeft(2, '0')}';

      // Create attendance data starting with required fields
      final Map<String, dynamic> attendanceData = {
        'employee_id': employeeId,
        'check_in': checkInFormatted,
        'entite_id': finalEntiteId,
        'auth_method': authMethodValue, // Always include auth_method
        'type_att':
            'entree', // Type de pointage (punching type): entree = entry, sortie = exit
      };

      // Try adding optional fields (may not exist in all Odoo setups)
      // These are common custom fields that might exist
      attendanceData['in_latitude'] = latitude;
      attendanceData['in_longitude'] = longitude;

      print('Creating attendance with data: $attendanceData');

      final result = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.attendance',
        'create',
        [attendanceData],
      ]);

      print('✓ Punch in created with ID: $result');
      return result != null && result > 0;
    } catch (e) {
      print('✗ Error punching in: $e');
      rethrow;
    }
  }

  // Punch out (Check out)
  Future<bool> punchOut({
    required double latitude,
    required double longitude,
    required DateTime checkOut,
  }) async {
    final syncService = SyncService();

    // Check if offline - queue operation if so
    if (!syncService.isConnected) {
      print('📴 Offline: Queueing punch out for sync');
      await syncService.queueOperation(
        operationType: SyncService.opAttendancePunchOut,
        operationData: {
          'latitude': latitude,
          'longitude': longitude,
          'checkOut': checkOut.toIso8601String(),
        },
      );
      return true; // Return success immediately for offline mode
    }

    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      final employeeId = await getCurrentEmployeeId();

      // Get the last check-in that doesn't have a check-out
      final lastCheckIn = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.attendance',
        'search_read',
        [
          [
            ['employee_id', '=', employeeId],
            ['check_out', '=', false],
          ]
        ],
        {
          'fields': ['id', 'check_in'],
          'order': 'check_in desc',
          'limit': 1,
        }
      ]);

      if (lastCheckIn is List && lastCheckIn.isNotEmpty) {
        final attendanceId = lastCheckIn[0]['id'];

        // Format check-out time in UTC
        final checkOutUtc = checkOut.toUtc(); // Convert to UTC first
        final checkOutFormatted =
            '${checkOutUtc.year.toString().padLeft(4, '0')}-'
            '${checkOutUtc.month.toString().padLeft(2, '0')}-'
            '${checkOutUtc.day.toString().padLeft(2, '0')} '
            '${checkOutUtc.hour.toString().padLeft(2, '0')}:'
            '${checkOutUtc.minute.toString().padLeft(2, '0')}:'
            '${checkOutUtc.second.toString().padLeft(2, '0')}';

        final result = await _callRPC('object', 'execute_kw', [
          database,
          _userId,
          _password,
          'hr.attendance',
          'write',
          [
            [attendanceId],
            {
              'check_out': checkOutFormatted,
              'out_latitude': latitude,
              'out_longitude': longitude,
            }
          ],
        ]);

        print('✅ Punch out updated: $result');
        return result == true;
      } else {
        print('❌ No active check-in found');
        return false;
      }
    } catch (e) {
      print('❌ Error punching out: $e');
      rethrow;
    }
  }

  // Get attendance history for current employee
  Future<List<Map<String, dynamic>>> getAttendanceHistory({
    int limit = 1000, // Increased limit to show all attendance history
  }) async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      final employeeId = await getCurrentEmployeeId();

      final attendanceRecords = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.attendance',
        'search_read',
        [
          [
            ['employee_id', '=', employeeId],
          ]
        ],
        {
          'fields': [
            'id',
            'check_in',
            'check_out',
            'worked_hours',
            'in_latitude',
            'in_longitude',
            'out_latitude',
            'out_longitude',
            'entite_id',
            'auth_method',
            'type_att', // Punching type (entree/sortie)
          ],
          'order': 'check_in desc',
          'limit': limit,
        }
      ]);

      print('Raw attendance records type: ${attendanceRecords.runtimeType}');
      print('Raw attendance records: $attendanceRecords');

      if (attendanceRecords is List) {
        // Filter out non-map items and convert to proper format
        final List<Map<String, dynamic>> validRecords = [];
        for (var item in attendanceRecords) {
          print('Item type: ${item.runtimeType}, item: $item');
          if (item is Map) {
            try {
              validRecords.add(Map<String, dynamic>.from(item));
            } catch (e) {
              print('Error converting item to Map: $e');
            }
          } else {
            print('Skipping non-map item: $item');
          }
        }
        print('Valid records count: ${validRecords.length}');
        return validRecords;
      }
      return [];
    } catch (e) {
      print('Error fetching attendance history: $e');
      return [];
    }
  }

  // Get attendance records for a specific employee
  Future<List<Map<String, dynamic>>> getEmployeeAttendance(int employeeId,
      {bool useCache = true}) async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      // Serve from cache if available and fresh
      if (useCache && _employeeAttendanceCache.containsKey(employeeId)) {
        final cachedAt = _employeeAttendanceCachedAt[employeeId];
        if (cachedAt != null &&
            DateTime.now().difference(cachedAt) < _defaultCacheTtl) {
          return _employeeAttendanceCache[employeeId]!;
        }
      }

      final attendanceRecords = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.attendance',
        'search_read',
        [
          [
            ['employee_id', '=', employeeId],
          ]
        ],
        {
          'fields': [
            'id',
            'check_in',
            'check_out',
            'worked_hours',
          ],
          'order': 'check_in desc',
          'limit': 100,
        }
      ]);

      print('Raw employee attendance type: ${attendanceRecords.runtimeType}');

      if (attendanceRecords is List) {
        // Filter out non-map items and convert to proper format
        final List<Map<String, dynamic>> validRecords = [];
        for (var item in attendanceRecords) {
          print('Item type: ${item.runtimeType}, item: $item');
          if (item is Map) {
            try {
              validRecords.add(Map<String, dynamic>.from(item));
            } catch (e) {
              print('Error converting item to Map: $e');
            }
          } else {
            print('Skipping non-map item: $item');
          }
        }
        print('Valid records count: ${validRecords.length}');
        // cache
        _employeeAttendanceCache[employeeId] = validRecords;
        _employeeAttendanceCachedAt[employeeId] = DateTime.now();
        return validRecords;
      }
      return [];
    } catch (e) {
      print('Error fetching employee attendance: $e');
      return [];
    }
  }

  // Get notifications sent by the current HR user
  Future<List<Map<String, dynamic>>> getSentNotifications() async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      print('Fetching sent notifications for current user: $_userId');

      // Fetch mail.message records created by the current logged-in user
      // Uses the same module and logic as sendNotificationToEmployee()
      // The author_id is automatically set to the user making the RPC call (_userId)

      // Fetch mail.message records created by the current logged-in user
      // Use search then read (same pattern as other methods) to avoid XML-RPC format issues
      // Don't filter by model - get all notifications sent by this user
      final messageIds = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'mail.message',
        'search',
        [
          [
            ['author_id', '=', _userId],
            ['message_type', '=', 'notification'],
          ]
        ],
        {
          'order': 'create_date desc, id desc',
          'limit': 0, // 0 means no limit - get all notifications
        }
      ]);

      print(
          '📊 Found ${messageIds is List ? messageIds.length : 0} message IDs');

      if (messageIds is List && messageIds.isNotEmpty) {
        // Read full message data for all IDs
        final sentMessages = await _callRPC('object', 'execute_kw', [
          database,
          _userId,
          _password,
          'mail.message',
          'read',
          [messageIds],
          {
            'fields': [
              'id',
              'subject',
              'body',
              'create_date',
              'partner_ids',
              'author_id',
              'model',
            ],
          }
        ]);

        print(
            '📦 Read ${sentMessages is List ? sentMessages.length : 0} message records');

        if (sentMessages is List) {
          final List<Map<String, dynamic>> validMessages = [];

          // Process each message record
          for (var item in sentMessages) {
            if (item is Map) {
              try {
                final message = Map<String, dynamic>.from(item);

                // Convert false values to null for string fields to prevent type errors
                // Odoo returns false for empty fields, but we need strings or null
                if (message.containsKey('subject') &&
                    message['subject'] == false) {
                  message['subject'] = null;
                }
                if (message.containsKey('body') && message['body'] == false) {
                  message['body'] = null;
                }
                if (message.containsKey('create_date') &&
                    message['create_date'] == false) {
                  message['create_date'] = null;
                }
                if (message.containsKey('model') && message['model'] == false) {
                  message['model'] = null;
                }
                if (message.containsKey('author_id') &&
                    message['author_id'] == false) {
                  message['author_id'] = null;
                }

                // Include all complete records (have id and subject)
                if (message.containsKey('id') &&
                    message.containsKey('subject')) {
                  validMessages.add(message);
                }
              } catch (e) {
                print('⚠️ Error converting message: $e');
              }
            }
          }

          print(
              '✅ Extracted ${validMessages.length} complete notification records');

          // Sort by create_date descending to ensure most recent first
          // If dates are equal, sort by ID descending (newest ID = most recent)
          validMessages.sort((a, b) {
            final dateA = a['create_date']?.toString() ?? '';
            final dateB = b['create_date']?.toString() ?? '';

            // First compare by date
            final dateCompare = dateB.compareTo(dateA);
            if (dateCompare != 0) {
              return dateCompare;
            }

            // If dates are equal, sort by ID (newest ID first)
            final idA = a['id'] ?? 0;
            final idB = b['id'] ?? 0;
            if (idA is int && idB is int) {
              return idB.compareTo(idA);
            }
            return dateCompare;
          });

          print('📊 Final result: ${validMessages.length} notifications');
          if (validMessages.isNotEmpty) {
            print(
                '📅 Most recent notification: ID ${validMessages.first['id']}, Date: ${validMessages.first['create_date']}, Subject: ${validMessages.first['subject']}');
            print(
                '📅 Oldest notification: ID ${validMessages.last['id']}, Date: ${validMessages.last['create_date']}, Subject: ${validMessages.last['subject']}');
          }
          return validMessages;
        }
      }

      return [];
    } catch (e) {
      print('Error fetching sent notifications: $e');
      return [];
    }
  }

  // Get partner names from partner IDs
  Future<Map<int, String>> getPartnerNames(List<int> partnerIds) async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    if (partnerIds.isEmpty) {
      return {};
    }

    try {
      final partners = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'res.partner',
        'read',
        [partnerIds],
        {
          'fields': ['name']
        }
      ]);

      final Map<int, String> namesMap = {};
      if (partners is List) {
        for (var partner in partners) {
          if (partner is Map) {
            final id = partner['id'] as int?;
            final name = partner['name']?.toString() ?? 'Inconnu';
            if (id != null) {
              namesMap[id] = name;
            }
          }
        }
      }
      return namesMap;
    } catch (e) {
      print('Error fetching partner names: $e');
      return {};
    }
  }

  // Get expense reports for the current employee
  Future<List<Map<String, dynamic>>> getEmployeeExpenses() async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      final employeeId = await getCurrentEmployeeId();
      print('Fetching expenses for employee: $employeeId');

      final expenses = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.expense',
        'search_read',
        [
          [
            ['employee_id', '=', employeeId],
          ]
        ],
        {
          'fields': [
            'id',
            'name',
            'date',
            'employee_id',
            'payment_mode',
            'total_amount',
            'state',
            'currency_id',
            'product_id',
            'product_uom_id',
            'quantity',
            'price_unit',
            'tax_amount',
            'description',
            'sheet_id',
            'company_id',
            'create_date',
            'write_date',
          ],
          'order': 'date desc, create_date desc',
          'limit': 100,
        }
      ]);

      print('Found ${expenses is List ? expenses.length : 0} expense records');

      if (expenses is List) {
        final List<Map<String, dynamic>> validExpenses = [];
        for (var item in expenses) {
          if (item is Map) {
            try {
              validExpenses.add(Map<String, dynamic>.from(item));
            } catch (e) {
              print('Error converting expense to Map: $e');
            }
          }
        }
        return validExpenses;
      }
      return [];
    } catch (e) {
      print('Error fetching employee expenses: $e');
      return [];
    }
  }

  // Get expense categories (products that can be expensed)
  Future<List<Map<String, dynamic>>> getExpenseCategories() async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      final categories = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'product.product',
        'search_read',
        [
          [
            ['can_be_expensed', '=', true],
          ]
        ],
        {
          'fields': ['id', 'name', 'default_code'],
          'order': 'name asc',
          'limit': 100,
          'context': {'lang': 'fr_FR'}, // Request French translations
        }
      ]);

      print(
          'Found ${categories is List ? categories.length : 0} expense categories');

      if (categories is List) {
        final List<Map<String, dynamic>> validCategories = [];
        for (var item in categories) {
          if (item is Map) {
            try {
              validCategories.add(Map<String, dynamic>.from(item));
            } catch (e) {
              print('Error converting category to Map: $e');
            }
          }
        }
        return validCategories;
      }
      return [];
    } catch (e) {
      print('Error fetching expense categories: $e');
      return [];
    }
  }

  // Create a new expense report
  Future<int> createExpense({
    required String name,
    required double totalAmount,
    required DateTime date,
    required String paymentMode,
    required int? productId, // Category/Product ID
    String? description,
  }) async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      final employeeId = await getCurrentEmployeeId();
      print('Creating expense for employee: $employeeId');

      // Format date for Odoo (YYYY-MM-DD)
      final formattedDate = date.toIso8601String().split('T')[0];

      // Create expense data
      final expenseData = {
        'name': name,
        'employee_id': employeeId,
        'date': formattedDate,
        'total_amount': totalAmount,
        'payment_mode': paymentMode,
        'product_id': productId ?? false,
        'description': description?.isNotEmpty == true ? description : false,
        'state': 'draft', // Start as draft
      };

      print('Expense data: $expenseData');

      // Create expense in Odoo
      final result = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.expense',
        'create',
        [expenseData],
        {},
      ]);

      print('✅ Expense created with ID: $result');
      return result is int ? result : result as int;
    } catch (e) {
      print('❌ Error creating expense: $e');
      rethrow;
    }
  }

  // Delete an expense report
  Future<bool> deleteExpense(int expenseId) async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      print('Deleting expense with ID: $expenseId');

      // Delete expense in Odoo
      final result = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.expense',
        'unlink',
        [
          [expenseId]
        ],
      ]);

      print('✅ Expense deleted: $result');
      return result == true;
    } catch (e) {
      print('❌ Error deleting expense: $e');
      rethrow;
    }
  }

  // Upload a file attachment to Odoo
  Future<int> uploadAttachment({
    required String filename,
    required List<int> fileBytes,
    required String resModel,
    required int resId,
    String? mimetype,
  }) async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
      // Convert file bytes to base64
      final base64Content = base64Encode(fileBytes);

      // Detect MIME type if not provided
      final detectedMimetype = mimetype ?? _detectMimeType(filename);

      // Create attachment data
      final attachmentData = {
        'name': filename,
        'type': 'binary',
        'datas': base64Content,
        'res_model': resModel,
        'res_id': resId,
        'mimetype': detectedMimetype,
      };

      print('Uploading attachment: $filename (${fileBytes.length} bytes)');

      // Create attachment in Odoo
      final result = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'ir.attachment',
        'create',
        [attachmentData],
        {},
      ]);

      print('✅ Attachment uploaded with ID: $result');
      return result is int ? result : result as int;
    } catch (e) {
      print('❌ Error uploading attachment: $e');
      rethrow;
    }
  }

  // Detect MIME type from filename
  String _detectMimeType(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }
}
