import 'package:flutter/material.dart';
import '../../services/offline_odoo_service.dart';

class DashboardProvider extends ChangeNotifier {
  final OfflineOdooService _offlineOdooService = OfflineOdooService();
  Map<String, dynamic>? _teamStats;
  bool _isLoading = false;
  DateTime? _lastFetchTime;
  static const Duration _cacheExpiration =
      Duration(minutes: 5); // Cache for 5 minutes

  Map<String, dynamic>? get teamStats => _teamStats;
  bool get isLoading => _isLoading;
  bool get hasData => _teamStats != null;
  bool get isCacheValid =>
      _lastFetchTime != null &&
      DateTime.now().difference(_lastFetchTime!) < _cacheExpiration;

  Future<void> loadTeamData({bool forceRefresh = false}) async {
    if (!forceRefresh && hasData && isCacheValid) {
      print('Using cached team data');
      return;
    }

    final bool showLoader = !hasData || forceRefresh;
    if (showLoader) {
      _isLoading = true;
      notifyListeners();
    } else {
      print('Refreshing team data in background without loader');
    }

    try {
      final stats = await _offlineOdooService.getTeamStatistics(
        forceRefresh: forceRefresh || !isCacheValid || !hasData,
      );
      _teamStats = stats;
      _lastFetchTime = DateTime.now();
    } catch (e) {
      print('Error loading team data: $e');
    } finally {
      if (showLoader) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> refreshData() async {
    await loadTeamData(forceRefresh: true);
  }

  void clearCache() {
    _teamStats = null;
    _lastFetchTime = null;
    notifyListeners();
  }

  // Method to update data after approval/rejection
  Future<void> updateAfterAction() async {
    // Force refresh after approval/rejection to get updated data
    await loadTeamData(forceRefresh: true);
  }
}
