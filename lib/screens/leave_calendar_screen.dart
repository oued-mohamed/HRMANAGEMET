import 'package:flutter/material.dart';
import '../utils/navigation_helpers.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/leave_provider.dart';

class LeaveCalendarScreen extends StatefulWidget {
  const LeaveCalendarScreen({super.key});

  @override
  State<LeaveCalendarScreen> createState() => _LeaveCalendarScreenState();
}

class _LeaveCalendarScreenState extends State<LeaveCalendarScreen> {
  DateTime _selectedDay = DateTime.now();
  List<Map<String, dynamic>> _selectedDayLeaves = [];
  bool _isSelectedDayHoliday = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    print('⭐️⭐️⭐️ _loadData() called ⭐️⭐️⭐️');
    final leaveProvider = context.read<LeaveProvider>();
    final year = DateTime.now().year;

    try {
      await leaveProvider.loadHolidays(year);
      print('✅ loadHolidays completed');
    } catch (e) {
      print('❌ loadHolidays failed: $e');
    }

    try {
      await leaveProvider.loadApprovedLeaves(year);
      print('✅ loadApprovedLeaves completed');
    } catch (e) {
      print('❌ loadApprovedLeaves failed: $e');
    }

    try {
      await leaveProvider.loadPendingLeaves(year);
      print('✅ loadPendingLeaves completed');
    } catch (e) {
      print('❌ loadPendingLeaves failed: $e');
    }

    try {
      await leaveProvider.loadMoroccanHolidays(year);
      print('✅ loadMoroccanHolidays completed');
    } catch (e) {
      print('❌ loadMoroccanHolidays failed: $e');
    }

    try {
      await leaveProvider.loadLeaveTypes();
      print('✅ loadLeaveTypes completed');
    } catch (e) {
      print('❌ loadLeaveTypes failed: $e');
    }

    print('⭐️⭐️⭐️ _loadData() finished ⭐️⭐️⭐️');
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Helper method to extract employee name from employee_id field
  String _getEmployeeName(dynamic employeeId) {
    if (employeeId == null) return 'Inconnu';

    // In Odoo, employee_id is typically a tuple [id, "Employee Name"]
    if (employeeId is List && employeeId.length >= 2) {
      return employeeId[1].toString();
    }

    // If it's just a string, return it
    if (employeeId is String) {
      return employeeId;
    }

    // If it's just an ID, return a generic name
    return 'Employé #$employeeId';
  }

  void _showLeaveInfoForDate(
      BuildContext context, LeaveProvider leaveProvider, DateTime date) {
    final approvedLeaves = leaveProvider.approvedLeaves ?? [];
    final pendingLeaves = leaveProvider.pendingLeaves ?? [];
    final holidays = leaveProvider.holidays ?? [];
    final moroccanHolidays = leaveProvider.moroccanHolidays ?? [];
    final dayOnly = DateTime.utc(date.year, date.month, date.day);

    print('========================================');
    print('Clicked on date: ${date.day}/${date.month}/${date.year}');
    print('Total approved leaves: ${approvedLeaves.length}');
    print('Total pending leaves: ${pendingLeaves.length}');
    print('========================================');

    // Check if it's a holiday
    final isHoliday = holidays.any((h) => _isSameDate(h, dayOnly)) ||
        moroccanHolidays.any((h) => _isSameDate(h, dayOnly));

    if (isHoliday) {
      print('This is a holiday!');
    }

    // Find leaves that include this date
    List<Map<String, dynamic>> leavesOnThisDate = [];

    // Check approved leaves
    for (var i = 0; i < approvedLeaves.length; i++) {
      var leave = approvedLeaves[i];
      if (_isDateInLeaveRange(leave, dayOnly)) {
        leavesOnThisDate.add({...leave, 'status': 'approved'});
        print('✅ Found approved leave: ${leave['name']}');
      }
    }

    // Check pending leaves
    for (var i = 0; i < pendingLeaves.length; i++) {
      var leave = pendingLeaves[i];
      if (_isDateInLeaveRange(leave, dayOnly)) {
        leavesOnThisDate.add({...leave, 'status': 'pending'});
        print('✅ Found pending leave: ${leave['name']}');
      }
    }

    // Debug: Print all pending leaves for comparison
    print('🔍 CLICK DEBUG: All pending leaves in system:');
    for (var i = 0; i < pendingLeaves.length; i++) {
      var leave = pendingLeaves[i];
      print(
          '  Leave $i: ${leave['name']} - ${leave['date_from']} to ${leave['date_to']}');
    }

    print(
        '🔍 Final result: ${leavesOnThisDate.length} leaves found for this date');

    // Update state to show details at bottom instead of navigating
    setState(() {
      _selectedDayLeaves = leavesOnThisDate;
      _isSelectedDayHoliday = isHoliday;
    });
  }

  bool _isDateInLeaveRange(Map<String, dynamic> leave, DateTime date) {
    try {
      dynamic dateFromValue = leave['date_from'];
      dynamic dateToValue = leave['date_to'];

      if (dateFromValue == null || dateToValue == null) {
        print('  ERROR: date_from or date_to is null');
        return false;
      }

      // Parse dates more robustly
      DateTime dateFrom;
      DateTime dateTo;

      if (dateFromValue is String) {
        // Remove time component and parse only date part
        String dateStr = dateFromValue.split(' ')[0].split('T')[0];
        dateFrom = DateTime.parse(dateStr);
      } else {
        print(
            '  ERROR: date_from is not a string: ${dateFromValue.runtimeType}');
        return false;
      }

      if (dateToValue is String) {
        // Remove time component and parse only date part
        String dateStr = dateToValue.split(' ')[0].split('T')[0];
        dateTo = DateTime.parse(dateStr);
      } else {
        print('  ERROR: date_to is not a string: ${dateToValue.runtimeType}');
        return false;
      }

      // Normalize ALL dates to midnight UTC to avoid timezone issues
      final dayOnly = DateTime.utc(date.year, date.month, date.day);
      final leaveFromOnly =
          DateTime.utc(dateFrom.year, dateFrom.month, dateFrom.day);
      final leaveToOnly = DateTime.utc(dateTo.year, dateTo.month, dateTo.day);

      // Check if date is within range (inclusive)
      final isInRange = (dayOnly.isAtSameMomentAs(leaveFromOnly) ||
              dayOnly.isAfter(leaveFromOnly)) &&
          (dayOnly.isAtSameMomentAs(leaveToOnly) ||
              dayOnly.isBefore(leaveToOnly));

      // Debug logging - seulement pour les jours problématiques
      final problematicDays = <int>{8, 9, 13, 14, 20, 21};
      if (problematicDays.contains(date.day)) {
        print('🔍 Day ${date.day}/${date.month}/${date.year}');
        print('  Leave: ${leave['name']}');
        print('  From: $leaveFromOnly');
        print('  To: $leaveToOnly');
        print('  Checking: $dayOnly');
        print('  Result: $isInRange');
      }

      return isInRange;
    } catch (e) {
      print('  ERROR parsing leave dates: $e');
      print('  Leave data: ${leave['date_from']} to ${leave['date_to']}');
      return false;
    }
  }

  /// Optimise la vérification des jours en créant un cache intelligent
  Map<int, Map<String, bool>> _buildDayCache(
    DateTime firstDayOfMonth,
    DateTime lastDayOfMonth,
    List<Map<String, dynamic>> approvedLeaves,
    List<Map<String, dynamic>> pendingLeaves,
    List<DateTime> holidays,
    List<DateTime> moroccanHolidays,
  ) {
    final Map<int, Map<String, bool>> cache = {};

    // Debug seulement pour les jours problématiques
    final problematicDays = <int>{8, 9, 13, 14, 20, 21};

    print(
        '🔍 BUILDING DAY CACHE - Month: ${firstDayOfMonth.month}/${firstDayOfMonth.year}');
    print('🔍 Pending leaves count: ${pendingLeaves.length}');
    for (var i = 0; i < pendingLeaves.length; i++) {
      var leave = pendingLeaves[i];
      print(
          '  Pending leave $i: ${leave['name']} - ${leave['date_from']} to ${leave['date_to']}');
    }

    // Créer des intervalles optimisés pour les congés
    final List<Map<String, dynamic>> allLeaves = [
      ...approvedLeaves.map((leave) => {...leave, 'type': 'approved'}),
      ...pendingLeaves.map((leave) => {...leave, 'type': 'pending'}),
    ];

    // Parcourir chaque jour du mois
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(firstDayOfMonth.year, firstDayOfMonth.month, day);
      final dayOnly = DateTime.utc(date.year, date.month, date.day);

      bool hasApprovedLeave = false;
      bool hasPendingLeave = false;
      bool isHoliday = holidays.any((h) => _isSameDate(h, dayOnly)) ||
          moroccanHolidays.any((h) => _isSameDate(h, dayOnly));

      // Vérifier seulement les congés qui peuvent affecter ce jour
      for (var leave in allLeaves) {
        if (_isDateInLeaveRange(leave, dayOnly)) {
          if (leave['type'] == 'approved') {
            hasApprovedLeave = true;
          } else {
            hasPendingLeave = true;
          }

          // Debug intelligent: seulement pour les jours problématiques
          if (problematicDays.contains(day)) {
            print(
                '🔍 Day $day: Found ${leave['type']} leave: ${leave['name']} (${leave['date_from']} to ${leave['date_to']})');
          }
        }
      }

      cache[day] = {
        'hasApprovedLeave': hasApprovedLeave,
        'hasPendingLeave': hasPendingLeave,
        'isHoliday': isHoliday,
      };
    }

    print(
        '🔍 CACHE BUILT - Days with pending leaves: ${cache.entries.where((e) => e.value['hasPendingLeave']!).map((e) => e.key).toList()}');
    print('🔍 ✅ CODE UPDATED - Using correct cache logic!');

    return cache;
  }

  /// Custom calendar that looks like CalendarDatePicker but with correct indicators
  Widget _buildCustomCalendarDatePicker(LeaveProvider leaveProvider) {
    final approvedLeaves = leaveProvider.approvedLeaves ?? [];
    final pendingLeaves = leaveProvider.pendingLeaves ?? [];
    final holidays = leaveProvider.holidays ?? [];
    final moroccanHolidays = leaveProvider.moroccanHolidays ?? [];

    final currentMonth = DateTime(_selectedDay.year, _selectedDay.month);
    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final lastDayOfMonth =
        DateTime(currentMonth.year, currentMonth.month + 1, 0);
    final firstDayWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    // Utiliser notre cache optimisé
    final Map<int, Map<String, bool>> dayCache = _buildDayCache(
      firstDayOfMonth,
      lastDayOfMonth,
      approvedLeaves,
      pendingLeaves,
      holidays,
      moroccanHolidays,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 400;
        final isTablet = screenWidth > 600;

        // Calculate responsive padding and spacing
        final horizontalPadding = isMobile ? 12.0 : (isTablet ? 20.0 : 16.0);
        final verticalPadding = isMobile ? 4.0 : 8.0;
        final headerFontSize = isMobile ? 16.0 : (isTablet ? 20.0 : 18.0);
        final weekdayFontSize = isMobile ? 11.0 : 12.0;

        return Column(
          children: [
            // Month header (like CalendarDatePicker)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Combined Month and Year Selection (Plain Text)
                  GestureDetector(
                    onTap: () => _showMonthYearPicker(context),
                    child: Text(
                      '${_getMonthName(_selectedDay.month)} ${_selectedDay.year}',
                      style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  // Navigation Arrows
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          final prevMonth = DateTime(
                              _selectedDay.year, _selectedDay.month - 1);
                          setState(() => _selectedDay = prevMonth);
                        },
                        icon: Icon(
                          Icons.chevron_left,
                          size: isMobile ? 20 : 24,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          final nextMonth = DateTime(
                              _selectedDay.year, _selectedDay.month + 1);
                          setState(() => _selectedDay = nextMonth);
                        },
                        icon: Icon(
                          Icons.chevron_right,
                          size: isMobile ? 20 : 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Weekday headers (like CalendarDatePicker)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                    .map((day) => Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                    fontSize: weekdayFontSize,
                                  ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),

            SizedBox(height: isMobile ? 4 : 8),

            // Calendar grid (like CalendarDatePicker)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                children: _buildCalendarRows(
                  firstDayWeekday,
                  daysInMonth,
                  currentMonth,
                  dayCache,
                  leaveProvider,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getMonthName(int month) {
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre'
    ];
    return months[month - 1];
  }

  void _showMonthYearPicker(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(10, (index) => currentYear - 5 + index);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sélectionner le mois et l\'année'),
          content: SizedBox(
            width: 300,
            height: 400,
            child: Column(
              children: [
                // Year Selection
                const Text(
                  'Année',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      childAspectRatio: 2,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: years.length,
                    itemBuilder: (context, index) {
                      final year = years[index];
                      final isSelected = year == _selectedDay.year;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDay = DateTime(year, _selectedDay.month);
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF000B58)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF000B58)
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$year',
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Month Selection
                const Text(
                  'Mois',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final month = index + 1;
                      final isSelected = month == _selectedDay.month;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDay = DateTime(_selectedDay.year, month);
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF000B58)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF000B58)
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _getMonthName(month),
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildCalendarRows(
    int firstDayWeekday,
    int daysInMonth,
    DateTime currentMonth,
    Map<int, Map<String, bool>> dayCache,
    LeaveProvider leaveProvider,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 400;
    final isTablet = screenWidth > 600;

    // Calculate responsive dimensions
    final cellHeight = isMobile ? 52.0 : (isTablet ? 68.0 : 60.0);
    final cellMargin = isMobile ? 2.0 : 2.5;
    final borderRadius = isMobile ? 16.0 : 20.0;
    final indicatorSize = isMobile ? 6.0 : 8.0;
    final fontSize = isMobile ? 14.0 : (isTablet ? 17.0 : 15.0);

    List<Widget> rows = [];
    List<Widget> currentRow = [];

    // Add empty cells for days before the first day of the month
    for (int i = 1; i < firstDayWeekday; i++) {
      currentRow.add(Expanded(child: SizedBox(height: cellHeight)));
    }

    // Add days of the month
    for (int day = 1; day <= daysInMonth; day++) {
      final dayData = dayCache[day] ??
          {
            'hasApprovedLeave': false,
            'hasPendingLeave': false,
            'isHoliday': false,
          };

      final hasApprovedLeave = dayData['hasApprovedLeave']!;
      final hasPendingLeave = dayData['hasPendingLeave']!;
      final isHoliday = dayData['isHoliday']!;

      currentRow.add(
        Expanded(
          child: GestureDetector(
            onTap: () {
              final date = DateTime(currentMonth.year, currentMonth.month, day);
              setState(() => _selectedDay = date);
              _showLeaveInfoForDate(context, leaveProvider, date);
            },
            child: Container(
              height: cellHeight,
              margin: EdgeInsets.all(cellMargin),
              decoration: BoxDecoration(
                color: _selectedDay.day == day &&
                        _selectedDay.month == currentMonth.month
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : null,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      day.toString(),
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: _selectedDay.day == day &&
                                _selectedDay.month == currentMonth.month
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _selectedDay.day == day &&
                                _selectedDay.month == currentMonth.month
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  ),
                  // Add visual indicators (correct ones from cache)
                  if (hasPendingLeave)
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        width: indicatorSize,
                        height: indicatorSize,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  if (hasApprovedLeave)
                    Positioned(
                      bottom: 1,
                      right: 1,
                      child: Container(
                        width: indicatorSize,
                        height: indicatorSize,
                        decoration: const BoxDecoration(
                          color: Color(0xFF35BF8C),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  if (isHoliday)
                    Positioned(
                      top: 1,
                      left: 1,
                      child: Container(
                        width: indicatorSize,
                        height: indicatorSize,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

      // Start a new row every 7 days
      if (currentRow.length == 7) {
        rows.add(Row(children: currentRow));
        currentRow = [];
      }
    }

    // Add remaining empty cells for the last row
    while (currentRow.length < 7) {
      currentRow.add(Expanded(child: SizedBox(height: cellHeight)));
    }
    if (currentRow.isNotEmpty) {
      rows.add(Row(children: currentRow));
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 400;

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
        title: const Text('Calendrier des congés - Tous les employés'),
        backgroundColor: const Color(0xFF000B58),
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              SizedBox(height: isMobile ? 8 : 12),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12.0 : 16.0,
                ),
                child: _Legend(),
              ),
              SizedBox(height: isMobile ? 4 : 8),
              Card(
                margin: EdgeInsets.all(isMobile ? 8 : 16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: isMobile ? 4.0 : 8.0,
                  ),
                  child: Consumer<LeaveProvider>(
                    builder: (context, leaveProvider, child) {
                      return Stack(
                        children: [
                          // Custom calendar that looks like CalendarDatePicker but with correct indicators
                          _buildCustomCalendarDatePicker(leaveProvider),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Day Details Section
              Expanded(
                child: _buildDayDetailsSection(),
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  Widget _buildDayDetailsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 400;
        final isTablet = screenWidth > 600;

        // Calculate responsive dimensions - Match leave cards exactly
        final margin = isMobile ? 8.0 : (isTablet ? 16.0 : 12.0);
        final padding = isMobile ? 16.0 : (isTablet ? 24.0 : 20.0);
        final borderRadius = isMobile ? 12.0 : (isTablet ? 16.0 : 14.0);
        final dateFontSize = isMobile ? 20.0 : (isTablet ? 24.0 : 22.0);
        final subtitleFontSize = isMobile ? 14.0 : (isTablet ? 18.0 : 16.0);
        final spacing = isMobile ? 6.0 : (isTablet ? 10.0 : 8.0);

        return Container(
          margin: EdgeInsets.all(margin),
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Date Header - Centered
                Column(
                  children: [
                    Text(
                      '${_selectedDay.day}',
                      style: TextStyle(
                        fontSize: dateFontSize,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF000B58),
                      ),
                    ),
                    SizedBox(height: isMobile ? 4 : 8),
                    Text(
                      _formatDate(_selectedDay),
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_isSelectedDayHoliday) ...[
                      SizedBox(height: isMobile ? 2 : 4),
                      Text(
                        'Jour férié',
                        style: TextStyle(
                          fontSize: isMobile ? 14.0 : 16.0,
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: spacing),

                // Content
                if (_selectedDayLeaves.isEmpty && !_isSelectedDayHoliday)
                  _buildNoLeaveContent()
                else if (_isSelectedDayHoliday)
                  _buildHolidayContent()
                else
                  _buildLeaveContent(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoLeaveContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 400;
    final isTablet = screenWidth > 600;

    final iconSize = isMobile ? 32.0 : (isTablet ? 40.0 : 36.0);
    final titleFontSize = isMobile ? 16.0 : (isTablet ? 20.0 : 18.0);
    final subtitleFontSize = isMobile ? 14.0 : (isTablet ? 18.0 : 16.0);
    final spacing = isMobile ? 6.0 : (isTablet ? 10.0 : 8.0);

    return Column(
      children: [
        Icon(
          Icons.calendar_today,
          size: iconSize,
          color: Colors.grey[400],
        ),
        SizedBox(height: spacing),
        Text(
          'Aucun congé ce jour',
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: isMobile ? 4 : 8),
        Text(
          'Tous les employés sont disponibles',
          style: TextStyle(
            fontSize: subtitleFontSize,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildHolidayContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 400;
    final isTablet = screenWidth > 600;

    final iconSize = isMobile ? 32.0 : (isTablet ? 40.0 : 36.0);
    final titleFontSize = isMobile ? 16.0 : (isTablet ? 20.0 : 18.0);
    final subtitleFontSize = isMobile ? 14.0 : (isTablet ? 18.0 : 16.0);
    final spacing = isMobile ? 6.0 : (isTablet ? 10.0 : 8.0);

    return Column(
      children: [
        Icon(
          Icons.celebration,
          size: iconSize,
          color: Colors.red[400],
        ),
        SizedBox(height: spacing),
        Text(
          'Jour férié',
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
        SizedBox(height: isMobile ? 4 : 8),
        Text(
          'Jour férié marocain - Bureau fermé',
          style: TextStyle(
            fontSize: subtitleFontSize,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLeaveContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 400;
    final isTablet = screenWidth > 600;

    final titleFontSize = isMobile ? 14.0 : (isTablet ? 20.0 : 16.0);
    final spacing = isMobile ? 8.0 : (isTablet ? 16.0 : 12.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Congés prévus - Tous les employés (${_selectedDayLeaves.length})',
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: spacing),
        ...(_selectedDayLeaves.map((leave) => _buildLeaveCard(leave))),
      ],
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 400;
    final isTablet = screenWidth > 600;

    final leaveType = leave['holiday_status_id'] is List
        ? leave['holiday_status_id'][1]
        : leave['holiday_status_id'].toString();
    final reason = leave['name'] ?? 'Aucune raison spécifiée';
    final status = leave['status'] == 'approved' ? 'Approuvé' : 'En attente';
    final statusColor =
        leave['status'] == 'approved' ? const Color(0xFF35BF8C) : Colors.orange;

    // Calculate responsive dimensions - Made bigger
    final margin = isMobile ? 8.0 : (isTablet ? 16.0 : 12.0);
    final padding = isMobile ? 16.0 : (isTablet ? 24.0 : 20.0);
    final borderRadius = isMobile ? 12.0 : (isTablet ? 16.0 : 14.0);
    final titleFontSize = isMobile ? 16.0 : (isTablet ? 20.0 : 18.0);
    final subtitleFontSize = isMobile ? 14.0 : (isTablet ? 18.0 : 16.0);
    final smallFontSize = isMobile ? 12.0 : (isTablet ? 16.0 : 14.0);
    final spacing = isMobile ? 6.0 : (isTablet ? 10.0 : 8.0);

    return Container(
      margin: EdgeInsets.only(bottom: margin),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  leaveType,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: titleFontSize,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: subtitleFontSize,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing),
          Text(
            'Employé: ${_getEmployeeName(leave['employee_id'])}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: subtitleFontSize,
              color: const Color.fromARGB(255, 113, 59, 237),
            ),
          ),
          SizedBox(height: spacing),
          Text(
            'Raison: $reason',
            style: TextStyle(fontSize: subtitleFontSize),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          SizedBox(height: spacing),
          Text(
            'Période: ${_formatDateRange(leave['date_from'], leave['date_to'])}',
            style: TextStyle(
              fontSize: smallFontSize,
              color: Colors.grey,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre'
    ];
    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche'
    ];

    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDateRange(dynamic dateFrom, dynamic dateTo) {
    try {
      final from = DateTime.parse(dateFrom.toString().split(' ')[0]);
      final to = DateTime.parse(dateTo.toString().split(' ')[0]);

      if (from.day == to.day &&
          from.month == to.month &&
          from.year == to.year) {
        return '${from.day}/${from.month}/${from.year}';
      } else {
        return '${from.day}/${from.month}/${from.year} - ${to.day}/${to.month}/${to.year}';
      }
    } catch (e) {
      return 'Date invalide';
    }
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 400;
    final isTablet = screenWidth > 600;

    final dotSize = isMobile ? 10.0 : (isTablet ? 14.0 : 12.0);
    final fontSize = isMobile ? 10.0 : (isTablet ? 14.0 : 12.0);
    final spacing = isMobile ? 8.0 : (isTablet ? 16.0 : 12.0);
    final runSpacing = isMobile ? 6.0 : (isTablet ? 12.0 : 8.0);

    Widget item(Color color, String text) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: isMobile ? 4 : 6),
          Text(
            text,
            style: TextStyle(fontSize: fontSize),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Flexible(child: item(const Color(0xFF35BF8C), 'Congé approuvé')),
        Flexible(child: item(Colors.orange.shade400, 'Congé en attente')),
        Flexible(child: item(Colors.red.shade400, 'Jours fériés')),
      ],
    );
  }
}
