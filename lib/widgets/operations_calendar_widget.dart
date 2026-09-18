import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/operation.dart';
import 'operation_details_dialog.dart';

/// Read-only operations calendar used by the consultant dashboard.
/// Mirrors the visual style of the management schedule for a consistent UX.
class OperationsCalendarPanel extends StatefulWidget {
  final List<Operation> operations;
  final String? viewerName;

  const OperationsCalendarPanel({
    super.key,
    required this.operations,
    this.viewerName,
  });

  @override
  State<OperationsCalendarPanel> createState() =>
      _OperationsCalendarPanelState();
}

class _OperationsCalendarPanelState extends State<OperationsCalendarPanel> {
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayOps =
        widget.operations.where((o) {
          if (o.dateTime == null) return false;
          return o.dateTime!.year == _selectedDate.year &&
              o.dateTime!.month == _selectedDate.month &&
              o.dateTime!.day == _selectedDate.day;
        }).toList()
          ..sort((a, b) => (a.dateTime ?? now).compareTo(b.dateTime ?? now));

    final monthOps = widget.operations.where((o) {
      return o.dateTime != null &&
          o.dateTime!.year == _currentMonth.year &&
          o.dateTime!.month == _currentMonth.month;
    }).toList();

    final todayOps = widget.operations.where((o) {
      return o.dateTime != null &&
          o.dateTime!.year == now.year &&
          o.dateTime!.month == now.month &&
          o.dateTime!.day == now.day;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Compact stats strip
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.event_available_outlined,
                  label: '${monthOps.length} this month',
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.today_outlined,
                  label: '${todayOps.length} today',
                  color: AppTheme.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.calendar_month_outlined,
                  label: '${widget.operations.length} total',
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Calendar Header
          _buildCalendarHeader(),
          const SizedBox(height: 12),

          // Calendar Grid
          Expanded(flex: 3, child: _buildMonthCalendarGrid()),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Selected Day Schedule
          Expanded(flex: 2, child: _buildSelectedDaySchedule(dayOps)),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.secondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              DateFormat('MMMM yyyy').format(_currentMonth),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.secondary,
              ),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onPressed: () {
                setState(() {
                  _currentMonth = DateTime.now();
                  _selectedDate = DateTime.now();
                });
              },
              child: const Text('Today'),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () {
                setState(() {
                  _currentMonth = DateTime(
                    _currentMonth.year,
                    _currentMonth.month - 1,
                  );
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () {
                setState(() {
                  _currentMonth = DateTime(
                    _currentMonth.year,
                    _currentMonth.month + 1,
                  );
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthCalendarGrid() {
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    );

    final startWeekday = firstDayOfMonth.weekday % 7;
    final totalDays = lastDayOfMonth.day;
    final weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Column(
      children: [
        Row(
          children: weekDays.map((d) {
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                child: Text(
                  d,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.slate500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellCount = (startWeekday + totalDays <= 35) ? 35 : 42;
              final cellHeight = (constraints.maxHeight / (cellCount / 7)) - 4;

              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  mainAxisExtent: cellHeight,
                ),
                itemCount: cellCount,
                itemBuilder: (context, idx) {
                  final dayOffset = idx - startWeekday + 1;
                  final isCurrentMonth =
                      dayOffset >= 1 && dayOffset <= totalDays;

                  if (!isCurrentMonth) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppTheme.slate50.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  }

                  final date = DateTime(
                    _currentMonth.year,
                    _currentMonth.month,
                    dayOffset,
                  );
                  final isSelected =
                      date.year == _selectedDate.year &&
                      date.month == _selectedDate.month &&
                      date.day == _selectedDate.day;
                  final isToday =
                      date.year == DateTime.now().year &&
                      date.month == DateTime.now().month &&
                      date.day == DateTime.now().day;

                  final dayOps = widget.operations.where((o) {
                    if (o.dateTime == null) return false;
                    return o.dateTime!.year == date.year &&
                        o.dateTime!.month == date.month &&
                        o.dateTime!.day == date.day;
                  }).toList();

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDate = date;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryLight.withValues(alpha: 0.6)
                            : (isToday
                                  ? const Color(0xFFEFF6FF)
                                  : AppTheme.cardBg),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : (isToday
                                    ? const Color(0xFF93C5FD)
                                    : AppTheme.slate200),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: isToday
                                    ? BoxDecoration(
                                        color: AppTheme.primary,
                                        shape: BoxShape.circle,
                                      )
                                    : null,
                                child: Text(
                                  '$dayOffset',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isToday || isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isToday
                                        ? Colors.white
                                        : (isSelected
                                              ? AppTheme.primary
                                              : AppTheme.secondary),
                                  ),
                                ),
                              ),
                              if (dayOps.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${dayOps.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          if (dayOps.isNotEmpty) ...[
                            ...dayOps.take(2).map((op) {
                              final dt = op.dateTime;
                              return Container(
                                margin: const EdgeInsets.only(top: 1),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  '${dt != null ? DateFormat("HH:mm").format(dt) : ""} ${op.patient?.name.split(" ").firstOrNull ?? "Patient"}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppTheme.primaryDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                            if (dayOps.length > 2)
                              Text(
                                '+${dayOps.length - 2} more',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: AppTheme.slate500,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDaySchedule(List<Operation> dayOps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.schedule_rounded, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(
              'Operations on ${DateFormat("EEEE, MMMM d, yyyy").format(_selectedDate)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${dayOps.length} scheduled',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: dayOps.isEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.slate50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.slate200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_busy_outlined,
                        size: 18,
                        color: AppTheme.slate400,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No operations booked for this day.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.slate500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: dayOps.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final op = dayOps[idx];
                    return _buildOperationTile(op);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOperationTile(Operation op) {
    return Material(
      color: AppTheme.slate50,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => OperationDetailsDialog.show(context, op),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.slate200),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      op.dateTime != null
                          ? DateFormat('HH:mm').format(op.dateTime!)
                          : '--:--',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      op.dateTime != null
                          ? DateFormat('EEEE').format(op.dateTime!)
                          : '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      op.patient?.name ?? 'Unknown Patient',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildChip(
                          '${op.graftsExpected ?? 0} grafts expected',
                          AppTheme.primary,
                        ),
                        _buildChip(
                          '${op.graftsDone ?? 0} done',
                          AppTheme.success,
                        ),
                        _buildChip(
                          'Deposit: ${op.deposit != null ? "${op.deposit!.toStringAsFixed(0)} EGP" : "-"}',
                          AppTheme.success,
                        ),
                        if (op.remainingAtOperation != null &&
                            op.remainingAtOperation! > 0)
                          _buildChip(
                            'Remaining: ${op.remainingAtOperation!.toStringAsFixed(0)} EGP',
                            AppTheme.warning,
                          ),
                        if (op.intraOpImages.isNotEmpty)
                          _buildChip(
                            '${op.intraOpImages.length} images',
                            AppTheme.purple,
                          ),
                        _buildChip(
                          'Added by ${op.addedByLabel}',
                          AppTheme.slate500,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}