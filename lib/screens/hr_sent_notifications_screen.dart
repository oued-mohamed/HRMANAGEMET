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

      // Group notifications that were sent to all employees
      final groupedNotifications = _groupNotifications(notifications);

      setState(() {
        _sentNotifications = groupedNotifications;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading sent notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  // Group notifications that were sent to all employees
  // If multiple notifications have the same subject and were sent at the same time (within 1 minute),
  // and there are more than 5 of them, group them into a single entry
  List<Map<String, dynamic>> _groupNotifications(
      List<Map<String, dynamic>> notifications) {
    if (notifications.isEmpty) return [];

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final List<Map<String, dynamic>> result = [];

    // Group notifications by subject and time window (same minute)
    for (var notification in notifications) {
      final subject = notification['subject']?.toString() ?? 'Sans titre';
      final createDate = notification['create_date']?.toString();

      if (createDate == null || createDate == false) {
        // If no date, treat as individual notification
        result.add(notification);
        continue;
      }

      try {
        final date = DateTime.parse(createDate);
        // Create a key based on subject and minute (ignore seconds)
        final key =
            '${subject}_${date.year}_${date.month}_${date.day}_${date.hour}_${date.minute}';

        if (!grouped.containsKey(key)) {
          grouped[key] = [];
        }
        grouped[key]!.add(notification);
      } catch (e) {
        // If date parsing fails, treat as individual notification
        result.add(notification);
      }
    }

    // Process groups
    for (var entry in grouped.entries) {
      final group = entry.value;

      if (group.length > 5) {
        // This looks like a notification sent to all employees
        // Create a single merged notification entry
        final firstNotification = group.first;

        // Use the first notification's date (most recent)
        final mergedNotification = Map<String, dynamic>.from(firstNotification);

        // Combine all partner_ids from all notifications in the group
        final allPartnerIds = <int>{};
        for (var notif in group) {
          final partnerIds = notif['partner_ids'];
          if (partnerIds != null && partnerIds != false) {
            if (partnerIds is List) {
              // Extract IDs from Odoo command format or simple list
              if (partnerIds.length >= 3 &&
                  partnerIds[0] == 6 &&
                  partnerIds[1] == 0 &&
                  partnerIds[2] is List) {
                final idsList = partnerIds[2] as List;
                for (var id in idsList) {
                  if (id is int) allPartnerIds.add(id);
                }
              } else if (partnerIds.isNotEmpty) {
                for (var item in partnerIds) {
                  if (item is int) {
                    allPartnerIds.add(item);
                  } else if (item is List &&
                      item.isNotEmpty &&
                      item[0] is int) {
                    allPartnerIds.add(item[0] as int);
                  }
                }
              }
            }
          }
        }

        // Set combined partner_ids in Odoo command format
        mergedNotification['partner_ids'] = [6, 0, allPartnerIds.toList()];

        result.add(mergedNotification);
      } else {
        // Less than 5 notifications with same subject/time - treat as individual
        result.addAll(group);
      }
    }

    // Sort by date descending (most recent first)
    result.sort((a, b) {
      final dateA = a['create_date']?.toString() ?? '';
      final dateB = b['create_date']?.toString() ?? '';
      if (dateA.isEmpty || dateB.isEmpty) return 0;
      try {
        final dtA = DateTime.parse(dateA);
        final dtB = DateTime.parse(dateB);
        return dtB.compareTo(dtA);
      } catch (e) {
        return 0;
      }
    });

    return result;
  }

  // Count recipients to determine if sent to all or specific employees
  String _getRecipientInfo(Map<String, dynamic> notification) {
    final partnerIds = notification['partner_ids'];

    if (partnerIds == null || partnerIds == false) {
      return 'Aucun destinataire';
    }

    int count = 0;

    if (partnerIds is List) {
      // Check if it's Odoo command format [6, 0, [id1, id2, ...]]
      if (partnerIds.length >= 3 &&
          partnerIds[0] == 6 &&
          partnerIds[1] == 0 &&
          partnerIds[2] is List) {
        // Odoo command format: extract IDs from third element
        final idsList = partnerIds[2] as List;
        count = idsList.length;
      } else if (partnerIds.isNotEmpty) {
        // Simple list format: could be list of IDs or list of [id, name] tuples
        // Check if first element is a list (tuple format)
        if (partnerIds[0] is List) {
          count = partnerIds.length;
        } else {
          // Assume it's a list of IDs
          count = partnerIds.length;
        }
      }
    }

    if (count == 0) {
      return 'Aucun destinataire';
    } else if (count > 5) {
      // When sent to many recipients (>5), assume it's "all employees"
      return 'Envoyé à tous les employés';
    } else {
      return '$count destinataire${count > 1 ? 's' : ''}';
    }
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
                                      .contains('Envoyé à tous les employés');

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
