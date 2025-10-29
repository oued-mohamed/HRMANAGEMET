import 'package:flutter/material.dart';
import '../services/odoo_service.dart';
import '../utils/app_localizations.dart';
import '../widgets/hr_drawer.dart';

class HRSentNotificationsScreen extends StatefulWidget {
  const HRSentNotificationsScreen({super.key});

  @override
  State<HRSentNotificationsScreen> createState() =>
      _HRSentNotificationsScreenState();
}

class _HRSentNotificationsScreenState extends State<HRSentNotificationsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final OdooService _odooService = OdooService();
  List<Map<String, dynamic>> _sentNotifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSentNotifications();
  }

  Future<void> _loadSentNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await _odooService.getSentNotifications();
      setState(() {
        _sentNotifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading sent notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  // Count recipients to determine if sent to all or specific employees
  String _getRecipientInfo(Map<String, dynamic> notification) {
    final partnerIds = notification['partner_ids'];
    if (partnerIds is List && partnerIds.isNotEmpty) {
      final count = partnerIds.length;
      // If more than 5 recipients, likely sent to all employees
      if (count > 5) {
        return 'Tous les employés ($count destinataires)';
      } else {
        return 'Employés sélectionnés ($count destinataires)';
      }
    }
    return 'Aucun destinataire';
  }

  // Format date
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr == false) return 'Date inconnue';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      key: _scaffoldKey,
      drawer: HRDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF000B58), // Deep navy blue
              Color(0xFF35BF8C), // Teal green
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                margin: EdgeInsets.fromLTRB(
                  isDesktop ? 32 : 20,
                  20,
                  isDesktop ? 32 : 20,
                  0,
                ),
                padding: EdgeInsets.all(isDesktop ? 24 : 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Menu Button
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF000B58).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                        icon: const Icon(
                          Icons.menu,
                          color: Color(0xFF000B58),
                          size: 24,
                        ),
                      ),
                    ),
                    SizedBox(width: isDesktop ? 20 : 16),
                    // Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.translate('notifications'),
                            style: TextStyle(
                              fontSize: isDesktop ? 28 : 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF000B58),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Historique des notifications envoyées',
                            style: TextStyle(
                              fontSize: isDesktop ? 16 : 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Refresh Button
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF35BF8C).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: _loadSentNotifications,
                        icon: const Icon(
                          Icons.refresh,
                          color: Color(0xFF35BF8C),
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Content
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _sentNotifications.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications_outlined,
                                    size: 80,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Aucune notification envoyée',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadSentNotifications,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _sentNotifications.length,
                                itemBuilder: (context, index) {
                                  final notification =
                                      _sentNotifications[index];
                                  final subject =
                                      notification['subject']?.toString() ??
                                          'Sans titre';
                                  final body =
                                      notification['body']?.toString() ?? '';
                                  final date = _formatDate(
                                      notification['create_date']?.toString());
                                  final recipientInfo =
                                      _getRecipientInfo(notification);

                                  final isAllEmployees = recipientInfo
                                      .contains('Tous les employés');

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(16),
                                      leading: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isAllEmployees
                                              ? const Color(0xFF35BF8C)
                                                  .withOpacity(0.1)
                                              : const Color(0xFF000B58)
                                                  .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          isAllEmployees
                                              ? Icons.people
                                              : Icons.person,
                                          color: isAllEmployees
                                              ? const Color(0xFF35BF8C)
                                              : const Color(0xFF000B58),
                                          size: 24,
                                        ),
                                      ),
                                      title: Text(
                                        subject,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Color(0xFF2d3436),
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          if (body.isNotEmpty)
                                            Text(
                                              body.length > 100
                                                  ? '${body.substring(0, 100)}...'
                                                  : body,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 13,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                isAllEmployees
                                                    ? Icons.people
                                                    : Icons.person,
                                                size: 14,
                                                color: isAllEmployees
                                                    ? const Color(0xFF35BF8C)
                                                    : const Color(0xFF000B58),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                recipientInfo,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isAllEmployees
                                                      ? const Color(0xFF35BF8C)
                                                      : const Color(0xFF000B58),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                date,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
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
}
