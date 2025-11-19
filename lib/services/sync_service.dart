import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'odoo_service.dart';
import 'offline_data_service.dart';
import 'data_sync_manager.dart';

/// Service to manage offline operations and sync queue
/// When offline, operations are stored locally and synced automatically when connection is restored
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  SharedPreferences? _prefs;
  final Connectivity _connectivity = Connectivity();
  bool _isConnected = true;
  bool _isSyncing = false;
  static const String _pendingOpsKey = 'pending_operations_queue';

  // Operation types
  static const String opTaskUpdate = 'task_update';
  static const String opTaskCreate = 'task_create';
  static const String opAttendancePunchIn = 'attendance_punch_in';
  static const String opAttendancePunchOut = 'attendance_punch_out';
  static const String opLeaveRequest = 'leave_request';
  static const String opEmployeeUpdate = 'employee_update';
  static const String opEmployeePhotoUpdate = 'employee_photo_update';
  static const String opHRNotification = 'hr_notification';

  /// Initialize the sync service
  Future<void> initialize() async {
    await _initPreferences();
    _startConnectivityListener();
    _startPeriodicSync();
  }

  /// Initialize SharedPreferences
  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    print('✅ SyncService initialized with SharedPreferences');
  }

  /// Get pending operations from cache
  List<Map<String, dynamic>> _getPendingOperations() {
    if (_prefs == null) return [];

    final opsJson = _prefs!.getString(_pendingOpsKey);
    if (opsJson == null || opsJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> opsList = jsonDecode(opsJson);
      return opsList.map((op) => op as Map<String, dynamic>).toList();
    } catch (e) {
      print('❌ Error parsing pending operations: $e');
      return [];
    }
  }

  /// Save pending operations to cache
  Future<void> _savePendingOperations(List<Map<String, dynamic>> ops) async {
    if (_prefs == null) {
      await _initPreferences();
    }

    try {
      final opsJson = jsonEncode(ops);
      await _prefs!.setString(_pendingOpsKey, opsJson);
    } catch (e) {
      print('❌ Error saving pending operations: $e');
    }
  }

  /// Start listening to connectivity changes
  void _startConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((result) {
      final wasConnected = _isConnected;
      _isConnected = result != ConnectivityResult.none;

      if (!wasConnected && _isConnected) {
        print('🌐 Connection restored! Starting sync...');
        // First sync pending operations, then refresh all data
        syncPendingOperations().then((_) {
          // After syncing pending operations, refresh all data
          final syncManager = DataSyncManager();
          syncManager.syncAllData().catchError((e) {
            print('⚠️ Error refreshing data after connection restored: $e');
          });
        });
      } else if (wasConnected && !_isConnected) {
        print('📴 Connection lost. Operations will be queued locally.');
      }
    });

    // Check initial connectivity
    _connectivity.checkConnectivity().then((result) {
      _isConnected = result != ConnectivityResult.none;
      print(
          '🌐 Initial connectivity: ${_isConnected ? "Connected" : "Offline"}');
      if (_isConnected) {
        syncPendingOperations().then((_) {
          // Refresh data on initial connection
          final syncManager = DataSyncManager();
          syncManager.syncAllData().catchError((e) {
            print('⚠️ Error refreshing data on initial connection: $e');
          });
        });
      }
    });
  }

  /// Start periodic sync check (every 30 seconds)
  void _startPeriodicSync() {
    Future.delayed(Duration(seconds: 30), () async {
      if (_isConnected && !_isSyncing) {
        await syncPendingOperations();
      }
      _startPeriodicSync(); // Schedule next check
    });
  }

  /// Queue an operation for later sync
  Future<int> queueOperation({
    required String operationType,
    required Map<String, dynamic> operationData,
  }) async {
    if (_prefs == null) {
      await initialize();
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ops = _getPendingOperations();

    // Generate a unique ID (timestamp + random)
    final id = timestamp + (ops.length * 1000);

    final newOp = {
      'id': id,
      'operation_type': operationType,
      'operation_data': operationData,
      'created_at': timestamp,
      'status': 'pending',
      'retry_count': 0,
    };

    ops.add(newOp);
    await _savePendingOperations(ops);

    print('📝 Queued operation: $operationType (ID: $id)');

    // Try to sync immediately if connected
    if (_isConnected) {
      syncPendingOperations();
    }

    return id;
  }

  /// Sync all pending operations
  Future<void> syncPendingOperations() async {
    if (_isSyncing || !_isConnected || _prefs == null) {
      return;
    }

    _isSyncing = true;
    print('🔄 Starting sync of pending operations...');

    try {
      final allOps = _getPendingOperations();
      final pendingOps =
          allOps.where((op) => op['status'] == 'pending').toList();
      pendingOps.sort(
          (a, b) => (a['created_at'] as int).compareTo(b['created_at'] as int));

      print('📊 Found ${pendingOps.length} pending operations');

      final List<Map<String, dynamic>> updatedOps = [];
      bool hasChanges = false;

      for (var op in pendingOps) {
        try {
          await _processOperation(op);
          // Mark as synced
          op['status'] = 'synced';
          op['synced_at'] = DateTime.now().millisecondsSinceEpoch;
          hasChanges = true;
          print('✅ Synced operation ${op['id']}: ${op['operation_type']}');
        } catch (e) {
          print('❌ Error processing operation ${op['id']}: $e');
          await _markOperationFailed(op, e.toString());
          hasChanges = true;
        }
        updatedOps.add(op);
      }

      // Update cache with synced operations
      if (hasChanges) {
        // Remove synced operations older than 7 days
        final cutoffTime =
            DateTime.now().subtract(Duration(days: 7)).millisecondsSinceEpoch;

        final opsToKeep = allOps.where((op) {
          if (op['status'] == 'synced' && op['synced_at'] != null) {
            return (op['synced_at'] as int) > cutoffTime;
          }
          return true; // Keep pending and failed operations
        }).toList();

        await _savePendingOperations(opsToKeep);

        // Trigger data refresh to update local cache with latest data from server
        // Don't await - let it run in background
        final syncManager = DataSyncManager();
        syncManager.syncAllData().catchError((e) {
          print('⚠️ Error refreshing data after sync: $e');
        });
      }

      print('✅ Sync completed');
    } catch (e) {
      print('❌ Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Process a single operation
  Future<void> _processOperation(Map<String, dynamic> op) async {
    final opType = op['operation_type'] as String;
    final opData = op['operation_data'] as Map<String, dynamic>;
    final odooService = OdooService();

    bool success = false;

    try {
      switch (opType) {
        case opTaskUpdate:
          success = await odooService.updateTaskStage(
            taskId: opData['taskId'] as int,
            newStage: opData['newStage'] as String,
          );
          break;

        case opTaskCreate:
          // Task creation returns an ID, so we handle it differently
          final taskId = await odooService.createTask(
            employeeId: opData['employeeId'] as int,
            title: opData['title'] as String,
            description: opData['description'] as String,
            priority: opData['priority'] as String,
            dueDate: DateTime.parse(opData['dueDate'] as String),
            assignedByName: opData['assignedByName'] as String,
          );
          success = taskId > 0;
          break;

        case opAttendancePunchIn:
          success = await odooService.punchIn(
            latitude: opData['latitude'] as double,
            longitude: opData['longitude'] as double,
            checkIn: DateTime.parse(opData['checkIn'] as String),
            entiteId: opData['entiteId'] as int?,
          );
          break;

        case opAttendancePunchOut:
          success = await odooService.punchOut(
            latitude: opData['latitude'] as double,
            longitude: opData['longitude'] as double,
            checkOut: DateTime.parse(opData['checkOut'] as String),
          );
          break;

        case opLeaveRequest:
          final leaveId = await odooService.createLeaveRequest(
            leaveTypeId: opData['leaveTypeId'] as int,
            dateFrom: DateTime.parse(opData['dateFrom'] as String),
            dateTo: DateTime.parse(opData['dateTo'] as String),
            reason: opData['reason'] as String?,
            isHalfDay: opData['isHalfDay'] as bool?,
          );
          success = leaveId > 0;
          break;

        case opEmployeeUpdate:
          success = await odooService.updateEmployeeField(
            opData['fieldKey'] as String,
            opData['newValue'] as String,
          );
          break;

        case opEmployeePhotoUpdate:
          success = await odooService.updateEmployeePhoto(
            opData['base64Image'] as String,
          );
          break;

        case opHRNotification:
          success = await odooService.sendNotificationToHR(
            employeeId: opData['employeeId'] as int,
            fieldName: opData['fieldName'] as String? ?? '',
            fieldLabel: opData['fieldLabel'] as String? ?? '',
            currentValue: opData['currentValue'] as String? ?? '',
            newValue: opData['newValue'] as String? ?? '',
            base64Image: opData['base64Image'] as String?,
          );
          break;

        default:
          print('⚠️ Unknown operation type: $opType');
          await _markOperationFailed(op, 'Unknown operation type');
          return;
      }

      if (success) {
        print('✅ Synced operation ${op['id']}: $opType');
        // Operation marked as synced in syncPendingOperations
      } else {
        throw Exception('Operation returned false');
      }
    } catch (e) {
      print('❌ Error syncing operation ${op['id']}: $e');
      await _markOperationFailed(op, e.toString());
      rethrow;
    }
  }

  /// Mark an operation as failed
  Future<void> _markOperationFailed(
      Map<String, dynamic> op, String error) async {
    final retryCount = (op['retry_count'] as int? ?? 0) + 1;

    // If retry count exceeds 5, mark as failed permanently
    final status = retryCount > 5 ? 'failed' : 'pending';

    op['status'] = status;
    op['retry_count'] = retryCount;
    op['error_message'] = error;

    // Update in cache
    final allOps = _getPendingOperations();
    final index = allOps.indexWhere((o) => o['id'] == op['id']);
    if (index != -1) {
      allOps[index] = op;
      await _savePendingOperations(allOps);
    }
  }

  /// Get pending operations count
  Future<int> getPendingOperationsCount() async {
    if (_prefs == null) {
      await initialize();
    }

    final ops = _getPendingOperations();
    return ops.where((op) => op['status'] == 'pending').length;
  }

  /// Get all pending operations (for UI display)
  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    if (_prefs == null) {
      await initialize();
    }

    final ops = _getPendingOperations();
    final pending = ops.where((op) => op['status'] == 'pending').toList();
    pending.sort(
        (a, b) => (b['created_at'] as int).compareTo(a['created_at'] as int));
    return pending;
  }

  /// Clear synced operations (cleanup old synced operations)
  Future<void> clearSyncedOperations({int olderThanDays = 7}) async {
    if (_prefs == null) {
      await initialize();
    }

    final cutoffTime = DateTime.now()
        .subtract(Duration(days: olderThanDays))
        .millisecondsSinceEpoch;

    final allOps = _getPendingOperations();
    final opsToKeep = allOps.where((op) {
      if (op['status'] == 'synced' && op['synced_at'] != null) {
        return (op['synced_at'] as int) > cutoffTime;
      }
      return true; // Keep pending and failed operations
    }).toList();

    await _savePendingOperations(opsToKeep);
    print('🗑️ Cleared old synced operations');
  }

  /// Force sync (can be called manually)
  Future<void> forceSync() async {
    if (!_isConnected) {
      throw Exception('No internet connection available');
    }
    await syncPendingOperations();
  }

  /// Check if connected
  bool get isConnected => _isConnected;

  /// Check if syncing
  bool get isSyncing => _isSyncing;
}
