import 'package:flutter/material.dart';
import '../../services/offline_odoo_service.dart';

class LeaveProvider extends ChangeNotifier {
  final OfflineOdooService _offlineOdooService = OfflineOdooService();

  Map<String, dynamic>? _leaveBalance;
  List<Map<String, dynamic>>? _leaveRequests;
  List<Map<String, dynamic>>? _leaveTypes;
  List<DateTime>? _holidays;
  bool _isLoading = false;
  String? _error;

  // Getters
  Map<String, dynamic>? get leaveBalance => _leaveBalance;
  List<Map<String, dynamic>>? get leaveRequests => _leaveRequests;
  List<Map<String, dynamic>>? get leaveTypes => _leaveTypes;
  List<DateTime>? get holidays => _holidays;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load leave balance
  Future<void> loadLeaveBalance() async {
    _setLoading(true);
    _clearError();

    try {
      _leaveBalance = await _offlineOdooService.getLeaveBalance();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load leave balance: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Load leave requests
  Future<void> loadLeaveRequests() async {
    // Don't set loading to true to avoid blocking UI when loading alongside balance
    _clearError();

    try {
      _leaveRequests = await _offlineOdooService.getLeaveRequests();
      notifyListeners();
    } catch (e) {
      print('Error loading leave requests: $e');
      // Don't set error here to avoid blocking UI
    }
  }

  // NEW: Load all employees' approved leaves for calendar
  List<Map<String, dynamic>>? _approvedLeaves;
  List<Map<String, dynamic>>? get approvedLeaves => _approvedLeaves;

  Future<void> loadApprovedLeaves(int year) async {
    try {
      _approvedLeaves = await _offlineOdooService.odooService.getApprovedLeaves(year);
      notifyListeners();
    } catch (e) {
      print('Error loading approved leaves: $e');
      _setError('Failed to load approved leaves: ${e.toString()}');
    }
  }

  // NEW: Load all employees' pending leaves for calendar
  List<Map<String, dynamic>>? _pendingLeaves;
  List<Map<String, dynamic>>? get pendingLeaves => _pendingLeaves;

  Future<void> loadPendingLeaves(int year) async {
    try {
      _pendingLeaves = await _offlineOdooService.odooService.getPendingLeaves(year);
      notifyListeners();
    } catch (e) {
      print('Error loading pending leaves: $e');
      _setError('Failed to load pending leaves: ${e.toString()}');
    }
  }

  // Placeholder for Moroccan holidays
  List<DateTime>? _moroccanHolidays;
  List<DateTime>? get moroccanHolidays => _moroccanHolidays;

  Future<void> loadMoroccanHolidays(int year) async {
    try {
      _moroccanHolidays = await _offlineOdooService.odooService.getMoroccanHolidays(year);
      notifyListeners();
    } catch (e) {
      print('Error loading Moroccan holidays: $e');
      _setError('Failed to load Moroccan holidays: ${e.toString()}');
    }
  }

  // Load leave types
  Future<void> loadLeaveTypes() async {
    _setLoading(true);
    _clearError();

    try {
      _leaveTypes = await _offlineOdooService.getLeaveTypes();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load leave types: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Load holidays for calendar
  Future<void> loadHolidays(int year) async {
    _setLoading(true);
    _clearError();

    try {
      _holidays = await _offlineOdooService.odooService.getHolidays(year);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load holidays: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Create leave request - UPDATED to use leaveTypeId instead of typeName
  Future<bool> createLeaveRequest({
    required int leaveTypeId, // Changed from String typeName to int leaveTypeId
    required DateTime dateFrom,
    required DateTime dateTo,
    String? reason,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final leaveId = await _offlineOdooService.createLeaveRequest(
        leaveTypeId: leaveTypeId, // Changed from typeName to leaveTypeId
        dateFrom: dateFrom,
        dateTo: dateTo,
        reason: reason,
      );

      if (leaveId > 0) {
        // Reload data after successful creation
        await loadLeaveRequests();
        await loadLeaveBalance();
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to create leave request: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Check if date is eligible
  Future<bool> isDateEligible(DateTime date) async {
    try {
      return await _offlineOdooService.odooService.isDateEligible(date);
    } catch (e) {
      _setError('Failed to check date eligibility: ${e.toString()}');
      return false;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
