import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/operation.dart';
import '../../models/patient.dart';
import '../../models/visit.dart';
import '../../providers/clinic_provider.dart';
import '../../widgets/stat_card.dart';

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  Operation? _selectedOperation;
  Patient? _formSelectedPatient;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

  final _graftsExpectedController = TextEditingController();
  final _graftsDoneController = TextEditingController();
  final _totalPriceController = TextEditingController();
  final _depositController = TextEditingController();
  final _remainingController = TextEditingController();
  final _patientSearchController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _totalPriceController.addListener(_recalculateRemaining);
    _depositController.addListener(_recalculateRemaining);
  }

  @override
  void dispose() {
    _graftsExpectedController.dispose();
    _graftsDoneController.dispose();
    _totalPriceController.dispose();
    _depositController.dispose();
    _remainingController.dispose();
    _patientSearchController.dispose();
    super.dispose();
  }

  void _recalculateRemaining() {
    final total = double.tryParse(_totalPriceController.text.trim()) ?? 0.0;
    final deposit = double.tryParse(_depositController.text.trim()) ?? 0.0;
    final remaining = (total - deposit).clamp(0.0, double.infinity);
    if (_remainingController.text != remaining.toStringAsFixed(0)) {
      _remainingController.text = remaining > 0
          ? remaining.toStringAsFixed(0)
          : '0';
    }
  }

  void _loadOperationIntoForm(Operation op) {
    setState(() {
      _selectedOperation = op;
      _formSelectedPatient =
          op.patient ??
          context
              .read<ClinicProvider>()
              .patients
              .where((p) => p.id == op.patientId)
              .firstOrNull;
      if (op.dateTime != null) {
        _selectedDate = DateTime(
          op.dateTime!.year,
          op.dateTime!.month,
          op.dateTime!.day,
        );
        _selectedTime = TimeOfDay(
          hour: op.dateTime!.hour,
          minute: op.dateTime!.minute,
        );
      }
      _graftsExpectedController.text =
          op.graftsExpected != null && op.graftsExpected! > 0
          ? op.graftsExpected.toString()
          : '';
      _graftsDoneController.text = op.graftsDone != null && op.graftsDone! > 0
          ? op.graftsDone.toString()
          : '';
      _totalPriceController.text = op.totalPrice != null && op.totalPrice! > 0
          ? op.totalPrice!.toStringAsFixed(0)
          : '';
      _depositController.text = op.deposit != null && op.deposit! > 0
          ? op.deposit!.toStringAsFixed(0)
          : '';
      _remainingController.text =
          op.remainingAtOperation != null && op.remainingAtOperation! >= 0
          ? op.remainingAtOperation!.toStringAsFixed(0)
          : '';
    });
  }

  void _resetForm({Patient? preselectedPatient, DateTime? date}) {
    setState(() {
      _selectedOperation = null;
      _formSelectedPatient = preselectedPatient;
      if (date != null) {
        _selectedDate = date;
      }
      _selectedTime = const TimeOfDay(hour: 9, minute: 0);
      _graftsExpectedController.clear();
      _graftsDoneController.clear();
      _totalPriceController.clear();
      _depositController.clear();
      _remainingController.clear();
    });
  }

  Future<void> _saveOperation() async {
    if (_formSelectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: const Text('Please select a patient for the operation.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<ClinicProvider>();

    final opDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final graftsExp = int.tryParse(_graftsExpectedController.text.trim());
    final graftsDone = int.tryParse(_graftsDoneController.text.trim());
    final totalPrice = double.tryParse(_totalPriceController.text.trim());
    final deposit = double.tryParse(_depositController.text.trim());
    final remaining = double.tryParse(_remainingController.text.trim());

    try {
      if (_selectedOperation != null) {
        await provider.updateOperation(
          _selectedOperation!.id,
          patientId: _formSelectedPatient!.id,
          dateTime: opDateTime,
          graftsExpected: graftsExp,
          graftsDone: graftsDone,
          totalPrice: totalPrice,
          deposit: deposit,
          remainingAtOperation: remaining,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.success,
              content: const Text('Operation schedule updated successfully!'),
            ),
          );
        }
      } else {
        await provider.scheduleOperation(
          patientId: _formSelectedPatient!.id,
          dateTime: opDateTime,
          graftsExpected: graftsExp,
          graftsDone: graftsDone,
          totalPrice: totalPrice,
          deposit: deposit,
          remainingAtOperation: remaining,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.success,
              content: const Text('New operation booked successfully!'),
            ),
          );
        }
      }
      _resetForm(date: _selectedDate);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('Error saving operation: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteOperation(Operation op) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel / Delete Operation'),
        content: Text(
          'Are you sure you want to delete the operation scheduled for ${op.patient?.name ?? "this patient"} on ${op.dateTime != null ? DateFormat("yyyy-MM-dd HH:mm").format(op.dateTime!) : "scheduled date"}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No, Keep'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<ClinicProvider>().deleteOperation(op.id);
        if (_selectedOperation?.id == op.id) {
          _resetForm(date: _selectedDate);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.success,
              content: const Text('Operation deleted successfully.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.danger,
              content: Text('Failed to delete operation: $e'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final operations = provider.operations;
    final patients = provider.patients;
    final visits = provider.visits;

    // Patients sent to management
    final sentToManagementVisits = visits
        .where((v) => v.status == AppConstants.statusSentToManagement)
        .toList();

    // Stats calculations
    final now = DateTime.now();
    final thisMonthOps = operations.where((o) {
      return o.dateTime != null &&
          o.dateTime!.year == _currentMonth.year &&
          o.dateTime!.month == _currentMonth.month;
    }).toList();

    final todayOps = operations.where((o) {
      return o.dateTime != null &&
          o.dateTime!.year == now.year &&
          o.dateTime!.month == now.month &&
          o.dateTime!.day == now.day;
    }).toList();

    final totalGrafts = operations.fold<int>(
      0,
      (sum, op) => sum + (op.graftsExpected ?? 0),
    );

    final totalDeposits = operations.fold<double>(
      0.0,
      (sum, op) => sum + (op.deposit ?? 0.0),
    );

    // Selected day's operations
    final selectedDayOps =
        operations.where((o) {
            if (o.dateTime == null) return false;
            return o.dateTime!.year == _selectedDate.year &&
                o.dateTime!.month == _selectedDate.month &&
                o.dateTime!.day == _selectedDate.day;
          }).toList()
          ..sort((a, b) => (a.dateTime ?? now).compareTo(b.dateTime ?? now));

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Top Stats Banner
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Total Operations Scheduled',
                    value: '${operations.length}',
                    icon: Icons.calendar_month_outlined,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title:
                        '${DateFormat("MMMM").format(_currentMonth)} Operations',
                    value: '${thisMonthOps.length}',
                    icon: Icons.event_available_outlined,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Today\'s Surgeries',
                    value: '${todayOps.length}',
                    icon: Icons.medical_information_outlined,
                    color: AppTheme.warning,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Total Grafts Target',
                    value: NumberFormat('#,###').format(totalGrafts),
                    icon: Icons.stacked_line_chart_rounded,
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Deposits Collected',
                    value: NumberFormat.currency(
                      symbol: 'EGP ',
                      decimalDigits: 0,
                    ).format(totalDeposits),
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppTheme.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Referrals Banner if patients sent to management
            if (sentToManagementVisits.isNotEmpty) ...[
              _buildReferralQueueBanner(sentToManagementVisits),
              const SizedBox(height: 16),
            ],

            // Main Content: Large Calendar + Day Schedule + Operation Booking Form
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left / Center Area: Large Calendar + Selected Day Operations
                  Expanded(
                    flex: 3,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Calendar Header (Month / Year Navigation)
                            _buildCalendarHeader(),
                            const SizedBox(height: 16),

                            // Calendar Grid
                            Expanded(
                              child: _buildMonthCalendarGrid(operations),
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),

                            // Selected Day Operations List
                            _buildSelectedDaySchedule(selectedDayOps),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Right Panel: Operation Form (Create / Edit)
                  SizedBox(
                    width: 420,
                    child: Card(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _buildOperationForm(patients),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralQueueBanner(List<Visit> referrals) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.purpleLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.purple.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.purple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: AppTheme.purple,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${referrals.length} Patient${referrals.length == 1 ? "" : "s"} Sent to Management by Consultant',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTheme.purple,
                  ),
                ),
                Text(
                  'Consultant requested operation scheduling for: ${referrals.map((v) => v.patient?.name ?? "Patient").join(", ")}',
                  style: TextStyle(fontSize: 11, color: AppTheme.slate500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            children: referrals.take(3).map((v) {
              final pat = v.patient;
              return ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                onPressed: () {
                  if (pat != null) {
                    _resetForm(preselectedPatient: pat, date: _selectedDate);
                  }
                },
                icon: const Icon(Icons.add_task_rounded, size: 14),
                label: Text('Book ${pat?.name.split(" ").first ?? "Patient"}'),
              );
            }).toList(),
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

  Widget _buildMonthCalendarGrid(List<Operation> allOperations) {
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

    // Days in previous month padding
    final startWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0, Mon = 1 ...
    final totalDays = lastDayOfMonth.day;

    final weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Column(
      children: [
        // Weekday header row
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

        // Grid of days
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

                  final dayOps = allOperations.where((o) {
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
                                  '${dt != null ? DateFormat("HH:mm").format(dt) : ""} ${op.patient?.name.split(" ").first ?? "Patient"}',
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
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
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                textStyle: const TextStyle(fontSize: 11),
              ),
              onPressed: () => _resetForm(date: _selectedDate),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Book for this date'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (dayOps.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
                Text(
                  'No operations booked for this day. Use the form on the right to schedule one.',
                  style: TextStyle(fontSize: 12, color: AppTheme.slate500),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dayOps.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, idx) {
                final op = dayOps[idx];
                final isSelected = _selectedOperation?.id == op.id;
                return InkWell(
                  onTap: () => _loadOperationIntoForm(op),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 250,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryLight.withValues(alpha: 0.5)
                          : AppTheme.slate50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.slate200,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              op.dateTime != null
                                  ? DateFormat('hh:mm a').format(op.dateTime!)
                                  : '09:00 AM',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppTheme.primary,
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                                color: AppTheme.danger,
                              ),
                              onPressed: () => _deleteOperation(op),
                            ),
                          ],
                        ),
                        Text(
                          op.patient?.name ?? 'Unknown Patient',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppTheme.secondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${op.graftsExpected ?? 0} grafts',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.slate500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Deposit: ${op.deposit != null ? "${op.deposit!.toStringAsFixed(0)} EGP" : "-"}',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.success,
                                fontWeight: FontWeight.bold,
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
      ],
    );
  }

  Widget _buildOperationForm(List<Patient> allPatients) {
    final isEditing = _selectedOperation != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Form Title
        Row(
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
                    isEditing
                        ? Icons.edit_note_rounded
                        : Icons.add_task_rounded,
                    color: isEditing ? AppTheme.accent : AppTheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'Edit Operation' : 'Schedule Operation',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondary,
                  ),
                ),
              ],
            ),
            if (isEditing)
              TextButton.icon(
                onPressed: () => _resetForm(date: _selectedDate),
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('New'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 12),

        // Patient Selector
        const Text(
          'Select Patient *',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Autocomplete<Patient>(
          displayStringForOption: (p) => '${p.name} (${p.phone})',
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return allPatients.take(10);
            }
            final q = textEditingValue.text.toLowerCase();
            return allPatients.where((p) {
              return p.name.toLowerCase().contains(q) ||
                  p.phone.contains(q) ||
                  (p.nationalId?.contains(q) ?? false);
            });
          },
          onSelected: (patient) {
            setState(() {
              _formSelectedPatient = patient;
            });
          },
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
                if (_formSelectedPatient != null &&
                    textEditingController.text.isEmpty) {
                  textEditingController.text =
                      '${_formSelectedPatient!.name} (${_formSelectedPatient!.phone})';
                }
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Search patient by name or phone...',
                    prefixIcon: const Icon(
                      Icons.person_search_outlined,
                      size: 18,
                    ),
                    suffixIcon: _formSelectedPatient != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              textEditingController.clear();
                              setState(() => _formSelectedPatient = null);
                            },
                          )
                        : null,
                  ),
                );
              },
        ),
        if (_formSelectedPatient != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Selected: ${_formSelectedPatient!.name} (Age: ${_formSelectedPatient!.calculatedAge ?? _formSelectedPatient!.dob ?? "-"})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),

        // Operation Date & Time
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Operation Date *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.slate200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('yyyy-MM-dd').format(_selectedDate),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Time *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (picked != null) {
                        setState(() => _selectedTime = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.slate200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedTime.format(context),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Grafts Expected & Grafts Done
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Grafts Expected',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _graftsExpectedController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 3500',
                      prefixIcon: Icon(
                        Icons.format_list_numbered_rounded,
                        size: 16,
                      ),
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
                  const Text(
                    'Grafts Done',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _graftsDoneController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 3600',
                      prefixIcon: Icon(Icons.done_all_rounded, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Financial Fields: Total Price, Deposit, Remaining at Operation
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.slate50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 16,
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Operation Financials (EGP)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Price',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _totalPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            hintText: '0',
                            fillColor: Colors.white,
                            filled: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Deposit Paid',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _depositController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            hintText: '0',
                            fillColor: Colors.white,
                            filled: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Remaining',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _remainingController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            hintText: '0',
                            fillColor: Colors.white,
                            filled: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Action Buttons
        Row(
          children: [
            if (isEditing) ...[
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.dangerLight,
                  foregroundColor: AppTheme.danger,
                ),
                onPressed: _isSaving
                    ? null
                    : () => _deleteOperation(_selectedOperation!),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: 'Delete Operation',
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEditing
                      ? AppTheme.accent
                      : AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isSaving ? null : _saveOperation,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isEditing
                            ? Icons.save_rounded
                            : Icons.event_available_rounded,
                        size: 18,
                      ),
                label: Text(
                  isEditing ? 'Save Operation Changes' : 'Schedule Operation',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
