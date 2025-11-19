import 'offline_odoo_service.dart';
import 'offline_data_service.dart';
import 'odoo_service.dart';

/// Manages background synchronization of all data when connection is restored
class DataSyncManager {
  static final DataSyncManager _instance = DataSyncManager._internal();
  factory DataSyncManager() => _instance;
  DataSyncManager._internal();

  final OfflineOdooService _offlineOdooService = OfflineOdooService();
  final OfflineDataService _offlineData = OfflineDataService();
  final OdooService _odooService = OdooService();
  bool _isSyncing = false;

  /// Sync all critical data when connection is restored
  Future<void> syncAllData() async {
    if (_isSyncing) {
      print('⏳ Data sync already in progress, skipping...');
      return;
    }

    _isSyncing = true;
    print('🔄 Starting full data sync...');

    try {
      // Get employee ID first (needed for employee-specific data)
      try {
        await _odooService.getCurrentEmployeeId();
      } catch (e) {
        print('⚠️ Could not get employee ID: $e');
        _isSyncing = false;
        return;
      }

      // Sync user and employee data
      try {
        await _offlineOdooService.getUserInfo(forceRefresh: true);
        await _offlineOdooService.getEmployeeDetails(forceRefresh: true);
        print('✅ Synced user and employee data');
      } catch (e) {
        print('❌ Error syncing user/employee data: $e');
      }

      // Sync leave-related data
      try {
        await _offlineOdooService.getLeaveTypes(forceRefresh: true);
        await _offlineOdooService.getLeaveBalance(forceRefresh: true);
        await _offlineOdooService.getLeaveAllocations(forceRefresh: true);
        await _offlineOdooService.getLeaveRequests(forceRefresh: true);
        print('✅ Synced leave data');
      } catch (e) {
        print('❌ Error syncing leave data: $e');
      }

      // Sync attendance data
      try {
        await _offlineOdooService.getAttendanceHistory(forceRefresh: true);
        await _offlineOdooService.getLastAttendance(forceRefresh: true);
        await _offlineOdooService.getPunchingEntities(forceRefresh: true);
        print('✅ Synced attendance data');
      } catch (e) {
        print('❌ Error syncing attendance data: $e');
      }

      // Sync team/management data (if user is manager/HR)
      try {
        await _offlineOdooService.getTeamStatistics(forceRefresh: true);
        await _offlineOdooService.getTeamMembers(forceRefresh: true);
        await _offlineOdooService.getDirectReports(forceRefresh: true);
        await _offlineOdooService.getAllEmployeesUnderManagement(forceRefresh: true);
        await _offlineOdooService.getPendingTeamLeaveRequests(forceRefresh: true);
        print('✅ Synced team/management data');
      } catch (e) {
        print('❌ Error syncing team data: $e');
      }

      // Sync tasks
      try {
        await _offlineOdooService.getEmployeeTasks(forceRefresh: true);
        await _offlineOdooService.getManagerTasks(forceRefresh: true);
        print('✅ Synced tasks data');
      } catch (e) {
        print('❌ Error syncing tasks data: $e');
      }

      // Sync notifications
      try {
        await _offlineOdooService.getUnreadNotifications(forceRefresh: true);
        print('✅ Synced notifications');
      } catch (e) {
        print('❌ Error syncing notifications: $e');
      }

      // Sync documents and expenses
      try {
        await _offlineOdooService.getEmployeeDocuments(forceRefresh: true);
        await _offlineOdooService.getEmployeeExpenses(forceRefresh: true);
        await _offlineOdooService.getExpenseCategories(forceRefresh: true);
        print('✅ Synced documents and expenses');
      } catch (e) {
        print('❌ Error syncing documents/expenses: $e');
      }

      // Update last sync timestamp
      await _offlineData.updateLastSyncTimestamp();
      print('✅ Full data sync completed successfully');
    } catch (e) {
      print('❌ Error during full data sync: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync specific data types (for targeted refresh)
  Future<void> syncLeaveData() async {
    try {
      await _offlineOdooService.getLeaveTypes(forceRefresh: true);
      await _offlineOdooService.getLeaveBalance(forceRefresh: true);
      await _offlineOdooService.getLeaveAllocations(forceRefresh: true);
      await _offlineOdooService.getLeaveRequests(forceRefresh: true);
      print('✅ Synced leave data');
    } catch (e) {
      print('❌ Error syncing leave data: $e');
    }
  }

  Future<void> syncAttendanceData() async {
    try {
      await _offlineOdooService.getAttendanceHistory(forceRefresh: true);
      await _offlineOdooService.getLastAttendance(forceRefresh: true);
      print('✅ Synced attendance data');
    } catch (e) {
      print('❌ Error syncing attendance data: $e');
    }
  }

  Future<void> syncTeamData() async {
    try {
      await _offlineOdooService.getTeamStatistics(forceRefresh: true);
      await _offlineOdooService.getTeamMembers(forceRefresh: true);
      await _offlineOdooService.getPendingTeamLeaveRequests(forceRefresh: true);
      print('✅ Synced team data');
    } catch (e) {
      print('❌ Error syncing team data: $e');
    }
  }

  /// Check if sync is in progress
  bool get isSyncing => _isSyncing;
}

