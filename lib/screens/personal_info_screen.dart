// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/odoo_service.dart';
import '../services/user_service.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../utils/app_localizations.dart';
import '../utils/navigation_helpers.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isPersonalInfoExpanded = false;
  bool _isProfessionalInfoExpanded = false;
  bool _isLeaveInfoExpanded = false;
  bool _isBankInfoExpanded = false;
  bool _isEmergencyContactExpanded = false;
  late Future<Map<String, dynamic>> _employeeFuture;
  Uint8List? _profileImageBytes;

  @override
  void initState() {
    super.initState();
    _employeeFuture = _loadEmployeeDataWithLeaves();
  }

  Future<Map<String, dynamic>> _loadEmployeeDataWithLeaves() async {
    final employeeData = await OdooService().getEmployeeDetails();

    // Load leave information - OPTIMIZED: Parallelize independent API calls
    try {
      // Execute all leave-related API calls in parallel for faster loading
      final results = await Future.wait([
        OdooService().getLeaveBalance(),
        OdooService().getLeaveAllocations(),
        OdooService().getLeaveRequests(),
      ]);

      final leaveBalance = results[0] as Map<String, dynamic>;
      final allocations = results[1] as List<dynamic>;
      final leaveRequests = results[2] as List<dynamic>;

      // 1. Calculate total balance (solde congé)
      double totalBalance = 0.0;
      for (var entry in leaveBalance.entries) {
        final balance = entry.value is num ? entry.value.toDouble() : 0.0;
        totalBalance +=
            balance; // Sum all balances (can be positive or negative)
      }
      employeeData['leave_balance'] = totalBalance;

      // 2. Calculate total acquired (droit acquis) from allocations
      double totalAcquired = 0.0;
      try {
        print(
            '📊 Processing ${allocations.length} allocations for droit acquis...');
        for (var allocation in allocations) {
          // Try number_of_days first
          var days = allocation['number_of_days'];
          if (days == null || days == false) {
            // Try alternative field
            days = allocation['number_of_days_display'];
          }

          if (days != null && days != false) {
            double daysValue = 0.0;
            if (days is num) {
              daysValue = days.toDouble();
            } else if (days is String) {
              daysValue = double.tryParse(days) ?? 0.0;
            }
            totalAcquired += daysValue;
            print(
                '📊 Added $daysValue days from allocation (total: $totalAcquired)');
          } else {
            print('📊 Allocation has no number_of_days: $allocation');
          }
        }
      } catch (e) {
        print('Could not process leave allocations: $e');
      }

      // 3. Calculate total taken (congés pris) from validated requests
      double totalTaken = 0.0;
      int absencesCount = 0;
      try {
        for (var leave in leaveRequests) {
          if (leave['state'] == 'validate') {
            absencesCount++;
            if (leave['number_of_days'] != null) {
              final days = leave['number_of_days'];
              if (days is num) {
                totalTaken += days.toDouble();
              } else if (days is String) {
                totalTaken += double.tryParse(days) ?? 0.0;
              }
            }
          }
        }
      } catch (e) {
        print('Could not process leave requests: $e');
      }

      // If droit acquis is still 0, calculate it: Solde + Congés pris = Droit acquis
      if (totalAcquired == 0.0 && (totalBalance != 0.0 || totalTaken != 0.0)) {
        totalAcquired = totalBalance + totalTaken;
        print(
            '📊 Calculated droit acquis from balance + taken: $totalBalance + $totalTaken = $totalAcquired');
      }

      employeeData['leave_acquired'] = totalAcquired;
      employeeData['leave_taken'] = totalTaken;
      employeeData['absences_count'] = absencesCount;

      print('📊 Leave Summary:');
      print('  - Solde congé: $totalBalance jours');
      print('  - Droit acquis: $totalAcquired jours');
      print('  - Congés pris: $totalTaken jours');
      print('  - Absences: $absencesCount');
    } catch (e) {
      print('Could not load leave information: $e');
      employeeData['leave_balance'] = 0.0;
      employeeData['leave_acquired'] = 0.0;
      employeeData['leave_taken'] = 0.0;
      employeeData['absences_count'] = 0;
    }

    return employeeData;
  }

  Future<void> _showPhotoOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF000B58).withOpacity(0.95),
                const Color(0xFF35BF8C).withOpacity(0.95),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context).translate('choose_photo'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: Colors.white,
                    size: 28,
                  ),
                  title: Text(
                    AppLocalizations.of(context).translate('gallery'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Choisir une photo depuis votre appareil',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImageFromGallery();
                  },
                ),
                const Divider(color: Colors.white30),
                ListTile(
                  leading: Icon(
                    Icons.camera_alt,
                    color:
                        kIsWeb ? Colors.white.withOpacity(0.5) : Colors.white,
                    size: 28,
                  ),
                  title: Text(
                    'Appareil photo',
                    style: TextStyle(
                      color:
                          kIsWeb ? Colors.white.withOpacity(0.5) : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    kIsWeb
                        ? 'Non disponible sur navigateur web'
                        : 'Prendre une nouvelle photo',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                  enabled: !kIsWeb,
                  onTap: kIsWeb
                      ? null
                      : () async {
                          Navigator.pop(context);
                          await _pickImageFromCamera();
                        },
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.white.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context).translate('cancel'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512, // Reduced from 1024
        maxHeight: 512, // Reduced from 1024
        imageQuality: 60, // Reduced from 85
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });

        // Upload to Odoo
        await _uploadImageToOdoo(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadImageToOdoo(XFile image) async {
    try {
      // Show loading indicator
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Text(localizations.translate('uploading_photo')),
              ],
            ),
            duration: const Duration(seconds: 10),
            backgroundColor: const Color(0xFF000B58),
          ),
        );
      }

      // Convert image to base64
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Upload to Odoo
      final success = await OdooService().updateEmployeePhoto(base64Image);

      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).clearSnackBars();

        if (success) {
          // Update the user service with the new profile image
          UserService.instance.updateUserProfileImage(base64Image);

          // Send notification to HR via OdooService (with offline support)
          final employeeId = await OdooService().getCurrentEmployeeId();
          await OdooService().sendNotificationToHR(
            employeeId: employeeId,
            fieldName: 'image_1920',
            fieldLabel: 'Photo de profil',
            currentValue: 'Photo existante',
            newValue: 'Nouvelle photo',
            base64Image: base64Image,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(localizations.translate('photo_updated')),
                ],
              ),
              backgroundColor: const Color(0xFF35BF8C),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          throw Exception(localizations.translate('error_uploading'));
        }
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).clearSnackBars();

        String errorMessage = localizations.translate('error_uploading');

        if (e.toString().contains('413') ||
            e.toString().contains('Too Large')) {
          errorMessage = localizations.translate('image_too_large');
        } else if (e.toString().contains('timeout')) {
          errorMessage = localizations.translate('connection_timeout');
        } else {
          errorMessage =
              '${localizations.translate('upload_error')}: ${e.toString().replaceAll('Exception: ', '')}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      // On web, camera might not be available, show info to user
      if (kIsWeb) {
        // Try to pick image with camera preference
        final XFile? image = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
          preferredCameraDevice: CameraDevice.rear,
        );

        if (image != null) {
          setState(() {
            _selectedImage = image;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photo sélectionnée! (Upload vers Odoo à venir)'),
                backgroundColor: Color(0xFF35BF8C),
              ),
            );
          }
        } else {
          // Show info that camera might not be available on web
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Note: Sur navigateur web, la caméra peut ne pas être disponible. Veuillez sélectionner une image.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        // On mobile/desktop, use camera directly
        final XFile? image = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 512, // Reduced from 1024
          maxHeight: 512, // Reduced from 1024
          imageQuality: 60, // Reduced from 85
          preferredCameraDevice: CameraDevice.rear,
        );

        if (image != null) {
          setState(() {
            _selectedImage = image;
          });

          // Upload to Odoo
          await _uploadImageToOdoo(image);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la capture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        // Handle Android back button - same functionality as AppBar back button
        await NavigationHelpers.backToMenu(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => NavigationHelpers.backToMenu(context),
          ),
          title: Text(
            localizations.translate('personal_employment_info'),
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF000B58),
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: Container(
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
          child: FutureBuilder<Map<String, dynamic>>(
            future: _employeeFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                );
              }

              if (snapshot.hasError) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 100),
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          localizations.translate('loading_error'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            snapshot.error
                                .toString()
                                .replaceAll('Exception: ', ''),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushReplacementNamed(
                                context, '/personal-info');
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(localizations.translate('retry')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF000B58),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          label: Text(
                            localizations.translate('back'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final employeeData = snapshot.data!;
              if (_profileImageBytes == null &&
                  employeeData['image_1920'] != null &&
                  employeeData['image_1920'] != false) {
                _profileImageBytes = base64Decode(employeeData['image_1920']);
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width < 360
                              ? 16.0
                              : 20.0,
                          vertical: 20.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile Picture Section
                            Center(
                              child: Column(
                                children: [
                                  Stack(
                                    children: [
                                      _selectedImage != null
                                          ? CircleAvatar(
                                              radius: 60,
                                              backgroundColor: Colors.white,
                                              backgroundImage: kIsWeb
                                                  ? NetworkImage(
                                                      _selectedImage!.path)
                                                  : FileImage(File(
                                                          _selectedImage!.path))
                                                      as ImageProvider,
                                            )
                                          : (employeeData['image_1920'] !=
                                                      null &&
                                                  employeeData['image_1920'] !=
                                                      false)
                                              ? CircleAvatar(
                                                  radius: 60,
                                                  backgroundColor: Colors.white,
                                                  backgroundImage: MemoryImage(
                                                    _profileImageBytes ??
                                                        base64Decode(
                                                            employeeData[
                                                                'image_1920']),
                                                  ),
                                                )
                                              : const CircleAvatar(
                                                  radius: 60,
                                                  backgroundColor: Colors.white,
                                                  child: Icon(
                                                    Icons.person,
                                                    size: 60,
                                                    color: Color(0xFF000B58),
                                                  ),
                                                ),
                                      if (_selectedImage != null)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF35BF8C),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _showPhotoOptions,
                                    icon: const Icon(Icons.camera_alt),
                                    label: Text(localizations
                                        .translate('change_photo')),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF000B58),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 32),

                            // 1. Matricule (always visible)
                            _buildInfoCard(
                              icon: Icons.badge_outlined,
                              label: 'Matricule',
                              value: _getValueOrNA(employeeData['barcode']),
                            ),

                            const SizedBox(height: 12),

                            // 2. Nom et prénom (always visible) - with edit button
                            _buildNameEditCard(employeeData),

                            const SizedBox(height: 12),

                            // 3. Fonction (always visible)
                            _buildInfoCard(
                              icon: Icons.work_outline,
                              label: 'Fonction',
                              value: _getValueOrNA(
                                  _extractName(employeeData['job_id'])),
                            ),

                            const SizedBox(height: 16),

                            // Volet 1: Informations personnelles - Expandable
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _isPersonalInfoExpanded =
                                      !_isPersonalInfoExpanded;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Informations personnelles',
                                        style: TextStyle(
                                          fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  360
                                              ? 15
                                              : 17,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    AnimatedRotation(
                                      turns: _isPersonalInfoExpanded ? 0.5 : 0,
                                      duration:
                                          const Duration(milliseconds: 200),
                                      child: const Icon(
                                        Icons.keyboard_arrow_down,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Animated expansion of personal information
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: _isPersonalInfoExpanded
                                  ? Column(
                                      children: [
                                        const SizedBox(height: 16),

                                        // N° CIN
                                        _buildInfoCard(
                                          icon: Icons.credit_card_outlined,
                                          label: 'N° CIN',
                                          value: _getValueOrNA(employeeData[
                                              'l10n_ma_cin_number']),
                                          fieldKey: 'l10n_ma_cin_number',
                                          requiresFileUpload: true,
                                        ),

                                        // Date de naissance
                                        _buildInfoCard(
                                          icon: Icons.cake_outlined,
                                          label: 'Date de naissance',
                                          value: employeeData['birthday'] !=
                                                      null &&
                                                  employeeData['birthday'] !=
                                                      false
                                              ? _formatDate(
                                                  employeeData['birthday']
                                                      .toString())
                                              : 'N/A',
                                          fieldKey: 'birthday',
                                          fieldType: 'date',
                                          requiresFileUpload: true,
                                        ),

                                        // Situation familiale
                                        _buildInfoCard(
                                          icon: Icons.favorite_outline,
                                          label: 'Situation familiale',
                                          value:
                                              employeeData['marital'] != null &&
                                                      employeeData['marital'] !=
                                                          false
                                                  ? _formatMaritalStatus(
                                                      employeeData['marital']
                                                          .toString())
                                                  : 'N/A',
                                          fieldKey: 'marital',
                                          requiresFileUpload: true,
                                        ),

                                        // Nombre d'enfant
                                        _buildInfoCard(
                                          icon: Icons.child_care_outlined,
                                          label: 'Nombre d\'enfant',
                                          value: _getValueOrNA(
                                              employeeData['children']),
                                          fieldKey: 'children',
                                          requiresFileUpload: true,
                                        ),

                                        // N° de téléphone
                                        _buildInfoCard(
                                          icon: Icons.phone_outlined,
                                          label: 'N° de téléphone',
                                          value: _getValueOrNA(
                                              employeeData['work_phone']),
                                          fieldKey: employeeData[
                                                          'work_phone'] !=
                                                      null &&
                                                  employeeData['work_phone'] !=
                                                      false
                                              ? 'work_phone'
                                              : null,
                                          fieldType: employeeData[
                                                          'work_phone'] !=
                                                      null &&
                                                  employeeData['work_phone'] !=
                                                      false
                                              ? 'phone'
                                              : null,
                                        ),

                                        // Email
                                        _buildInfoCard(
                                          icon: Icons.email_outlined,
                                          label: 'Email',
                                          value: employeeData['work_email']
                                                  ?.toString() ??
                                              employeeData['user_email']
                                                  ?.toString() ??
                                              'N/A',
                                          fieldKey: 'work_email',
                                          fieldType: 'email',
                                        ),

                                        // Adresse
                                        _buildInfoCard(
                                          icon: Icons.location_on_outlined,
                                          label: 'Adresse',
                                          value: _hasAddress(employeeData)
                                              ? _formatAddress(employeeData)
                                              : 'N/A',
                                          fieldKey: 'street',
                                          requiresFileUpload: true,
                                        ),

                                        // Personne à prévenir (expandable)
                                        _buildEmergencyContactCard(
                                            employeeData),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            const SizedBox(height: 16),

                            // Volet 2: Informations professionnelles - Expandable
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _isProfessionalInfoExpanded =
                                      !_isProfessionalInfoExpanded;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Informations professionnelles',
                                        style: TextStyle(
                                          fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  360
                                              ? 15
                                              : 17,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    AnimatedRotation(
                                      turns:
                                          _isProfessionalInfoExpanded ? 0.5 : 0,
                                      duration:
                                          const Duration(milliseconds: 200),
                                      child: const Icon(
                                        Icons.keyboard_arrow_down,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Animated expansion of professional information
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: _isProfessionalInfoExpanded
                                  ? Column(
                                      children: [
                                        const SizedBox(height: 16),

                                        // Département
                                        _buildInfoCard(
                                          icon: Icons.business_outlined,
                                          label: 'Département',
                                          value: _getValueOrNA(_extractName(
                                              employeeData['department_id'])),
                                        ),

                                        // Manager
                                        _buildInfoCard(
                                          icon:
                                              Icons.supervisor_account_outlined,
                                          label: 'Manager',
                                          value: _getValueOrNA(_extractName(
                                              employeeData['parent_id'])),
                                        ),

                                        // Date d'embauche
                                        _buildInfoCard(
                                          icon: Icons.calendar_today_outlined,
                                          label: 'Date d\'embauche',
                                          value: employeeData[
                                                          'first_contract_date'] !=
                                                      null &&
                                                  employeeData[
                                                          'first_contract_date'] !=
                                                      false
                                              ? _formatDate(employeeData[
                                                      'first_contract_date']
                                                  .toString())
                                              : 'N/A',
                                        ),

                                        // Date fin de contrat
                                        _buildInfoCard(
                                          icon: Icons.event_busy_outlined,
                                          label: 'Date fin de contrat',
                                          value: employeeData[
                                                          'contract_end_date'] !=
                                                      null &&
                                                  employeeData[
                                                          'contract_end_date'] !=
                                                      false
                                              ? _formatDate(employeeData[
                                                      'contract_end_date']
                                                  .toString())
                                              : 'N/A',
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            const SizedBox(height: 16),

                            // Congés et absences - Expandable
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _isLeaveInfoExpanded = !_isLeaveInfoExpanded;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Congés et absences',
                                        style: TextStyle(
                                          fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  360
                                              ? 15
                                              : 17,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    AnimatedRotation(
                                      turns: _isLeaveInfoExpanded ? 0.5 : 0,
                                      duration:
                                          const Duration(milliseconds: 200),
                                      child: const Icon(
                                        Icons.keyboard_arrow_down,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Animated expansion of leave information
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: _isLeaveInfoExpanded
                                  ? Column(
                                      children: [
                                        const SizedBox(height: 16),

                                        // Solde congé
                                        _buildInfoCard(
                                          icon: Icons.calendar_today_outlined,
                                          label: 'Solde congé',
                                          value: employeeData[
                                                      'leave_balance'] !=
                                                  null
                                              ? '${(employeeData['leave_balance'] as num).toStringAsFixed(1)} jours'
                                              : 'N/A',
                                        ),

                                        // Droit acquis
                                        _buildInfoCard(
                                          icon: Icons.check_circle_outline,
                                          label: 'Droit acquis',
                                          value: employeeData[
                                                      'leave_acquired'] !=
                                                  null
                                              ? '${(employeeData['leave_acquired'] as num).toStringAsFixed(1)} jours'
                                              : 'N/A',
                                        ),

                                        // Congés pris
                                        _buildInfoCard(
                                          icon: Icons.event_busy_outlined,
                                          label: 'Congés pris',
                                          value: employeeData['leave_taken'] !=
                                                  null
                                              ? '${(employeeData['leave_taken'] as num).toStringAsFixed(1)} jours'
                                              : 'N/A',
                                        ),

                                        // Absences enregistrées
                                        _buildInfoCard(
                                          icon: Icons.person_off_outlined,
                                          label: 'Absences enregistrées',
                                          value: employeeData[
                                                      'absences_count'] !=
                                                  null
                                              ? '${employeeData['absences_count']}'
                                              : 'N/A',
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            const SizedBox(height: 16),

                            // Informations bancaires - Expandable
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _isBankInfoExpanded = !_isBankInfoExpanded;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Informations bancaires',
                                        style: TextStyle(
                                          fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  360
                                              ? 15
                                              : 17,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    AnimatedRotation(
                                      turns: _isBankInfoExpanded ? 0.5 : 0,
                                      duration:
                                          const Duration(milliseconds: 200),
                                      child: const Icon(
                                        Icons.keyboard_arrow_down,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Animated expansion of bank information
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: _isBankInfoExpanded
                                  ? Column(
                                      children: [
                                        const SizedBox(height: 16),

                                        // Banque
                                        _buildInfoCard(
                                          icon: Icons.account_balance_outlined,
                                          label: 'Banque',
                                          value: _getValueOrNA(
                                              employeeData['bank_name']),
                                        ),

                                        // Agence bancaire
                                        _buildInfoCard(
                                          icon: Icons.business_outlined,
                                          label: 'Agence bancaire',
                                          value: _getValueOrNA(
                                              employeeData['bank_bic']),
                                        ),

                                        // RIB
                                        _buildInfoCard(
                                          icon: Icons.credit_card_outlined,
                                          label: 'RIB',
                                          value: _getValueOrNA(
                                              employeeData['bank_rib']),
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    String? fieldKey,
    String? fieldType,
    bool requiresFileUpload = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          // Edit icon for editable fields
          if (fieldKey != null &&
              (_isEditableField(fieldKey) || requiresFileUpload))
            InkWell(
              onTap: () {
                if (requiresFileUpload) {
                  _showEditDialogWithFileUpload(
                      fieldKey, label, value, fieldType);
                } else {
                  _showEditDialog(fieldKey, label, value, fieldType);
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _extractName(dynamic value) {
    if (value is List && value.length >= 2) {
      return value[1].toString();
    }
    if (value is String) {
      return value;
    }
    return 'N/A';
  }

  String _formatDate(String date) {
    try {
      final parsedDate = DateTime.parse(date);
      return DateFormat('dd/MM/yyyy').format(parsedDate);
    } catch (e) {
      return date;
    }
  }

  bool _isEditableField(String fieldKey) {
    // Define which fields are editable
    // Note: firstname and lastname are not directly editable in Odoo,
    // but we allow editing 'name' which will update the full name
    const editableFields = [
      'name',
      'work_email',
      'work_phone',
      'mobile_phone',
      'birthday',
      'street',
      'street2',
      'city',
      'zip',
    ];
    return editableFields.contains(fieldKey);
  }

  bool _requiresFileUpload(String fieldKey) {
    // Fields that require file upload for confirmation
    const fieldsWithFileUpload = [
      'name',
      'l10n_ma_cin_number',
      'birthday',
      'marital',
      'children',
      'street',
      'street2',
      'city',
      'zip',
    ];
    return fieldsWithFileUpload.contains(fieldKey);
  }

  void _showEditDialog(
      String fieldKey, String label, String currentValue, String? fieldType) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Modifier $label'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (fieldType == 'email')
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: label,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
            else if (fieldType == 'phone')
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: label,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
            else if (fieldType == 'date')
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    controller.text = DateFormat('yyyy-MM-dd').format(date);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: label,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(controller.text),
                ),
              )
            else
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: label,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await _updateField(fieldKey, controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  void _showEditDialogWithFileUpload(
      String fieldKey, String label, String currentValue, String? fieldType) {
    final controller =
        TextEditingController(text: currentValue == 'N/A' ? '' : currentValue);
    List<XFile> selectedFiles = [];
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Modifier $label'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Input field
                  if (fieldType == 'date')
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate:
                              currentValue != 'N/A' && currentValue.isNotEmpty
                                  ? DateTime.tryParse(currentValue) ??
                                      DateTime.now()
                                  : DateTime.now(),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          controller.text =
                              DateFormat('yyyy-MM-dd').format(date);
                          setDialogState(() {});
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: label,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(controller.text.isEmpty
                            ? 'Sélectionner une date'
                            : controller.text),
                      ),
                    )
                  else if (fieldKey == 'marital')
                    Builder(
                      builder: (context) {
                        // Convert French display value back to English value for dropdown
                        String? englishValue;
                        if (currentValue != 'N/A' && currentValue.isNotEmpty) {
                          // Reverse mapping from French to English
                          if (currentValue.contains('Célibataire')) {
                            englishValue = 'single';
                          } else if (currentValue.contains('Marié')) {
                            englishValue = 'married';
                          } else if (currentValue.contains('Divorcé')) {
                            englishValue = 'divorced';
                          } else if (currentValue.contains('Veuf')) {
                            englishValue = 'widower';
                          } else {
                            // If it's already in English, use it directly
                            englishValue = currentValue.toLowerCase();
                          }
                        }

                        return DropdownButtonFormField<String>(
                          value: englishValue,
                          decoration: InputDecoration(
                            labelText: label,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                                value: 'single', child: Text('Célibataire')),
                            DropdownMenuItem(
                                value: 'married', child: Text('Marié(e)')),
                            DropdownMenuItem(
                                value: 'divorced', child: Text('Divorcé(e)')),
                            DropdownMenuItem(
                                value: 'widower', child: Text('Veuf(ve)')),
                          ],
                          onChanged: (value) {
                            controller.text = value ?? '';
                            setDialogState(() {});
                          },
                        );
                      },
                    )
                  else
                    TextFormField(
                      controller: controller,
                      keyboardType: fieldKey == 'children'
                          ? TextInputType.number
                          : TextInputType.text,
                      decoration: InputDecoration(
                        labelText: label,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ce champ est requis';
                        }
                        return null;
                      },
                    ),

                  const SizedBox(height: 20),

                  // File upload section
                  Text(
                    'Joindre des fichiers de confirmation (optionnel)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Selected files list
                  if (selectedFiles.isNotEmpty)
                    ...selectedFiles.map((file) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.attach_file, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  file.name,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  selectedFiles.remove(file);
                                  setDialogState(() {});
                                },
                              ),
                            ],
                          ),
                        )),

                  // Upload buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final file = await _picker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (file != null) {
                              selectedFiles.add(file);
                              setDialogState(() {});
                            }
                          },
                          icon: const Icon(Icons.photo_library, size: 18),
                          label: const Text('Photo'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            // For file picker, we'll use image picker as a workaround
                            // In a real app, you'd use file_picker package
                            final file = await _picker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (file != null) {
                              selectedFiles.add(file);
                              setDialogState(() {});
                            }
                          },
                          icon: const Icon(Icons.insert_drive_file, size: 18),
                          label: const Text('Fichier'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'Vous pouvez joindre des photos ou documents pour confirmer l\'information',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  await _updateFieldWithFileUpload(
                    fieldKey,
                    controller.text.trim(),
                    selectedFiles,
                    label,
                  );
                }
              },
              child: const Text('Mettre à jour'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateFieldWithFileUpload(
    String fieldKey,
    String newValue,
    List<XFile> files,
    String fieldLabel,
  ) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Envoi de la demande en cours...'),
            ],
          ),
          backgroundColor: Color(0xFF000B58),
        ),
      );

      // Convert files to base64
      List<String> base64Files = [];
      for (var file in files) {
        final bytes = await file.readAsBytes();
        final base64 = base64Encode(bytes);
        base64Files.add(base64);
      }

      // Get employee data
      final employeeId = await OdooService().getCurrentEmployeeId();
      final employeeData = await OdooService().getEmployeeDetails();

      // Map field key to label
      final fieldLabels = {
        'name': 'Nom et prénom',
        'l10n_ma_cin_number': 'N° CIN',
        'birthday': 'Date de naissance',
        'marital': 'Situation familiale',
        'children': 'Nombre d\'enfant',
        'street': 'Adresse - Rue',
        'street2': 'Adresse - Complément',
        'city': 'Adresse - Ville',
        'zip': 'Adresse - Code postal',
      };

      final label = fieldLabels[fieldKey] ?? fieldLabel;
      final currentValue = employeeData[fieldKey]?.toString() ?? 'N/A';

      // Send notification to HR with files
      // For now, we'll send the first file as base64Image if available
      // In a real implementation, you might want to send multiple files
      String? base64Image;
      if (base64Files.isNotEmpty) {
        base64Image = base64Files.first;
      }

      await OdooService().sendNotificationToHR(
        employeeId: employeeId,
        fieldName: fieldKey,
        fieldLabel: label,
        currentValue: currentValue,
        newValue: newValue,
        base64Image: base64Image,
      );

      // Show success message
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Demande envoyée au RH avec succès'),
            ],
          ),
          backgroundColor: Color(0xFF35BF8C),
          duration: Duration(seconds: 3),
        ),
      );

      // Refresh the page
      setState(() {
        _employeeFuture = OdooService().getEmployeeDetails();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateField(String fieldKey, String newValue) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Mise à jour en cours...'),
            ],
          ),
          backgroundColor: Color(0xFF000B58),
        ),
      );

      // Update in Odoo
      final success =
          await OdooService().updateEmployeeField(fieldKey, newValue);

      if (success) {
        // Update UserService if name was changed
        if (fieldKey == 'name') {
          UserService.instance.updateUserName(newValue);
        }

        // Send notification to HR via OdooService (with offline support)
        final employeeId = await OdooService().getCurrentEmployeeId();
        final employeeData = await OdooService().getEmployeeDetails();

        // Map field key to label
        final fieldLabels = {
          'name': 'Nom complet',
          'work_email': 'Email',
          'work_phone': 'Téléphone',
          'mobile_phone': 'Téléphone portable',
          'birthday': 'Date de naissance',
          'street': 'Adresse - Rue',
          'street2': 'Adresse - Complément',
          'city': 'Adresse - Ville',
          'zip': 'Adresse - Code postal',
        };

        final fieldLabel = fieldLabels[fieldKey] ?? fieldKey;
        final currentValue = employeeData[fieldKey]?.toString() ?? 'N/A';

        await OdooService().sendNotificationToHR(
          employeeId: employeeId,
          fieldName: fieldKey,
          fieldLabel: fieldLabel,
          currentValue: currentValue,
          newValue: newValue,
        );

        // Show success message
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Information mise à jour avec succès'),
              ],
            ),
            backgroundColor: Color(0xFF35BF8C),
            duration: Duration(seconds: 3),
          ),
        );

        // Refresh the page and UserService
        setState(() {
          _employeeFuture = OdooService().getEmployeeDetails();
        });

        // Force refresh UserService to update cached data
        await UserService.instance.refreshUser();
      } else {
        throw Exception('Erreur lors de la mise à jour');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Note: HR notifications are now sent via OdooService.sendNotificationToHR
  // which supports offline mode and syncs automatically when connection is restored

  String _formatGender(String gender) {
    switch (gender.toLowerCase()) {
      case 'male':
      case 'm':
        return 'Masculin';
      case 'female':
      case 'f':
        return 'Féminin';
      case 'other':
      case 'o':
        return 'Autre';
      default:
        return gender;
    }
  }

  String _formatMaritalStatus(String status) {
    switch (status.toLowerCase()) {
      case 'single':
        return 'Célibataire';
      case 'married':
        return 'Marié(e)';
      case 'divorced':
        return 'Divorcé(e)';
      case 'widower':
        return 'Veuf(ve)';
      default:
        return status;
    }
  }

  bool _hasAddress(Map<String, dynamic> employeeData) {
    return (employeeData['street'] != null &&
            employeeData['street'] != false) ||
        (employeeData['city'] != null && employeeData['city'] != false) ||
        (employeeData['zip'] != null && employeeData['zip'] != false);
  }

  // Helper function to get value or "N/A"
  String _getValueOrNA(dynamic value) {
    if (value == null || value == false || value == 'null' || value == '') {
      return 'N/A';
    }
    return value.toString();
  }

  String _formatAddress(Map<String, dynamic> employeeData) {
    List<String> addressParts = [];

    if (employeeData['street'] != null && employeeData['street'] != false) {
      addressParts.add(employeeData['street'].toString());
    }
    if (employeeData['street2'] != null && employeeData['street2'] != false) {
      addressParts.add(employeeData['street2'].toString());
    }
    if (employeeData['zip'] != null && employeeData['zip'] != false) {
      addressParts.add(employeeData['zip'].toString());
    }
    if (employeeData['city'] != null && employeeData['city'] != false) {
      addressParts.add(employeeData['city'].toString());
    }
    if (employeeData['country_id'] != null &&
        employeeData['country_id'] != false) {
      addressParts.add(_extractName(employeeData['country_id']));
    }

    return addressParts.isEmpty ? 'N/A' : addressParts.join(', ');
  }

  // Séparer le nom complet en prénom et nom
  Map<String, String> _splitFullName(String fullName) {
    if (fullName.isEmpty || fullName == 'N/A') {
      return {'firstname': '', 'lastname': ''};
    }

    final parts = fullName.trim().split(' ');

    if (parts.isEmpty) {
      return {'firstname': '', 'lastname': ''};
    } else if (parts.length == 1) {
      // Si un seul mot, considérer comme prénom
      return {'firstname': parts[0], 'lastname': ''};
    } else {
      // Premier mot = prénom, le reste = nom
      final firstname = parts[0];
      final lastname = parts.sublist(1).join(' ');
      return {'firstname': firstname, 'lastname': lastname};
    }
  }

  // Widget pour afficher le prénom et le nom avec bouton d'édition
  Widget _buildNameEditCard(Map<String, dynamic> employeeData) {
    final fullName = employeeData['user_name']?.toString() ??
        employeeData['name']?.toString() ??
        'N/A';

    return _buildInfoCard(
      icon: Icons.person_outline,
      label: 'Nom et prénom',
      value: fullName,
      fieldKey: 'name',
      requiresFileUpload: true,
    );
  }

  // Widget pour afficher le prénom et le nom séparément
  Widget _buildSeparatedNameCards(Map<String, dynamic> employeeData) {
    final fullName = employeeData['user_name']?.toString() ??
        employeeData['name']?.toString() ??
        'N/A';

    final nameParts = _splitFullName(fullName);
    final firstname = nameParts['firstname'] ?? '';
    final lastname = nameParts['lastname'] ?? '';

    return Row(
      children: [
        // Prénom (affichage uniquement, non éditable directement)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _buildInfoCard(
              icon: Icons.person_outline,
              label: 'Prénom',
              value: firstname.isNotEmpty ? firstname : 'N/A',
              // Pas de fieldKey pour rendre non éditable
            ),
          ),
        ),

        // Nom (affichage uniquement, non éditable directement) - toujours visible
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _buildInfoCard(
              icon: Icons.person_outline,
              label: 'Nom',
              value: lastname.isNotEmpty ? lastname : 'N/A',
              // Pas de fieldKey pour rendre non éditable
            ),
          ),
        ),
      ],
    );
  }

  // Widget pour afficher les informations de contact d'urgence avec expansion
  Widget _buildEmergencyContactCard(Map<String, dynamic> employeeData) {
    final emergencyContact = employeeData['emergency_contact']?.toString();
    final emergencyPhone = employeeData['emergency_phone']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Carte cliquable pour Personne à prévenir
          InkWell(
            onTap: () {
              setState(() {
                _isEmergencyContactExpanded = !_isEmergencyContactExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.person_pin_circle_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personne à prévenir',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getValueOrNA(emergencyContact),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  // Icône de flèche si le numéro est disponible
                  AnimatedRotation(
                    turns: _isEmergencyContactExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Numéro de téléphone (expandable)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isEmergencyContactExpanded
                ? Container(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(
                          color: Colors.white30,
                          height: 1,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_in_talk_outlined,
                              color: Colors.white.withOpacity(0.8),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'N° tél de la personne à prévenir',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getValueOrNA(emergencyPhone),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
