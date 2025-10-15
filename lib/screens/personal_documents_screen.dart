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
            // Header Section
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mes documents',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gérez vos documents personnels et professionnels',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
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
}
