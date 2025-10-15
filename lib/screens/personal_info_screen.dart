// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/odoo_service.dart';
import '../services/user_service.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../utils/app_localizations.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

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

    return Scaffold(
      appBar: AppBar(
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
          future: OdooService().getEmployeeDetails(),
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
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
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

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
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
                                          ? NetworkImage(_selectedImage!.path)
                                          : FileImage(
                                                  File(_selectedImage!.path))
                                              as ImageProvider,
                                    )
                                  : (employeeData['image_1920'] != null &&
                                          employeeData['image_1920'] != false)
                                      ? CircleAvatar(
                                          radius: 60,
                                          backgroundColor: Colors.white,
                                          backgroundImage: MemoryImage(
                                            base64Decode(
                                                employeeData['image_1920']),
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
                            label:
                                Text(localizations.translate('change_photo')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF000B58),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Personal Information Section
                    _buildSectionTitle('Informations personnelles'),
                    const SizedBox(height: 16),

                    _buildInfoCard(
                      icon: Icons.person_outline,
                      label: 'Nom complet',
                      value: employeeData['name']?.toString() ?? 'N/A',
                    ),

                    _buildInfoCard(
                      icon: Icons.email_outlined,
                      label: 'Email professionnel',
                      value: employeeData['work_email']?.toString() ??
                          employeeData['user_email']?.toString() ??
                          'N/A',
                    ),

                    if (employeeData['work_phone'] != null &&
                        employeeData['work_phone'] != false)
                      _buildInfoCard(
                        icon: Icons.phone_outlined,
                        label: 'Téléphone professionnel',
                        value: employeeData['work_phone'].toString(),
                      ),

                    if (employeeData['mobile_phone'] != null &&
                        employeeData['mobile_phone'] != false)
                      _buildInfoCard(
                        icon: Icons.phone_android_outlined,
                        label: 'Mobile',
                        value: employeeData['mobile_phone'].toString(),
                      ),

                    if (employeeData['birthday'] != null &&
                        employeeData['birthday'] != false)
                      _buildInfoCard(
                        icon: Icons.cake_outlined,
                        label: 'Date de naissance',
                        value: _formatDate(employeeData['birthday'].toString()),
                      ),

                    const SizedBox(height: 20),

                    // Employment Information d'emploi
                    _buildSectionTitle('Informations d\'emploi'),
                    const SizedBox(height: 16),

                    if (employeeData['job_id'] != null &&
                        employeeData['job_id'] != false)
                      _buildInfoCard(
                        icon: Icons.work_outline,
                        label: 'Poste',
                        value: _extractName(employeeData['job_id']),
                      ),

                    if (employeeData['department_id'] != null &&
                        employeeData['department_id'] != false)
                      _buildInfoCard(
                        icon: Icons.business_outlined,
                        label: 'Département',
                        value: _extractName(employeeData['department_id']),
                      ),

                    if (employeeData['barcode'] != null &&
                        employeeData['barcode'] != false)
                      _buildInfoCard(
                        icon: Icons.badge_outlined,
                        label: 'Matricule',
                        value: employeeData['barcode'].toString(),
                      ),

                    if (employeeData['company_id'] != null &&
                        employeeData['company_id'] != false)
                      _buildInfoCard(
                        icon: Icons.apartment_outlined,
                        label: 'Société',
                        value: _extractName(employeeData['company_id']),
                      ),

                    if (employeeData['parent_id'] != null &&
                        employeeData['parent_id'] != false)
                      _buildInfoCard(
                        icon: Icons.supervisor_account_outlined,
                        label: 'Manager',
                        value: _extractName(employeeData['parent_id']),
                      ),

                    const SizedBox(height: 20),

                    // Edit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Fonctionnalité de modification à venir'),
                              backgroundColor: Color(0xFF35BF8C),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit),
                        label: Text(localizations.translate('edit_my_info')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF000B58),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(5),
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
                ),
              ],
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
}
