import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Service to manage offline data storage and retrieval
/// Caches all read data locally so the app works completely offline
class OfflineDataService {
  static final OfflineDataService _instance = OfflineDataService._internal();
  factory OfflineDataService() => _instance;
  OfflineDataService._internal();

  static const String _boxName = 'offline_data';
  Box? _box;
  bool _isInitialized = false;

  // Cache keys (public for use in other services)
  static const String keyUserInfo = 'user_info';
  static const String keyEmployeeDetails = 'employee_details';
  static const String keyDirectReports = 'direct_reports';
  static const String keyTeamMembers = 'team_members';
  static const String keyPendingLeaves = 'pending_leaves';
  static const String keyLeaveTypes = 'leave_types';
  static const String keyLeaveRequests = 'leave_requests';
  static const String keyLeaveBalance = 'leave_balance';
  static const String keyLeaveAllocations = 'leave_allocations';
  static const String keyAttendanceHistory = 'attendance_history';
  static const String keyLastAttendance = 'last_attendance';
  static const String keyTeamStats = 'team_stats';
  static const String keyPunchingEntities = 'punching_entities';
  static const String keyAllManagedEmployees = 'all_managed_employees';
  static const String keyNotifications = 'notifications';
  static const String keyUnreadNotifications = 'unread_notifications';
  static const String keyTasks = 'tasks';
  static const String keyEmployeeTasks = 'employee_tasks';
  static const String keyManagerTasks = 'manager_tasks';
  static const String keyEmployeeDocuments = 'employee_documents';
  static const String keyEmployeeExpenses = 'employee_expenses';
  static const String keyExpenseCategories = 'expense_categories';
  static const String keyLastSync = 'last_sync_timestamp';

  // Private keys for internal use
  static const String _keyUserInfo = keyUserInfo;
  static const String _keyEmployeeDetails = keyEmployeeDetails;
  static const String _keyDirectReports = keyDirectReports;
  static const String _keyTeamMembers = keyTeamMembers;
  static const String _keyPendingLeaves = keyPendingLeaves;
  static const String _keyLeaveTypes = keyLeaveTypes;
  static const String _keyLeaveRequests = keyLeaveRequests;
  static const String _keyLeaveBalance = keyLeaveBalance;
  static const String _keyLeaveAllocations = keyLeaveAllocations;
  static const String _keyAttendanceHistory = keyAttendanceHistory;
  static const String _keyLastAttendance = keyLastAttendance;
  static const String _keyTeamStats = keyTeamStats;
  static const String _keyPunchingEntities = keyPunchingEntities;
  static const String _keyAllManagedEmployees = keyAllManagedEmployees;
  static const String _keyNotifications = keyNotifications;
  static const String _keyUnreadNotifications = keyUnreadNotifications;
  static const String _keyTasks = keyTasks;
  static const String _keyEmployeeTasks = keyEmployeeTasks;
  static const String _keyManagerTasks = keyManagerTasks;
  static const String _keyEmployeeDocuments = keyEmployeeDocuments;
  static const String _keyEmployeeExpenses = keyEmployeeExpenses;
  static const String _keyExpenseCategories = keyExpenseCategories;
  static const String _keyLastSync = keyLastSync;

  /// Initialize Hive and open the box
  Future<void> initialize() async {
    if (_isInitialized) return;

    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    _isInitialized = true;
    print('✅ OfflineDataService initialized');
  }

  /// Check if we have cached data for a key
  bool hasCachedData(String key) {
    if (_box == null) return false;
    return _box!.containsKey(key);
  }

  /// Get cached data
  T? getCachedData<T>(String key) {
    if (_box == null) return null;
    try {
      final data = _box!.get(key);
      if (data == null) return null;
      
      // If T is a List or Map, decode from JSON string
      final isListType = T.toString().startsWith('List<');
      final isMapType = T.toString().startsWith('Map<');
      if (isListType || isMapType) {
        if (data is String) {
          return jsonDecode(data) as T;
        }
        // If already decoded, return as is
        return data as T;
      }
      return data as T;
    } catch (e) {
      print('❌ Error getting cached data for $key: $e');
      return null;
    }
  }

  /// Save data to cache
  Future<void> saveData<T>(String key, T data) async {
    if (_box == null) await initialize();
    
    try {
      // Convert complex types to JSON string
      if (data is List || data is Map) {
        await _box!.put(key, jsonEncode(data));
      } else {
        await _box!.put(key, data);
      }
      print('💾 Saved data to cache: $key');
    } catch (e) {
      print('❌ Error saving data for $key: $e');
    }
  }

  /// Save with timestamp
  Future<void> saveDataWithTimestamp(String key, dynamic data) async {
    await saveData(key, data);
    await saveData('${key}_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  /// Check if cached data is still valid (not older than maxAge)
  bool isCacheValid(String key, {Duration maxAge = const Duration(hours: 24)}) {
    if (!hasCachedData(key)) return false;
    
    final timestamp = getCachedData<int>('${key}_timestamp');
    if (timestamp == null) return true; // If no timestamp, assume valid
    
    final cacheAge = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(timestamp)
    );
    return cacheAge < maxAge;
  }

  /// User Info
  Future<void> saveUserInfo(Map<String, dynamic> userInfo) async {
    await saveDataWithTimestamp(_keyUserInfo, userInfo);
  }

  Map<String, dynamic>? getUserInfo() {
    return getCachedData<Map<String, dynamic>>(_keyUserInfo);
  }

  /// Employee Details
  Future<void> saveEmployeeDetails(Map<String, dynamic> details) async {
    await saveDataWithTimestamp(_keyEmployeeDetails, details);
  }

  Map<String, dynamic>? getEmployeeDetails() {
    return getCachedData<Map<String, dynamic>>(_keyEmployeeDetails);
  }

  /// Direct Reports
  Future<void> saveDirectReports(List<Map<String, dynamic>> reports) async {
    await saveDataWithTimestamp(_keyDirectReports, reports);
  }

  List<Map<String, dynamic>>? getDirectReports() {
    return getCachedData<List<Map<String, dynamic>>>(_keyDirectReports);
  }

  /// Team Members
  Future<void> saveTeamMembers(List<Map<String, dynamic>> members) async {
    await saveDataWithTimestamp(_keyTeamMembers, members);
  }

  List<Map<String, dynamic>>? getTeamMembers() {
    return getCachedData<List<Map<String, dynamic>>>(_keyTeamMembers);
  }

  /// Leave Requests
  Future<void> saveLeaveRequests(List<Map<String, dynamic>> requests) async {
    await saveDataWithTimestamp(_keyLeaveRequests, requests);
  }

  List<Map<String, dynamic>>? getLeaveRequests() {
    return getCachedData<List<Map<String, dynamic>>>(_keyLeaveRequests);
  }

  /// Leave Balance
  Future<void> saveLeaveBalance(Map<String, dynamic> balance) async {
    await saveDataWithTimestamp(_keyLeaveBalance, balance);
  }

  Map<String, dynamic>? getLeaveBalance() {
    return getCachedData<Map<String, dynamic>>(_keyLeaveBalance);
  }

  /// Leave Allocations
  Future<void> saveLeaveAllocations(List<Map<String, dynamic>> allocations) async {
    await saveDataWithTimestamp(_keyLeaveAllocations, allocations);
  }

  List<Map<String, dynamic>>? getLeaveAllocations() {
    return getCachedData<List<Map<String, dynamic>>>(_keyLeaveAllocations);
  }

  /// Leave Types
  Future<void> saveLeaveTypes(List<Map<String, dynamic>> types) async {
    await saveDataWithTimestamp(_keyLeaveTypes, types);
  }

  List<Map<String, dynamic>>? getLeaveTypes() {
    return getCachedData<List<Map<String, dynamic>>>(_keyLeaveTypes);
  }

  /// Attendance History
  Future<void> saveAttendanceHistory(int employeeId, List<Map<String, dynamic>> history) async {
    await saveDataWithTimestamp('${_keyAttendanceHistory}_$employeeId', history);
  }

  List<Map<String, dynamic>>? getAttendanceHistory(int employeeId) {
    return getCachedData<List<Map<String, dynamic>>>('${_keyAttendanceHistory}_$employeeId');
  }

  /// Last Attendance
  Future<void> saveLastAttendance(Map<String, dynamic>? attendance) async {
    if (attendance != null) {
      await saveDataWithTimestamp(_keyLastAttendance, attendance);
    } else {
      await _box?.delete(_keyLastAttendance);
    }
  }

  Map<String, dynamic>? getLastAttendance() {
    return getCachedData<Map<String, dynamic>>(_keyLastAttendance);
  }

  /// Team Stats
  Future<void> saveTeamStats(Map<String, dynamic> stats) async {
    await saveDataWithTimestamp(_keyTeamStats, stats);
  }

  Map<String, dynamic>? getTeamStats() {
    return getCachedData<Map<String, dynamic>>(_keyTeamStats);
  }

  /// Pending Leaves
  Future<void> savePendingLeaves(List<Map<String, dynamic>> leaves) async {
    await saveDataWithTimestamp(_keyPendingLeaves, leaves);
  }

  List<Map<String, dynamic>>? getPendingLeaves() {
    return getCachedData<List<Map<String, dynamic>>>(_keyPendingLeaves);
  }

  /// Punching Entities
  Future<void> savePunchingEntities(List<Map<String, dynamic>> entities) async {
    await saveDataWithTimestamp(_keyPunchingEntities, entities);
  }

  List<Map<String, dynamic>>? getPunchingEntities() {
    return getCachedData<List<Map<String, dynamic>>>(_keyPunchingEntities);
  }

  /// All Managed Employees
  Future<void> saveAllManagedEmployees(List<Map<String, dynamic>> employees) async {
    await saveDataWithTimestamp(_keyAllManagedEmployees, employees);
  }

  List<Map<String, dynamic>>? getAllManagedEmployees() {
    return getCachedData<List<Map<String, dynamic>>>(_keyAllManagedEmployees);
  }

  /// Notifications
  Future<void> saveNotifications(List<Map<String, dynamic>> notifications) async {
    await saveDataWithTimestamp(_keyNotifications, notifications);
  }

  List<Map<String, dynamic>>? getNotifications() {
    return getCachedData<List<Map<String, dynamic>>>(_keyNotifications);
  }

  /// Unread Notifications
  Future<void> saveUnreadNotifications(List<Map<String, dynamic>> notifications) async {
    await saveDataWithTimestamp(_keyUnreadNotifications, notifications);
  }

  List<Map<String, dynamic>>? getUnreadNotifications() {
    return getCachedData<List<Map<String, dynamic>>>(_keyUnreadNotifications);
  }

  /// Tasks
  Future<void> saveTasks(int employeeId, List<Map<String, dynamic>> tasks) async {
    await saveDataWithTimestamp('${_keyTasks}_$employeeId', tasks);
  }

  List<Map<String, dynamic>>? getTasks(int employeeId) {
    return getCachedData<List<Map<String, dynamic>>>('${_keyTasks}_$employeeId');
  }

  /// Employee Tasks
  Future<void> saveEmployeeTasks(List<Map<String, dynamic>> tasks) async {
    await saveDataWithTimestamp(_keyEmployeeTasks, tasks);
  }

  List<Map<String, dynamic>>? getEmployeeTasks() {
    return getCachedData<List<Map<String, dynamic>>>(_keyEmployeeTasks);
  }

  /// Manager Tasks
  Future<void> saveManagerTasks(List<Map<String, dynamic>> tasks) async {
    await saveDataWithTimestamp(_keyManagerTasks, tasks);
  }

  List<Map<String, dynamic>>? getManagerTasks() {
    return getCachedData<List<Map<String, dynamic>>>(_keyManagerTasks);
  }

  /// Employee Documents
  Future<void> saveEmployeeDocuments(List<Map<String, dynamic>> documents) async {
    await saveDataWithTimestamp(_keyEmployeeDocuments, documents);
  }

  List<Map<String, dynamic>>? getEmployeeDocuments() {
    return getCachedData<List<Map<String, dynamic>>>(_keyEmployeeDocuments);
  }

  /// Employee Expenses
  Future<void> saveEmployeeExpenses(List<Map<String, dynamic>> expenses) async {
    await saveDataWithTimestamp(_keyEmployeeExpenses, expenses);
  }

  List<Map<String, dynamic>>? getEmployeeExpenses() {
    return getCachedData<List<Map<String, dynamic>>>(_keyEmployeeExpenses);
  }

  /// Expense Categories
  Future<void> saveExpenseCategories(List<Map<String, dynamic>> categories) async {
    await saveDataWithTimestamp(_keyExpenseCategories, categories);
  }

  List<Map<String, dynamic>>? getExpenseCategories() {
    return getCachedData<List<Map<String, dynamic>>>(_keyExpenseCategories);
  }

  /// Clear all cached data
  Future<void> clearAll() async {
    if (_box == null) return;
    await _box!.clear();
    print('🗑️ Cleared all offline data');
  }

  /// Clear specific key
  Future<void> clearKey(String key) async {
    if (_box == null) return;
    await _box!.delete(key);
    await _box!.delete('${key}_timestamp');
  }

  /// Get last sync timestamp
  int? getLastSyncTimestamp() {
    return getCachedData<int>(_keyLastSync);
  }

  /// Update last sync timestamp
  Future<void> updateLastSyncTimestamp() async {
    await saveData(_keyLastSync, DateTime.now().millisecondsSinceEpoch);
  }
}

