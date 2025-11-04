import 'package:flutter/material.dart';
import '../services/odoo_service.dart';
import '../utils/app_localizations.dart';
import '../widgets/hr_sent_notifications_list.dart';

class HRNotificationsScreen extends StatefulWidget {
  const HRNotificationsScreen({super.key});

  @override
  State<HRNotificationsScreen> createState() => _HRNotificationsScreenState();
}

class _HRNotificationsScreenState extends State<HRNotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<HRSentNotificationsListState> _historyListKey =
      GlobalKey<HRSentNotificationsListState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> _employees = [];
  List<int> _selectedEmployeeIds = [];
  bool _isLoading = true;
  bool _isSending = false;
  String _notificationType = 'all'; // 'all', 'selected', 'department'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEmployees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final employees = await OdooService().getAllEmployees();
      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading employees: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.trim().isEmpty ||
        _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context).translate('fill_all_fields')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      // Determine target employees based on notification type
      List<int> targetEmployeeIds = [];

      switch (_notificationType) {
        case 'all':
          targetEmployeeIds =
              _employees.map((emp) => emp['id'] as int).toList();
          break;
        case 'selected':
          targetEmployeeIds = _selectedEmployeeIds;
          break;
        case 'department':
          // For now, send to all employees (can be enhanced later)
          targetEmployeeIds =
              _employees.map((emp) => emp['id'] as int).toList();
          break;
      }

      if (targetEmployeeIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context).translate('select_employees')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Send notification to each employee
      int successCount = 0;
      for (int employeeId in targetEmployeeIds) {
        try {
          await OdooService().sendNotificationToEmployee(
            employeeId: employeeId,
            title: _titleController.text.trim(),
            message: _messageController.text.trim(),
            type: 'hr_notification',
          );
          successCount++;
        } catch (e) {
          print('Error sending notification to employee $employeeId: $e');
        }
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${AppLocalizations.of(context).translate('notification_sent')} $successCount ${AppLocalizations.of(context).translate('employees')}'),
          backgroundColor: const Color(0xFF35BF8C),
        ),
      );

      // Clear form immediately
      _titleController.clear();
      _messageController.clear();
      _selectedEmployeeIds.clear();
      setState(() {});

      // Refresh history after sending notifications
      // Wait longer to allow Odoo to process and commit all messages to database
      // The delay depends on how many notifications were sent
      final delayMs = targetEmployeeIds.length > 10
          ? 2000 +
              (targetEmployeeIds.length * 100) // More notifications = more time
          : 1500;

      print('⏳ Waiting ${delayMs}ms before refreshing history...');

      Future.delayed(Duration(milliseconds: delayMs), () {
        if (!mounted) return;

        print('🔄 Refreshing history tab...');

        if (_tabController.index == 1) {
          // Already on history tab, refresh it
          _historyListKey.currentState?.refresh();
        } else {
          // Switch to history tab and refresh
          _tabController.animateTo(1);
          // Wait for tab animation to complete, then refresh
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _historyListKey.currentState?.refresh();
            }
          });
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${AppLocalizations.of(context).translate('error')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      key: _scaffoldKey,
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
                    // Back Button
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF000B58).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
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
                            localizations.translate('send_notifications'),
                            style: TextStyle(
                              fontSize: isDesktop ? 16 : 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Tab Bar
              Container(
                margin: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20),
                padding: EdgeInsets.all(isDesktop ? 24 : 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF000B58),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF35BF8C),
                  indicatorWeight: 3,
                  tabs: [
                    Tab(
                      text: localizations.translate('send_notifications'),
                      icon: const Icon(Icons.send),
                    ),
                    Tab(
                      text: 'Historique',
                      icon: const Icon(Icons.history),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Send Notifications Tab
                    SingleChildScrollView(
                      padding:
                          EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Notification Type Selection
                          _buildNotificationTypeSelector(
                              localizations, isDesktop),

                          const SizedBox(height: 24),

                          // Notification Form
                          _buildNotificationForm(localizations, isDesktop),

                          const SizedBox(height: 24),

                          // Employee Selection (if needed)
                          if (_notificationType == 'selected') ...[
                            _buildEmployeeSelector(localizations, isDesktop),
                            const SizedBox(height: 24),
                          ],

                          // Send Button
                          _buildSendButton(localizations, isDesktop),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    // History Tab
                    HRSentNotificationsList(key: _historyListKey),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationTypeSelector(
      AppLocalizations localizations, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.translate('notification_type'),
            style: TextStyle(
              fontSize: isDesktop ? 20 : 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF000B58),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTypeOption(
                  'all',
                  localizations.translate('all_employees'),
                  Icons.people,
                  isDesktop,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTypeOption(
                  'selected',
                  localizations.translate('selected_employees'),
                  Icons.person_add,
                  isDesktop,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(
      String value, String title, IconData icon, bool isDesktop) {
    final isSelected = _notificationType == value;
    return GestureDetector(
      onTap: () => setState(() => _notificationType = value),
      child: Container(
        padding: EdgeInsets.all(isDesktop ? 16 : 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF35BF8C) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF35BF8C) : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: isDesktop ? 24 : 20,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: isDesktop ? 14 : 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationForm(
      AppLocalizations localizations, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.translate('notification_details'),
            style: TextStyle(
              fontSize: isDesktop ? 20 : 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF000B58),
            ),
          ),
          const SizedBox(height: 20),

          // Title Field
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: localizations.translate('notification_title'),
              hintText: localizations.translate('enter_title'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.title),
            ),
          ),

          const SizedBox(height: 16),

          // Message Field
          TextField(
            controller: _messageController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: localizations.translate('message'),
              hintText: localizations.translate('enter_message'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.message),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeSelector(
      AppLocalizations localizations, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                localizations.translate('select_employees'),
                style: TextStyle(
                  fontSize: isDesktop ? 20 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF000B58),
                ),
              ),
              Text(
                '${_selectedEmployeeIds.length} ${localizations.translate('selected')}',
                style: TextStyle(
                  fontSize: isDesktop ? 14 : 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: _employees.length,
                itemBuilder: (context, index) {
                  final employee = _employees[index];
                  final employeeId = employee['id'] as int;
                  final isSelected = _selectedEmployeeIds.contains(employeeId);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? const Color(0xFF35BF8C)
                          : Colors.grey[300],
                      child: Icon(
                        Icons.person,
                        color: isSelected ? Colors.white : Colors.grey[600],
                      ),
                    ),
                    title: Text(
                      employee['name']?.toString() ?? 'Unknown',
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? const Color(0xFF35BF8C)
                            : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      employee['job_id'] is List
                          ? employee['job_id'][1].toString()
                          : 'No position',
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF35BF8C)
                            : Colors.grey[600],
                      ),
                    ),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedEmployeeIds.add(employeeId);
                          } else {
                            _selectedEmployeeIds.remove(employeeId);
                          }
                        });
                      },
                      activeColor: const Color(0xFF35BF8C),
                    ),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedEmployeeIds.remove(employeeId);
                        } else {
                          _selectedEmployeeIds.add(employeeId);
                        }
                      });
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSendButton(AppLocalizations localizations, bool isDesktop) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSending ? null : _sendNotification,
        icon: _isSending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.send),
        label: Text(
          _isSending
              ? localizations.translate('sending')
              : localizations.translate('send_notification'),
          style: TextStyle(
            fontSize: isDesktop ? 16 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF35BF8C),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            vertical: isDesktop ? 16 : 12,
            horizontal: isDesktop ? 24 : 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
        ),
      ),
    );
  }
}
