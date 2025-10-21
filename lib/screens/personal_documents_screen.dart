import 'package:flutter/material.dart';
import '../services/odoo_service.dart';
import 'package:intl/intl.dart';
import '../utils/app_localizations.dart';

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

    return Scaffold(
      appBar: AppBar(
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

                  // Group documents by category
                  final categorized = _categorizeDocuments(documents);

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      if (categorized['identity']!.isNotEmpty) ...[
                        _buildDocumentCategory(
                          context,
                          title: 'Documents d\'identité',
                          icon: Icons.badge_outlined,
                          documents: categorized['identity']!,
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (categorized['professional']!.isNotEmpty) ...[
                        _buildDocumentCategory(
                          context,
                          title: 'Documents professionnels',
                          icon: Icons.work_outline,
                          documents: categorized['professional']!,
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (categorized['education']!.isNotEmpty) ...[
                        _buildDocumentCategory(
                          context,
                          title: 'Certificats et diplômes',
                          icon: Icons.school_outlined,
                          documents: categorized['education']!,
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (categorized['other']!.isNotEmpty) ...[
                        _buildDocumentCategory(
                          context,
                          title: 'Autres documents',
                          icon: Icons.folder_outlined,
                          documents: categorized['other']!,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
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
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ajoutez des documents depuis Odoo'),
                        backgroundColor: Color(0xFF35BF8C),
                      ),
                    );
                  },
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
    );
  }

  Map<String, List<Map<String, dynamic>>> _categorizeDocuments(
      List<Map<String, dynamic>> documents) {
    final Map<String, List<Map<String, dynamic>>> categorized = {
      'identity': [],
      'professional': [],
      'education': [],
      'other': [],
    };

    for (var doc in documents) {
      final name = (doc['name'] ?? '').toString().toLowerCase();
      final description = (doc['description'] ?? '').toString().toLowerCase();

      if (name.contains('identité') ||
          name.contains('cin') ||
          name.contains('passeport') ||
          name.contains('passport') ||
          name.contains('identity') ||
          description.contains('identity')) {
        categorized['identity']!.add(doc);
      } else if (name.contains('contrat') ||
          name.contains('paie') ||
          name.contains('attestation') ||
          name.contains('contract') ||
          name.contains('salary') ||
          description.contains('professional')) {
        categorized['professional']!.add(doc);
      } else if (name.contains('diplôme') ||
          name.contains('certificat') ||
          name.contains('formation') ||
          name.contains('degree') ||
          name.contains('certificate') ||
          description.contains('education')) {
        categorized['education']!.add(doc);
      } else {
        categorized['other']!.add(doc);
      }
    }

    return categorized;
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

  Widget _buildDocumentTile(
      BuildContext context, Map<String, dynamic> document) {
    final name = document['name']?.toString() ?? 'Document sans nom';
    final createDate = document['create_date']?.toString() ?? '';
    final formattedDate = _formatDate(createDate);
    // final documentId = document['id'] as int? ?? 0; // Reserved for future download/preview

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
            IconButton(
              icon: const Icon(Icons.visibility, color: Colors.white, size: 20),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ouverture de $name...'),
                    backgroundColor: const Color(0xFF35BF8C),
                  ),
                );
                // TODO: Implement preview
              },
            ),
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
