import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

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

  // Get employee documents/attachments
  Future<List<Map<String, dynamic>>> getEmployeeDocuments() async {
    print('Fetching employee documents...');

    try {
      final employeeId = await getCurrentEmployeeId();
      print('Employee ID: $employeeId');

      // Fetch attachments related to the employee
      final documents = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'ir.attachment',
        'search_read',
        [
          [
            ['res_model', '=', 'hr.employee'],
            ['res_id', '=', employeeId],
          ]
        ],
        {
          'fields': [
            'id',
            'name',
            'datas_fname',
            'mimetype',
            'file_size',
            'create_date',
            'type',
            'description',
          ],
          'order': 'create_date desc',
          'context': {'lang': 'fr_FR'}
        }
      ]);

      print('Found ${documents is List ? documents.length : 0} documents');

      if (documents is List) {
        return documents
            .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      return [];
    } catch (e) {
      print('Error fetching employee documents: $e');
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

  // Get leave balance based on employee's annual entitlement
  Future<Map<String, dynamic>> getLeaveBalance() async {
    print('Loading leave balance...');
    final employeeId = await getCurrentEmployeeId();
    print('Employee ID: $employeeId');

    try {
      // Skip fetching employee data since annual_leave_days field doesn't exist
      print('Using default annual leave entitlements...');

      // Get used leaves
      print('Fetching used leaves...');
      final leaves = await _callRPC('object', 'execute_kw', [
        database,
        _userId,
        _password,
        'hr.leave',
        'search_read',
        [
          [
            ['employee_id', '=', employeeId],
            [
              'state',
              'in',
              ['confirm', 'validate1', 'validate']
            ]
          ]
        ],
        {
          'fields': ['holiday_status_id', 'number_of_days'],
          'limit': 1000,
          'context': {'lang': 'fr_FR'}
        }
      ]);

      print('Leaves response type: ${leaves.runtimeType}');
      print('Leaves count: ${leaves is List ? leaves.length : 0}');
      if (leaves is List && leaves.isNotEmpty) {
        print('First leave: ${leaves.first}');
      }

      // Calculate balance starting from annual entitlement
      Map<String, double> balance = {};

      // Set default annual entitlements
      double annualPaidLeave = 20.0; // Default annual paid leave
      double annualSickLeave = 5.0; // Default annual sick leave

      // Initialize balance with annual entitlements
      balance['Congés payés'] = annualPaidLeave;
      balance['Congé maladie'] = annualSickLeave;

      print(
          'Initial annual entitlement: Paid=$annualPaidLeave, Sick=$annualSickLeave');

      // Subtract used leaves
      if (leaves is List) {
        for (var leave in leaves) {
          if (leave is Map &&
              leave.containsKey('holiday_status_id') &&
              leave.containsKey('number_of_days')) {
            var statusId = leave['holiday_status_id'];
            String typeName;

            if (statusId is List && statusId.length >= 2) {
              typeName = statusId[1].toString();
            } else if (statusId is String) {
              typeName = statusId;
            } else {
              print('Warning: Unknown holiday_status_id format: $statusId');
              continue;
            }

            double days = 0.0;
            var numDays = leave['number_of_days'];
            if (numDays is num) {
              days = numDays.toDouble();
            } else if (numDays is String) {
              days = double.tryParse(numDays) ?? 0.0;
            }

            balance[typeName] = (balance[typeName] ?? 0) - days;
            print('Subtracted leave: $typeName = $days days');
          }
        }
      }

      print('Final balance: $balance');
      return balance;
    } catch (e) {
      print('Error in getLeaveBalance: $e');
      rethrow;
    }
  }

  // Get leave requests
  Future<List<Map<String, dynamic>>> getLeaveRequests() async {
    final employeeId = await getCurrentEmployeeId();

    final requests = await _callRPC('object', 'execute', [
      database,
      _userId,
      _password,
      'hr.leave',
      'search_read',
      [
        ['employee_id', '=', employeeId]
      ],
      [
        'date_from',
        'date_to',
        'holiday_status_id',
        'state',
        'request_date_from',
        'name',
        'employee_id'
      ]
    ]);

    return requests;
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

    if (types.isEmpty) {
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
  }) async {
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

    print('Creating leave request with:');
    print('  Employee ID: $employeeId');
    print('  Leave Type ID: $leaveTypeId');
    print('  Date From (original): $dateFrom');
    print('  Date From (normalized): $normalizedDateFrom');
    print('  Date From (formatted): $formattedDateFrom');
    print('  Date To (original): $dateTo');
    print('  Date To (normalized): $normalizedDateTo');
    print('  Date To (formatted): $formattedDateTo');
    print('  Reason: $reason');

    try {
      final leaveId = await _callRPC('object', 'execute', [
        database,
        _userId,
        _password,
        'hr.leave',
        'create',
        {
          'employee_id': employeeId,
          'holiday_status_id': leaveTypeId,
          'request_date_from':
              formattedDateFrom, // Use request_date_from instead of date_from
          'request_date_to':
              formattedDateTo, // Use request_date_to instead of date_to
          'name': reason ?? 'Demande de congé',
        }
      ]);

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

  // Get approved leaves for calendar display
  Future<List<Map<String, dynamic>>> getApprovedLeaves(int year) async {
    print('Loading approved leaves for year $year...');
    final employeeId = await getCurrentEmployeeId();

    print('Fetching approved employee leave requests...');
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
            ['employee_id', '=', employeeId],
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

      print('Loaded ${leaves.length} approved leaves');
      return leaves;
    } catch (e) {
      print('Error fetching approved leave requests: $e');
      return [];
    }
  }

  // Get pending leaves for calendar display
  Future<List<Map<String, dynamic>>> getPendingLeaves(int year) async {
    print('Loading pending leaves for year $year...');
    final employeeId = await getCurrentEmployeeId();

    print('Fetching pending employee leave requests...');
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
            ['employee_id', '=', employeeId],
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

      print('Loaded ${leaves.length} pending leaves');
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
  Future<List<Map<String, dynamic>>> getDirectReports() async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
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
  Future<List<Map<String, dynamic>>> getAllEmployeesUnderManagement() async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
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

  Future<List<Map<String, dynamic>>> getTeamMembers() async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
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
  Future<List<Map<String, dynamic>>> getPendingTeamLeaveRequests() async {
    if (_userId == null || _password == null) {
      throw Exception('Not authenticated');
    }

    try {
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
          throw Exception('XML-RPC fault: ${faultStruct['faultString']}');
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
}
