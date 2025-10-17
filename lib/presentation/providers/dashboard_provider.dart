import 'package:flutter/material.dart';
import '../../services/odoo_service.dart';

class DashboardProvider extends ChangeNotifier {
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
    // If we have valid cached data and not forcing refresh, don't fetch again
    if (hasData && isCacheValid && !forceRefresh) {
      print('Using cached team data');
      return;
    }

    try {
      _isLoading = true;
      notifyListeners();

      print('Fetching fresh team data...');

      // Debug employee hierarchy first
      await OdooService().debugEmployeeHierarchy();

      // Debug Othman configuration specifically
      await OdooService().debugOthmanConfiguration();

      final stats = await OdooService().getTeamStatistics();
      print('Team stats loaded: ${stats.keys}');
      print('Pending requests type: ${stats['pending_requests'].runtimeType}');
      print('Team members type: ${stats['team_members'].runtimeType}');

      // Additional debugging
      if (stats['team_members'] is List) {
        print('Team members count: ${(stats['team_members'] as List).length}');
        for (int i = 0; i < (stats['team_members'] as List).length; i++) {
          final member = (stats['team_members'] as List)[i];
          print('Team member $i: ${member.runtimeType} - $member');
        }
      }

      if (stats['pending_requests'] is List) {
        print(
            'Pending requests count: ${(stats['pending_requests'] as List).length}');
        for (int i = 0; i < (stats['pending_requests'] as List).length; i++) {
          final request = (stats['pending_requests'] as List)[i];
          print('Pending request $i: ${request.runtimeType} - $request');
        }
      }

      _teamStats = stats;
      _lastFetchTime = DateTime.now();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error loading team data: $e');
      _isLoading = false;
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
