import 'package:flutter/material.dart';
import '../utils/navigation_helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/odoo_service.dart';
import '../utils/app_localizations.dart';
import 'package:intl/intl.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final OdooService _odooService = OdooService();
  bool _isLoading = false;
  bool _locationEnabled = false;
  Position? _currentPosition;
  String? _lastAttendanceType;
  DateTime? _lastAttendanceTime;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _checkLastAttendance();
    // Start periodic location status check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLocationStatusListener();
    });
  }

  @override
  void dispose() {
    // Cancel any ongoing listeners if needed
    super.dispose();
  }

  void _startLocationStatusListener() {
    // Check location status every 3 seconds to update UI if user changes it
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _checkLocationPermission();
        _startLocationStatusListener(); // Continue checking
      }
    });
  }

  Future<void> _checkLocationPermission() async {
    if (kIsWeb) {
      // On web, location is handled differently
      setState(() {
        _locationEnabled = false; // Web doesn't support location for now
      });
      return;
    }

    try {
      // Check both permission status and location service status
      final permissionStatus = await Permission.location.status;
      final isLocationServiceEnabled =
          await Geolocator.isLocationServiceEnabled();

      // Location is enabled only if BOTH permission is granted AND location services are enabled
      final isEnabled = permissionStatus.isGranted && isLocationServiceEnabled;

      setState(() {
        _locationEnabled = isEnabled;
      });

      print(
          'Location permission: ${permissionStatus.isGranted}, Location service enabled: $isLocationServiceEnabled, Final status: $isEnabled');
    } catch (e) {
      print('Error checking location permission: $e');
      setState(() {
        _locationEnabled = false;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    // First request permission
    final status = await Permission.location.request();

    if (status.isGranted) {
      // Permission granted - now check if location services are actually enabled
      final isLocationServiceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!isLocationServiceEnabled) {
        // Location services are disabled - ask user before opening settings
        if (mounted) {
          final shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              final localizations = AppLocalizations.of(context);
              return AlertDialog(
                title: Text(
                  localizations.translate('location_service_disabled'),
                ),
                content: const Text(
                  'Les services de localisation sont désactivés. Voulez-vous ouvrir les paramètres pour les activer?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(localizations.translate('cancel')),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF35BF8C),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Ouvrir les paramètres'),
                  ),
                ],
              );
            },
          );

          if (shouldOpenSettings == true) {
            // User confirmed - open location settings
            final opened = await Geolocator.openLocationSettings();
            if (!opened) {
              // Fallback: open app settings
              await openAppSettings();
            }

            // Re-check status after user returns (check every second for 10 seconds)
            int checkCount = 0;
            final maxChecks = 10;
            Future.delayed(const Duration(seconds: 1), () {
              void checkPeriodically() {
                if (mounted && checkCount < maxChecks) {
                  _checkLocationPermission();
                  _getCurrentLocation();

                  if (_locationEnabled) {
                    // Success! Show confirmation
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)
                              .translate('location_enabled'),
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } else {
                    // Check again
                    checkCount++;
                    Future.delayed(
                        const Duration(seconds: 1), checkPeriodically);
                  }
                }
              }

              checkPeriodically();
            });
          }
        }
      } else {
        // Location services already enabled - verify we can get location
        await _getCurrentLocation();
        await _checkLocationPermission();

        if (_locationEnabled && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).translate('location_enabled'),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else if (status.isPermanentlyDenied) {
      // Permission permanently denied
      _showPermissionDialog();
    } else {
      // Permission denied
      setState(() {
        _locationEnabled = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)
                  .translate('location_permission_denied'),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showPermissionDialog() {
    if (kIsWeb) return; // Don't show on web

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(localizations.translate('location_permission_required')),
          content: Text(localizations.translate('location_permission_message')),
          actions: [
            TextButton(
              onPressed: () => NavigationHelpers.backToMenu(context),
              child: Text(localizations.translate('cancel')),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (!kIsWeb) {
                  openAppSettings();
                }
              },
              child: Text(localizations.translate('open_settings')),
            ),
          ],
        );
      },
    );
  }

  void _showWebLocationDialog(bool isPunchIn) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(localizations.translate('web_location_notice')),
          content: Text(localizations.translate('web_location_message')),
          actions: [
            TextButton(
              onPressed: () => NavigationHelpers.backToMenu(context),
              child: Text(localizations.translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                // Use a default location (e.g., company headquarters)
                setState(() {
                  _currentPosition = Position(
                    latitude: 33.5731, // Default to Casablanca
                    longitude: -7.5898,
                    timestamp: DateTime.now(),
                    accuracy: 0,
                    altitude: 0,
                    altitudeAccuracy: 0,
                    heading: 0,
                    headingAccuracy: 0,
                    speed: 0,
                    speedAccuracy: 0,
                  );
                });

                // Wait a bit for state to update then execute the action
                await Future.delayed(const Duration(milliseconds: 100));

                if (isPunchIn) {
                  // Re-call _punchIn after setting position
                  await _executePunchIn();
                } else {
                  // Re-call _punchOut after setting position
                  await _executePunchOut();
                }
              },
              child: Text(localizations.translate('continue_without_location')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkLastAttendance() async {
    try {
      final lastAttendance = await _odooService.getLastAttendance();
      if (lastAttendance != null && mounted) {
        setState(() {
          _lastAttendanceType = lastAttendance['action'];
          _lastAttendanceTime = DateTime.parse(lastAttendance['check_in']);
        });
      }
    } catch (e) {
      print('Error checking last attendance: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    if (kIsWeb) {
      // On web, use mock coordinates or show a message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are not available on web'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      LocationPermission permission = await Geolocator.checkPermission();

      // Update location enabled status based on BOTH service status AND permission
      final permissionGranted = permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever;
      setState(() {
        _locationEnabled = serviceEnabled && permissionGranted;
      });

      if (!serviceEnabled) {
        // Services disabled - return without showing message
        return;
      }
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)
                    .translate('location_permission_denied')),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showPermissionDialog();
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${AppLocalizations.of(context).translate('error_getting_location')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _punchIn() async {
    // Handle web platform - use mock location or allow without location
    if (kIsWeb) {
      // On web, proceed without location or use a default location
      _showWebLocationDialog(true);
      return;
    }

    // Check location status before allowing punch in
    await _checkLocationPermission();
    if (!_locationEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context).translate('location_required')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (_currentPosition == null) {
      await _getCurrentLocation();
    }

    // Re-check location status after getting location
    await _checkLocationPermission();
    if (!_locationEnabled || _currentPosition == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context).translate('location_required')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get available entities
      final entities = await _odooService.getPunchingEntities();
      int? entiteId;

      if (entities.isNotEmpty) {
        entiteId = entities[0]['id']; // Use first available entity
        print('Using entity ID: $entiteId');
      } else {
        print('Warning: No entities found, attempting punch-in without entity');
      }

      final success = await _odooService.punchIn(
        latitude: _currentPosition?.latitude ?? 0.0,
        longitude: _currentPosition?.longitude ?? 0.0,
        checkIn: DateTime.now(),
        entiteId: entiteId, // Pass the entity ID
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context).translate('punch_in_success')),
              backgroundColor: Colors.green,
            ),
          );
          _checkLastAttendance();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context).translate('punch_in_failed')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error punching in: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${AppLocalizations.of(context).translate('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _executePunchIn() async {
    setState(() => _isLoading = true);

    try {
      // Get available entities
      final entities = await _odooService.getPunchingEntities();
      int? entiteId;

      if (entities.isNotEmpty) {
        entiteId = entities[0]['id']; // Use first available entity
        print('Using entity ID: $entiteId');
      } else {
        print('Warning: No entities found, attempting punch-in without entity');
      }

      final success = await _odooService.punchIn(
        latitude: _currentPosition?.latitude ?? 0.0,
        longitude: _currentPosition?.longitude ?? 0.0,
        checkIn: DateTime.now(),
        entiteId: entiteId, // Pass the entity ID
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context).translate('punch_in_success')),
              backgroundColor: Colors.green,
            ),
          );
          _checkLastAttendance();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context).translate('punch_in_failed')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error punching in: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${AppLocalizations.of(context).translate('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _executePunchOut() async {
    setState(() => _isLoading = true);

    try {
      final success = await _odooService.punchOut(
        latitude: _currentPosition?.latitude ?? 0.0,
        longitude: _currentPosition?.longitude ?? 0.0,
        checkOut: DateTime.now(),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context).translate('punch_out_success')),
              backgroundColor: Colors.green,
            ),
          );
          _checkLastAttendance();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context).translate('punch_out_failed')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error punching out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${AppLocalizations.of(context).translate('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _punchOut() async {
    // Handle web platform
    if (kIsWeb) {
      _showWebLocationDialog(false);
      return;
    }

    // Check location status before allowing punch out
    await _checkLocationPermission();
    if (!_locationEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context).translate('location_required')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (_currentPosition == null) {
      await _getCurrentLocation();
    }

    // Re-check location status after getting location
    await _checkLocationPermission();
    if (!_locationEnabled || _currentPosition == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context).translate('location_required')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _odooService.punchOut(
        latitude: _currentPosition?.latitude ?? 0.0,
        longitude: _currentPosition?.longitude ?? 0.0,
        checkOut: DateTime.now(),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context).translate('punch_out_success')),
              backgroundColor: Colors.green,
            ),
          );
          _checkLastAttendance();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context).translate('punch_out_failed')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error punching out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${AppLocalizations.of(context).translate('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isCheckingIn =
        _lastAttendanceType == null || _lastAttendanceType == 'check_out';

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('punch_in_out')),
        backgroundColor: const Color(0xFF000B58),
        foregroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF000B58),
              Color(0xFF35BF8C),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Location Status Card
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _locationEnabled
                            ? Icons.location_on
                            : Icons.location_off,
                        color: _locationEnabled ? Colors.green : Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _locationEnabled
                            ? localizations.translate('location_enabled')
                            : localizations.translate('location_disabled'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_currentPosition != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Lon: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Action Buttons
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Punch In Button
                      if (isCheckingIn)
                        _buildActionButton(
                          icon: Icons.login,
                          label: localizations.translate('punch_in'),
                          color: Colors.green,
                          onPressed: (_isLoading || !_locationEnabled)
                              ? null
                              : _punchIn,
                          isLoading: _isLoading,
                        ),

                      if (isCheckingIn) const SizedBox(height: 20),

                      // Punch Out Button
                      if (!isCheckingIn)
                        _buildActionButton(
                          icon: Icons.logout,
                          label: localizations.translate('punch_out'),
                          color: Colors.red,
                          onPressed: (_isLoading || !_locationEnabled)
                              ? null
                              : _punchOut,
                          isLoading: _isLoading,
                        ),

                      const SizedBox(height: 40),

                      // Last Attendance Info
                      if (_lastAttendanceTime != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Text(
                                localizations.translate('last_attendance'),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _lastAttendanceType == 'check_in'
                                    ? localizations.translate('checked_in')
                                    : localizations.translate('checked_out'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd/MM/yyyy HH:mm')
                                    .format(_lastAttendanceTime!),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Enable Location Button
              if (!_locationEnabled)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _requestLocationPermission,
                      icon: const Icon(Icons.location_on),
                      label: Text(localizations.translate('enable_location')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF35BF8C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
