import 'package:connectivity_plus/connectivity_plus.dart';
import 'odoo_service.dart';
import 'offline_data_service.dart';

/// Wrapper around OdooService that implements offline-first pattern
/// Always checks local cache first, then syncs with backend when online
class OfflineOdooService {
  final OdooService _odooService = OdooService();
  final OfflineDataService _offlineData = OfflineDataService();
  final Connectivity _connectivity = Connectivity();

  /// Check if device is online
  Future<bool> get isOnline async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Get employee details (offline-first)
  Future<Map<String, dynamic>> getEmployeeDetails(
      {bool forceRefresh = false}) async {
    // Check cache first if not forcing refresh
    if (!forceRefresh) {
      final cached = _offlineData.getEmployeeDetails();
      if (cached != null && _offlineData.isCacheValid('employee_details')) {
        print('📱 Using cached employee details');
        return cached;
      }
    }

    // Try to fetch from backend if online
    if (await isOnline) {
      try {
        final data = await _odooService.getEmployeeDetails();
        await _offlineData.saveEmployeeDetails(data);
        return data;
      } catch (e) {
        print('❌ Error fetching employee details: $e');
        // Fallback to cache even if expired
        final cached = _offlineData.getEmployeeDetails();
        if (cached != null) {
          print('📱 Using expired cache as fallback');
          return cached;
        }
        rethrow;
      }
    } else {
      // Offline: use cache even if expired
      final cached = _offlineData.getEmployeeDetails();
      if (cached != null) {
        print('📱 Offline: Using cached employee details');
        return cached;
      }
      throw Exception('No internet connection and no cached data available');
    }
  }

  /// Get user info (offline-first)
  Future<Map<String, dynamic>> getUserInfo({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _offlineData.getUserInfo();
      if (cached != null && _offlineData.isCacheValid('user_info')) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data = await _odooService.getUserInfo();
        await _offlineData.saveUserInfo(data);
        return data;
      } catch (e) {
        final cached = _offlineData.getUserInfo();
        if (cached != null) return cached;
        rethrow;
      }
    } else {
      final cached = _offlineData.getUserInfo();
      if (cached != null) return cached;
      throw Exception('No internet connection and no cached data available');
    }
  }

  /// Get current employee ID
  Future<int> getCurrentEmployeeId() async {
    return await _odooService.getCurrentEmployeeId();
  }

  /// Get direct reports (offline-first)
  Future<List<Map<String, dynamic>>> getDirectReports(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _offlineData.getDirectReports();
      if (cached != null && _offlineData.isCacheValid('direct_reports')) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data = await _odooService.getDirectReports();
        await _offlineData.saveDirectReports(data);
        return data;
      } catch (e) {
        final cached = _offlineData.getDirectReports();
        if (cached != null) return cached;
        rethrow;
      }
    } else {
      final cached = _offlineData.getDirectReports();
      if (cached != null) return cached;
      return [];
    }
  }

  /// Get team members (offline-first)
  Future<List<Map<String, dynamic>>> getTeamMembers(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _offlineData.getTeamMembers();
      if (cached != null && _offlineData.isCacheValid('team_members')) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data = await _odooService.getTeamMembers();
        await _offlineData.saveTeamMembers(data);
        return data;
      } catch (e) {
        final cached = _offlineData.getTeamMembers();
        if (cached != null) return cached;
        rethrow;
      }
    } else {
      final cached = _offlineData.getTeamMembers();
      if (cached != null) return cached;
      return [];
    }
  }

  /// Get leave requests (offline-first)
  Future<List<Map<String, dynamic>>> getLeaveRequests(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _offlineData.getLeaveRequests();
      if (cached != null && _offlineData.isCacheValid('leave_requests')) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data = await _odooService.getLeaveRequests();
        await _offlineData.saveLeaveRequests(data);
        return data;
      } catch (e) {
        final cached = _offlineData.getLeaveRequests();
        if (cached != null) return cached;
        rethrow;
      }
    } else {
      final cached = _offlineData.getLeaveRequests();
      if (cached != null) return cached;
      return [];
    }
  }

  /// Get leave balance (offline-first)
  Future<Map<String, dynamic>> getLeaveBalance(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _offlineData.getLeaveBalance();
      if (cached != null && _offlineData.isCacheValid('leave_balance')) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data = await _odooService.getLeaveBalance();
        await _offlineData.saveLeaveBalance(data);
        return data;
      } catch (e) {
        final cached = _offlineData.getLeaveBalance();
        if (cached != null) return cached;
        rethrow;
      }
    } else {
      final cached = _offlineData.getLeaveBalance();
      if (cached != null) return cached;
      return {};
    }
  }

  /// Get leave allocations (offline-first)
  Future<List<Map<String, dynamic>>> getLeaveAllocations(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _offlineData.getLeaveAllocations();
      if (cached != null && _offlineData.isCacheValid('leave_allocations')) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data = await _odooService.getLeaveAllocations();
        await _offlineData.saveLeaveAllocations(data);
        return data;
      } catch (e) {
        final cached = _offlineData.getLeaveAllocations();
        if (cached != null) return cached;
        rethrow;
      }
    } else {
      final cached = _offlineData.getLeaveAllocations();
      if (cached != null) return cached;
      return [];
    }
  }

  /// Get leave types (offline-first)
  Future<List<Map<String, dynamic>>> getLeaveTypes(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _offlineData.getLeaveTypes();
      if (cached != null && _offlineData.isCacheValid('leave_types')) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data = await _odooService.getLeaveTypes();
        await _offlineData.saveLeaveTypes(data);
        return data;
      } catch (e) {
        final cached = _offlineData.getLeaveTypes();
        if (cached != null) return cached;
        rethrow;
      }
    } else {
      final cached = _offlineData.getLeaveTypes();
      if (cached != null) return cached;
      return [];
    }
  }

  /// Get attendance history (offline-first)
  Future<List<Map<String, dynamic>>> getAttendanceHistory({
    int limit = 1000,
    bool forceRefresh = false,
  }) async {
    final employeeId = await getCurrentEmployeeId();
    final cacheKey = 'attendance_history_$employeeId';

    if (!forceRefresh) {
      final cached = _offlineData.getAttendanceHistory(employeeId);
      if (cached != null && _offlineData.isCacheValid(cacheKey)) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data = await _odooService.getAttendanceHistory(limit: limit);
        await _offlineData.saveAttendanceHistory(employeeId, data);
        return data;
      } catch (e) {
        final cached = _offlineData.getAttendanceHistory(employeeId);
        if (cached != null) return cached;
        rethrow;
      }
    } else {
      final cached = _offlineData.getAttendanceHistory(employeeId);
      if (cached != null) return cached;
      return [];
    }
  }

  /// Get employee attendance (offline-first)
  Future<List<Map<String, dynamic>>> getEmployeeAttendance(
    int employeeId, {
    bool useCache = true,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'attendance_history_$employeeId';

    if (!forceRefresh && useCache && dateFrom == null && dateTo == null) {
      final cached = _offlineData.getAttendanceHistory(employeeId);
      if (cached != null && _offlineData.isCacheValid(cacheKey)) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data = await _odooService.getEmployeeAttendance(
          employeeId,
          useCache: useCache,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );
        await _offlineData.saveAttendanceHistory(employeeId, data);
        return data;
      } catch (e) {
        final cached = _offlineData.getAttendanceHistory(employeeId);
        if (cached != null) return cached;
        rethrow;
      }
    } else {
      final cached = _offlineData.getAttendanceHistory(employeeId);
      if (cached != null) return cached;
      return [];
    }
  }

  /// Get last attendance (offline-first)
  Future<Map<String, dynamic>?> getLastAttendance(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _offlineData.getLastAttendance();
      if (cached != null) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data = await _odooService.getLastAttendance();
        await _offlineData.saveLastAttendance(data);
        return data;
      } catch (e) {
        final cached = _offlineData.getLastAttendance();
        if (cached != null) return cached;
        return null;
      }
    } else {
      return _offlineData.getLastAttendance();
    }
  }

  /// Get team statistics (offline-first)
  Future<Map<String, dynamic>> getTeamStatistics(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _offlineData.getTeamStats();
      if (cached != null && _offlineData.isCacheValid('team_stats')) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data =
            await _odooService.getTeamStatistics(forceRefresh: forceRefresh);
        await _offlineData.saveTeamStats(data);
        return data;
      } catch (e) {
        final cached = _offlineData.getTeamStats();
        if (cached != null) return cached;
        rethrow;
      }
    } else {
      final cached = _offlineData.getTeamStats();
      if (cached != null) return cached;
      return {};
    }
  }

  /// Get punching entities (offline-first)
  Future<List<Map<String, dynamic>>> getPunchingEntities(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _offlineData.getPunchingEntities();
      if (cached != null && _offlineData.isCacheValid('punching_entities')) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data = await _odooService.getPunchingEntities();
        await _offlineData.savePunchingEntities(data);
        return data;
      } catch (e) {
        final cached = _offlineData.getPunchingEntities();
        if (cached != null) return cached;
        rethrow;
      }
    } else {
      final cached = _offlineData.getPunchingEntities();
      if (cached != null) return cached;
      return [];
    }
  }

  /// Get all managed employees (offline-first)
  Future<List<Map<String, dynamic>>> getAllEmployeesUnderManagement(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _offlineData.getAllManagedEmployees();
      if (cached != null &&
          _offlineData.isCacheValid('all_managed_employees')) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data = await _odooService.getAllEmployeesUnderManagement();
        await _offlineData.saveAllManagedEmployees(data);
        return data;
      } catch (e) {
        final cached = _offlineData.getAllManagedEmployees();
        if (cached != null) return cached;
        rethrow;
      }
    } else {
      final cached = _offlineData.getAllManagedEmployees();
      if (cached != null) return cached;
      return [];
    }
  }

  /// Get pending team leave requests (offline-first)
  Future<List<Map<String, dynamic>>> getPendingTeamLeaveRequests(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _offlineData.getPendingLeaves();
      if (cached != null && _offlineData.isCacheValid('pending_leaves')) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data = await _odooService.getPendingTeamLeaveRequests();
        await _offlineData.savePendingLeaves(data);
        return data;
      } catch (e) {
        final cached = _offlineData.getPendingLeaves();
        if (cached != null) return cached;
        rethrow;
      }
    } else {
      final cached = _offlineData.getPendingLeaves();
      if (cached != null) return cached;
      return [];
    }
  }

  /// Get unread notifications (offline-first)
  Future<List<Map<String, dynamic>>> getUnreadNotifications(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _offlineData.getUnreadNotifications();
      if (cached != null && _offlineData.isCacheValid('unread_notifications')) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data = await _odooService.getUnreadNotifications();
        await _offlineData.saveUnreadNotifications(data);
        return data;
      } catch (e) {
        final cached = _offlineData.getUnreadNotifications();
        if (cached != null) return cached;
        rethrow;
      }
    } else {
      final cached = _offlineData.getUnreadNotifications();
      if (cached != null) return cached;
      return [];
    }
  }

  /// Get employee tasks (offline-first)
  Future<List<Map<String, dynamic>>> getEmployeeTasks(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _offlineData.getEmployeeTasks();
      if (cached != null && _offlineData.isCacheValid('employee_tasks')) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data = await _odooService.getEmployeeTasks();
        await _offlineData.saveEmployeeTasks(data);
        return data;
      } catch (e) {
        final cached = _offlineData.getEmployeeTasks();
        if (cached != null) return cached;
        rethrow;
      }
    } else {
      final cached = _offlineData.getEmployeeTasks();
      if (cached != null) return cached;
      return [];
    }
  }

  /// Get manager tasks (offline-first)
  Future<List<Map<String, dynamic>>> getManagerTasks(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _offlineData.getManagerTasks();
      if (cached != null && _offlineData.isCacheValid('manager_tasks')) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data = await _odooService.getManagerTasks();
        await _offlineData.saveManagerTasks(data);
        return data;
      } catch (e) {
        final cached = _offlineData.getManagerTasks();
        if (cached != null) return cached;
        rethrow;
      }
    } else {
      final cached = _offlineData.getManagerTasks();
      if (cached != null) return cached;
      return [];
    }
  }

  /// Get employee documents (offline-first)
  Future<List<Map<String, dynamic>>> getEmployeeDocuments(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _offlineData.getEmployeeDocuments();
      if (cached != null && _offlineData.isCacheValid('employee_documents')) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data = await _odooService.getEmployeeDocuments();
        await _offlineData.saveEmployeeDocuments(data);
        return data;
      } catch (e) {
        final cached = _offlineData.getEmployeeDocuments();
        if (cached != null) return cached;
        rethrow;
      }
    } else {
      final cached = _offlineData.getEmployeeDocuments();
      if (cached != null) return cached;
      return [];
    }
  }

  /// Get employee expenses (offline-first)
  Future<List<Map<String, dynamic>>> getEmployeeExpenses(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _offlineData.getEmployeeExpenses();
      if (cached != null && _offlineData.isCacheValid('employee_expenses')) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data = await _odooService.getEmployeeExpenses();
        await _offlineData.saveEmployeeExpenses(data);
        return data;
      } catch (e) {
        final cached = _offlineData.getEmployeeExpenses();
        if (cached != null) return cached;
        rethrow;
      }
    } else {
      final cached = _offlineData.getEmployeeExpenses();
      if (cached != null) return cached;
      return [];
    }
  }

  /// Get expense categories (offline-first)
  Future<List<Map<String, dynamic>>> getExpenseCategories(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _offlineData.getExpenseCategories();
      if (cached != null && _offlineData.isCacheValid('expense_categories')) {
        return cached;
      }
    }

    if (await isOnline) {
      try {
        final data = await _odooService.getExpenseCategories();
        await _offlineData.saveExpenseCategories(data);
        return data;
      } catch (e) {
        final cached = _offlineData.getExpenseCategories();
        if (cached != null) return cached;
        rethrow;
      }
    } else {
      final cached = _offlineData.getExpenseCategories();
      if (cached != null) return cached;
      return [];
    }
  }

  // ========== Write Operations (delegated to OdooService - they go through SyncService) ==========

  /// Delegate write operations to OdooService (they go through SyncService)
  Future<bool> punchIn({
    required double latitude,
    required double longitude,
    required DateTime checkIn,
    int? entiteId,
  }) async {
    return await _odooService.punchIn(
      latitude: latitude,
      longitude: longitude,
      checkIn: checkIn,
      entiteId: entiteId,
    );
  }

  Future<bool> punchOut({
    required double latitude,
    required double longitude,
    required DateTime checkOut,
  }) async {
    return await _odooService.punchOut(
      latitude: latitude,
      longitude: longitude,
      checkOut: checkOut,
    );
  }

  Future<int> createLeaveRequest({
    required int leaveTypeId,
    required DateTime dateFrom,
    required DateTime dateTo,
    String? reason,
    bool? isHalfDay,
  }) async {
    return await _odooService.createLeaveRequest(
      leaveTypeId: leaveTypeId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      reason: reason,
      isHalfDay: isHalfDay,
    );
  }

  Future<bool> updateTaskStage({
    required int taskId,
    required String newStage,
  }) async {
    return await _odooService.updateTaskStage(
      taskId: taskId,
      newStage: newStage,
    );
  }

  Future<int> createTask({
    required int employeeId,
    required String title,
    required String description,
    required String priority,
    required DateTime dueDate,
    required String assignedByName,
  }) async {
    return await _odooService.createTask(
      employeeId: employeeId,
      title: title,
      description: description,
      priority: priority,
      dueDate: dueDate,
      assignedByName: assignedByName,
    );
  }

  Future<bool> updateEmployeeField(String fieldKey, String newValue) async {
    return await _odooService.updateEmployeeField(fieldKey, newValue);
  }

  Future<bool> updateEmployeePhoto(String base64Image) async {
    return await _odooService.updateEmployeePhoto(base64Image);
  }

  Future<bool> sendNotificationToHR({
    required int employeeId,
    String? fieldName,
    String? fieldLabel,
    String? currentValue,
    String? newValue,
    String? base64Image,
  }) async {
    return await _odooService.sendNotificationToHR(
      employeeId: employeeId,
      fieldName: fieldName ?? '',
      fieldLabel: fieldLabel ?? '',
      currentValue: currentValue ?? '',
      newValue: newValue ?? '',
      base64Image: base64Image,
    );
  }

  // Expose OdooService for methods not yet wrapped
  OdooService get odooService => _odooService;
}
