import 'package:flutter/material.dart';

class LastNotificationWidget extends StatelessWidget {
  final Map<String, dynamic>? notification;
  final bool isLoading;
  final String? notificationsRoute;
  final EdgeInsets? margin;

  const LastNotificationWidget({
    super.key,
    required this.notification,
    required this.isLoading,
    this.notificationsRoute = '/employee-notifications',
    this.margin,
  });

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
    // Loading state
    if (isLoading) {
      return Center(
        child: Container(
          margin: margin ?? const EdgeInsets.fromLTRB(16, 20, 16, 16),
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF000B58).withOpacity(0.1),
                const Color(0xFF35BF8C).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF000B58)),
              ),
            ),
          ),
        ),
      );
    }

    // Empty state - show placeholder message
    if (notification == null) {
      return Center(
        child: Container(
          margin: margin ?? const EdgeInsets.fromLTRB(16, 20, 16, 16),
          height: 90,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white,
                Colors.grey[50]!,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.grey[200]!.withOpacity(0.5),
                      Colors.grey[100]!.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.grey[400],
                  size: 28,
                ),
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Aucune notification',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vous n\'avez pas de nouvelles notifications',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Normal state - display notification
    final title = notification!['title']?.toString() ?? 'Notification';
    final message = notification!['message']?.toString() ?? '';
    final isRead = notification!['is_read'] == true;
    final cleanMessage = _stripHtmlTags(message);
    final preview = cleanMessage.length > 90
        ? '${cleanMessage.substring(0, 90)}...'
        : cleanMessage;

    return Center(
      child: Container(
        margin: margin ?? const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(context, notificationsRoute!);
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Main content: Icon + Text
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left circular notification icon
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF35BF8C).withOpacity(0.1),
                          border: Border.all(
                            color: const Color(0xFF35BF8C).withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.notifications_rounded,
                              color: const Color(0xFF35BF8C),
                              size: 28,
                            ),
                            if (!isRead)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Middle section - Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title (main focus)
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Description
                            Text(
                              preview.isNotEmpty
                                  ? preview
                                  : 'Aucun message disponible',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey[600],
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Add space for button on the right
                      const SizedBox(width: 100),
                    ],
                  ),
                  // Button positioned at bottom-right
                  Positioned(
                    right: 8,
                    bottom: 0,
                    child: Transform.translate(
                      offset: const Offset(
                          4, 0), // Move button slightly to the left
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF35BF8C), // Always green
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'VOIR',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
