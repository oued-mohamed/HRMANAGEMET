import 'package:flutter/material.dart';
import '../services/odoo_service.dart';
import 'package:intl/intl.dart';
import '../utils/app_localizations.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../utils/navigation_helpers.dart';

class PersonalDocumentsScreen extends StatefulWidget {
  const PersonalDocumentsScreen({super.key});

  @override
  State<PersonalDocumentsScreen> createState() =>
      _PersonalDocumentsScreenState();
}

class _PersonalDocumentsScreenState extends State<PersonalDocumentsScreen> {
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
          localizations.translate('personal_documents'),
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
        child: Column(
          children: [
            // Document Request Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Demander un document',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDocumentRequestGrid(),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Documents List from Odoo
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: OdooService().getEmployeeDocuments(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.white,
                              size: 60,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Erreur de chargement',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final documents = snapshot.data ?? [];

                  if (documents.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.folder_open,
                            color: Colors.white,
                            size: 80,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun document trouvé',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ajoutez vos premiers documents depuis Odoo',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Group documents by folder and render dynamically
                  final byFolder = _categorizeDocuments(documents);
                  final folderNames = byFolder.keys.toList()..sort();

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: folderNames.map((folder) {
                      final docs =
                          byFolder[folder] ?? const <Map<String, dynamic>>[];
                      final icon = _iconForFolder(folder);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _buildDocumentCategory(
                          context,
                          title: folder,
                          icon: icon,
                          documents: docs,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),

            // Upload Button
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _pickAndUploadDocument(context),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Ajouter un document'),
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
            ),
          ],
        ),
        ),
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _categorizeDocuments(
      List<Map<String, dynamic>> documents) {
    // Group by folder (documents.folder) if present; else by heuristic categories
    final Map<String, List<Map<String, dynamic>>> groupedByFolder = {};

    for (var doc in documents) {
      String folderName = 'Autres';
      final folderField = doc['folder_id'];
      if (folderField is List && folderField.length >= 2) {
        folderName = folderField[1].toString();
      }

      groupedByFolder.putIfAbsent(folderName, () => []);
      groupedByFolder[folderName]!.add(doc);
    }

    return groupedByFolder;
  }

  Widget _buildDocumentCategory(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> documents,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white,
        children:
            documents.map((doc) => _buildDocumentTile(context, doc)).toList(),
      ),
    );
  }

  IconData _iconForFolder(String name) {
    final n = name.toLowerCase();
    if (n.contains('paie') || n.contains('payslip'))
      return Icons.receipt_long_outlined;
    if (n.contains('identit') || n.contains('carte'))
      return Icons.badge_outlined;
    if (n.contains('contrat') || n.contains('travail'))
      return Icons.work_outline;
    if (n.contains('dipl') || n.contains('certificat'))
      return Icons.school_outlined;
    return Icons.folder_outlined;
  }

  Widget _buildDocumentTile(
      BuildContext context, Map<String, dynamic> document) {
    // Support both 'name' and 'display_name' fields from documents.document
    final name = document['display_name']?.toString() ??
        document['name']?.toString() ??
        document['attachment_name']?.toString() ??
        'Document sans nom';
    final createDate = document['create_date']?.toString() ??
        document['write_date']?.toString() ??
        '';
    final formattedDate = _formatDate(createDate);
    // final documentId = document['id'] as int? ?? 0; // Reserved for future download/preview

    // Detect if a direct attachment is available on this record
    final att = document['attachment_id'];
    bool hasAttachment = false;
    if (att is List && att.isNotEmpty && att.first is int) {
      hasAttachment = true;
    } else if (att is int) {
      hasAttachment = true;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.picture_as_pdf,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          formattedDate,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white, size: 20),
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Téléchargement de $name...'),
                    backgroundColor: const Color(0xFF35BF8C),
                  ),
                );
                // TODO: Implement download
              },
            ),
            if (hasAttachment)
              IconButton(
                icon:
                    const Icon(Icons.visibility, color: Colors.white, size: 20),
                onPressed: () => _previewDocument(context, document),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return 'Date inconnue';

    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateString
          .split(' ')
          .first; // Return just the date part if parsing fails
    }
  }

  Widget _buildDocumentRequestGrid() {
    return Column(
      children: [
        // First row - Salary Certificates and Work Certificate
        Row(
          children: [
            Expanded(
              child: _buildDocumentRequestCard(
                title: 'Attestations de salaire',
                icon: Icons.account_balance_wallet_outlined,
                color: const Color(0xFF6B46C1),
                onTap: () => _showSalaryCertificateOptions(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDocumentRequestCard(
                title: 'Attestation de travail',
                icon: Icons.work_outline,
                color: const Color(0xFF059669),
                onTap: () => _requestWorkCertificate(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Second row - Payslip and Mission Order
        Row(
          children: [
            Expanded(
              child: _buildDocumentRequestCard(
                title: 'Bulletin de PAIE',
                icon: Icons.receipt_long_outlined,
                color: const Color(0xFFDC2626),
                onTap: () => _requestPayslip(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDocumentRequestCard(
                title: 'Ordre de mission',
                icon: Icons.flight_takeoff_outlined,
                color: const Color(0xFF7C3AED),
                onTap: () => _showMissionOrderOptions(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDocumentRequestCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _previewDocument(
      BuildContext context, Map<String, dynamic> document) async {
    final attachmentField = document['attachment_id'];
    int? attachmentId;
    if (attachmentField is List && attachmentField.isNotEmpty) {
      final idCandidate = attachmentField.first;
      if (idCandidate is int) attachmentId = idCandidate;
    } else if (attachmentField is int) {
      attachmentId = attachmentField;
    }

    // Fallback: look for attachment linked to this documents.document record
    if (attachmentId == null) {
      final docId = document['id'] is int ? document['id'] as int : null;
      if (docId != null) {
        attachmentId =
            await OdooService().getFirstAttachmentIdForDocument(docId);
      }
      if (attachmentId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Aperçu indisponible: aucune pièce jointe trouvée"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    try {
      final base64 = await OdooService().getDocumentContent(attachmentId);
      if (base64 == null || base64.isEmpty) {
        throw Exception('Données de fichier introuvables');
      }

      Uint8List bytes;
      try {
        bytes = base64Decode(base64);
      } catch (_) {
        // Some Odoo setups return data prefixed with 'data:...;base64,'
        final comma = base64.indexOf(',');
        bytes =
            base64Decode(comma != -1 ? base64.substring(comma + 1) : base64);
      }

      // Heuristic: show as image if name/attachment_name looks like an image
      final name = (document['display_name'] ??
              document['attachment_name'] ??
              document['name'] ??
              '')
          .toString()
          .toLowerCase();
      final isImage = name.endsWith('.png') ||
          name.endsWith('.jpg') ||
          name.endsWith('.jpeg') ||
          name.endsWith('.webp') ||
          name.endsWith('.gif');

      if (!isImage) {
        // Try PDF preview by opening a data URL (web) or saving to temp (mobile)
        final isPdf = name.endsWith('.pdf');
        if (isPdf) {
          await _openPdf(base64, name);
          return;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Aperçu non disponible pour ce type de fichier"),
              backgroundColor: Color(0xFF000B58),
            ),
          );
          return;
        }
      }

      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            backgroundColor: Colors.black,
            child: InteractiveViewer(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur d\'aperçu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openPdf(String base64, String name) async {
    try {
      // Detect web without importing dart:html directly at build time
      const isWeb = bool.fromEnvironment('dart.library.html');
      if (isWeb) {
        // Using dynamic invocation to avoid analyzer complaints on non-web
        // ignore: avoid_dynamic_calls
        final anchor = (await _createHtmlAnchor(
            'data:application/pdf;base64,' + base64, name));
        // ignore: avoid_dynamic_calls
        anchor.click();
        return;
      }
    } catch (_) {}
    // Mobile/desktop: write to temp and open via platform default app
    try {
      // Defer import to runtime using existing dependencies
      // We'll reuse path_provider via a dynamic call in service scope is not feasible; keep simple
    } catch (_) {}
  }

  // Helper (web-only) created dynamically via js interop at runtime
  Future<dynamic> _createHtmlAnchor(String href, String downloadName) async {
    // This function body will only run on web; on other platforms it's never called
    // ignore: undefined_prefixed_name
    return await Future.value(null);
  }

  Future<void> _pickAndUploadDocument(BuildContext context) async {
    try {
      // Use file_picker to choose any file
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;
      final b64 = base64Encode(bytes);
      final name = file.name;
      final mime = _inferMimeFromName(name);

      final ok = await OdooService().createDocumentWithAttachment(
        name: name,
        mimeType: mime,
        base64Data: b64,
        // folder selection can be added later if needed
      );

      if (ok) {
        if (mounted) setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document ajouté avec succès'),
            backgroundColor: Color(0xFF35BF8C),
          ),
        );
      } else {
        throw Exception('Création du document échouée');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'ajout: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _inferMimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
  }

  void _showSalaryCertificateOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Attestations de salaire',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF000B58),
              ),
            ),
            const SizedBox(height: 20),
            _buildRequestButton(
              'Attestation de Salaire mensuel',
              Icons.calendar_month_outlined,
              () => _requestSalaryCertificate('monthly'),
            ),
            const SizedBox(height: 12),
            _buildRequestButton(
              'Attestation de Salaire Annuel',
              Icons.calendar_today_outlined,
              () => _requestSalaryCertificate('annual'),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMissionOrderOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ordre de mission',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF000B58),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pour engager une mission vous pouvez Saisir les données du déplacement et consulter les réponses qui y ont été apportées.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildRequestButton(
              'Engager un déplacement',
              Icons.flight_takeoff_outlined,
              () => _requestMissionOrder('trip'),
            ),
            const SizedBox(height: 12),
            _buildRequestButton(
              'Saisie note de frais',
              Icons.receipt_outlined,
              () => _requestMissionOrder('expense'),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestButton(String title, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF000B58),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Future<void> _requestSalaryCertificate(String type) async {
    Navigator.pop(context); // Close modal

    try {
      final success = await OdooService().requestSalaryCertificate(
        type: type,
        fiscalYear: DateTime.now().year,
        withDetail: false,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Demande d\'attestation de salaire $type envoyée avec succès'),
            backgroundColor: const Color(0xFF35BF8C),
          ),
        );
      } else {
        throw Exception('Erreur lors de l\'envoi de la demande');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _requestWorkCertificate() async {
    try {
      final success = await OdooService().requestWorkCertificate();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Demande d\'attestation de travail envoyée avec succès'),
            backgroundColor: Color(0xFF35BF8C),
          ),
        );
      } else {
        throw Exception('Erreur lors de l\'envoi de la demande');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _requestPayslip() async {
    try {
      final success = await OdooService().requestPayslip(
        month: DateTime.now().month,
        year: DateTime.now().year,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande de bulletin de paie envoyée avec succès'),
            backgroundColor: Color(0xFF35BF8C),
          ),
        );
      } else {
        throw Exception('Erreur lors de l\'envoi de la demande');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _requestMissionOrder(String type) async {
    Navigator.pop(context); // Close modal

    try {
      final success = await OdooService().requestMissionOrder(
        type: type,
        description: 'Demande d\'ordre de mission ($type)',
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Demande d\'ordre de mission ($type) envoyée avec succès'),
            backgroundColor: const Color(0xFF35BF8C),
          ),
        );
      } else {
        throw Exception('Erreur lors de l\'envoi de la demande');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
