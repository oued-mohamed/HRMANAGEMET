import 'package:flutter/material.dart';
import '../services/odoo_service.dart';

class HRSentNotificationsList extends StatefulWidget {
  const HRSentNotificationsList({super.key});

  @override
  State<HRSentNotificationsList> createState() =>
      HRSentNotificationsListState();
}

class HRSentNotificationsListState extends State<HRSentNotificationsList> {
  final OdooService _odooService = OdooService();
  List<Map<String, dynamic>> _sentNotifications = [];
  bool _isLoading = true;
  // Cache for partner names: notification_id -> recipient_info
  final Map<int, String> _recipientInfoCache = {};

  @override
  void initState() {
    super.initState();
    _loadSentNotifications();
  }

  // Public method to refresh notifications from parent
  Future<void> refresh() async {
    print('🔄 HRSentNotificationsList: refresh() called');
    await _loadSentNotifications();
  }

  Future<void> _loadSentNotifications() async {
    print('📥 HRSentNotificationsList: Loading sent notifications...');
    setState(() => _isLoading = true);
    try {
      final notifications = await _odooService.getSentNotifications();
      print(
          '✅ HRSentNotificationsList: Loaded ${notifications.length} notifications');

      // Group notifications that were sent to all employees
      final groupedNotifications = _groupNotifications(notifications);
      print(
          '📊 Grouped ${notifications.length} notifications to ${groupedNotifications.length} entries');

      // Preload recipient names for all notifications
      await _preloadRecipientNames(groupedNotifications);

      if (mounted) {
        setState(() {
          _sentNotifications = groupedNotifications;
          _isLoading = false;
        });
        print(
            '✅ HRSentNotificationsList: State updated with ${_sentNotifications.length} notifications');
      }
    } catch (e) {
      print('❌ HRSentNotificationsList: Error loading sent notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        print(
            '📦 Grouped ${group.length} notifications into 1 entry: "${mergedNotification['subject']}"');
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

  // Preload recipient names for all notifications
  Future<void> _preloadRecipientNames(
      List<Map<String, dynamic>> notifications) async {
    final Set<int> allPartnerIds = {};

    // Collect all partner IDs
    for (var notification in notifications) {
      final partnerIds = notification['partner_ids'];
      if (partnerIds != null && partnerIds != false) {
        List<int> idsList = _extractPartnerIds(partnerIds);
        allPartnerIds.addAll(idsList);
      }
    }

    if (allPartnerIds.isEmpty) return;

    // Fetch all partner names in one batch
    try {
      final namesMap =
          await _odooService.getPartnerNames(allPartnerIds.toList());

      // Build recipient info for each notification
      for (var notification in notifications) {
        final notificationId = notification['id'] as int?;
        if (notificationId == null) continue;

        final partnerIds = notification['partner_ids'];
        if (partnerIds == null || partnerIds == false) {
          _recipientInfoCache[notificationId] = 'Aucun destinataire';
          continue;
        }

        final idsList = _extractPartnerIds(partnerIds);
        if (idsList.isEmpty) {
          _recipientInfoCache[notificationId] = 'Aucun destinataire';
        } else if (idsList.length > 5) {
          _recipientInfoCache[notificationId] = 'Envoyé à tous les employés';
        } else {
          // Get names for these IDs
          final names = idsList
              .map((id) => namesMap[id] ?? 'Inconnu')
              .where((name) => name != 'Inconnu')
              .toList();

          if (names.isEmpty) {
            _recipientInfoCache[notificationId] =
                '${idsList.length} destinataire${idsList.length > 1 ? 's' : ''}';
          } else if (names.length == 1) {
            _recipientInfoCache[notificationId] = names.first;
          } else if (names.length <= 3) {
            _recipientInfoCache[notificationId] = names.join(', ');
          } else {
            _recipientInfoCache[notificationId] =
                '${names.take(2).join(', ')} et ${names.length - 2} autre${names.length - 2 > 1 ? 's' : ''}';
          }
        }
      }
    } catch (e) {
      print('Error preloading recipient names: $e');
    }
  }

  // Extract partner IDs from various formats
  List<int> _extractPartnerIds(dynamic partnerIds) {
    final List<int> idsList = [];

    if (partnerIds is List) {
      // Check if it's Odoo command format [6, 0, [id1, id2, ...]]
      if (partnerIds.length >= 3 &&
          partnerIds[0] == 6 &&
          partnerIds[1] == 0 &&
          partnerIds[2] is List) {
        // Odoo command format: extract IDs from third element
        final ids = partnerIds[2] as List;
        for (var id in ids) {
          if (id is int) idsList.add(id);
        }
      } else if (partnerIds.isNotEmpty) {
        // Simple list format: could be list of IDs or list of [id, name] tuples
        for (var item in partnerIds) {
          if (item is int) {
            idsList.add(item);
          } else if (item is List && item.isNotEmpty && item[0] is int) {
            idsList.add(item[0] as int);
          }
        }
      }
    }

    return idsList;
  }

  // Get recipient info with names (now uses cache)
  String _getRecipientInfo(Map<String, dynamic> notification) {
    final notificationId = notification['id'] as int?;
    if (notificationId != null &&
        _recipientInfoCache.containsKey(notificationId)) {
      return _recipientInfoCache[notificationId]!;
    }

    // Fallback if cache not ready yet
    final partnerIds = notification['partner_ids'];
    if (partnerIds == null || partnerIds == false) {
      return 'Aucun destinataire';
    }

    final idsList = _extractPartnerIds(partnerIds);
    if (idsList.isEmpty) {
      return 'Aucun destinataire';
    } else if (idsList.length > 5) {
      return 'Envoyé à tous les employés';
    } else {
      return '${idsList.length} destinataire${idsList.length > 1 ? 's' : ''}';
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

  // Helper to strip HTML tags from notification message
  String _stripHtmlTags(String htmlString) {
    if (htmlString.isEmpty) return '';

    String text = htmlString.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return text;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sentNotifications.isEmpty) {
      return Center(
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
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSentNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sentNotifications.length,
        itemBuilder: (context, index) {
          final notification = _sentNotifications[index];
          final subject = notification['subject']?.toString() ?? 'Sans titre';
          final bodyRaw = notification['body']?.toString() ?? '';
          final body = _stripHtmlTags(bodyRaw); // Clean HTML tags
          final date = _formatDate(notification['create_date']?.toString());
          final recipientInfo = _getRecipientInfo(notification);

          final isAllEmployees =
              recipientInfo.contains('Envoyé à tous les employés');

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
                      ? const Color(0xFF35BF8C).withOpacity(0.1)
                      : const Color(0xFF000B58).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isAllEmployees ? Icons.people : Icons.person,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  if (body.isNotEmpty)
                    Text(
                      body.length > 100 ? '${body.substring(0, 100)}...' : body,
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
                        isAllEmployees ? Icons.people : Icons.person,
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
    );
  }
}
