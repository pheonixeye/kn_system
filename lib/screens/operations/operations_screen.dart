import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/services/pdf_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/operation.dart';
import '../../providers/clinic_provider.dart';
import '../../widgets/operation_booking_dialog.dart';
import '../../widgets/patient_operations_dialog.dart';

/// Operations workspace available to resident doctors and the consultant.
/// Contains two sub-tabs: Today's Operations (editable + printable operative
/// report) and a search/filter view over all recorded operations.
class OperationsScreen extends StatefulWidget {
  const OperationsScreen({super.key});

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  final _searchController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  int _tabIndex = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Operation> _todayOperations(List<Operation> operations) {
    final now = DateTime.now();
    return operations.where((o) {
      final dt = o.dateTime;
      if (dt == null) return false;
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).toList()..sort(
      (a, b) => (a.dateTime ?? now).compareTo(b.dateTime ?? now),
    );
  }

  List<Operation> _filteredOperations(List<Operation> operations) {
    final query = _searchController.text.trim().toLowerCase();
    var filtered = operations.where((o) {
      if (query.isNotEmpty) {
        final name = o.patient?.name.toLowerCase() ?? '';
        final phone = o.patient?.phone.toLowerCase() ?? '';
        if (!name.contains(query) && !phone.contains(query)) return false;
      }
      final dt = o.dateTime;
      if (_fromDate != null && dt != null && dt.isBefore(_fromDate!)) {
        return false;
      }
      if (_toDate != null && dt != null && dt.isAfter(_toDate!)) {
        return false;
      }
      return true;
    }).toList();
    return filtered..sort(
      (a, b) =>
          (b.dateTime ?? DateTime(0)).compareTo(a.dateTime ?? DateTime(0)),
    );
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(
        () => _fromDate = DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _toDate = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _editOperation(BuildContext context, Operation op) async {
    final updated = await OperationBookingDialog.show(
      context,
      operationToEdit: op,
    );
    if (updated != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.success,
          content: Text(
            'Operation updated for ${updated.patient?.name ?? "patient"}',
          ),
        ),
      );
    }
  }

  Future<void> _printOperativeReport(BuildContext context, Operation op) async {
    try {
      await PdfService.printOperationClinicalReport(op);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('Error printing operative report: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final operations = provider.operations;
    final todayOps = _todayOperations(operations);
    final filtered = _filteredOperations(operations);

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.local_hospital_outlined,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.secondary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Operative schedule, records and reports',
                      style: TextStyle(fontSize: 11, color: AppTheme.slate500),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Sub-tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.slate100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Row(
                children: [
                  _buildSubTab(
                    icon: Icons.today_outlined,
                    label: 'Today\'s Operations',
                    count: todayOps.length,
                    selected: _tabIndex == 0,
                    onTap: () => setState(() => _tabIndex = 0),
                  ),
                  _buildSubTab(
                    icon: Icons.search_rounded,
                    label: 'Search / Filter',
                    count: filtered.length,
                    selected: _tabIndex == 1,
                    onTap: () => setState(() => _tabIndex = 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Body
            Expanded(
              child: _tabIndex == 0
                  ? _buildTodayTab(context, todayOps)
                  : _buildSearchTab(context, filtered),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTab({
    required IconData icon,
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppTheme.onPrimary : AppTheme.slate500,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? AppTheme.onPrimary : AppTheme.slate700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppTheme.slate200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: selected ? AppTheme.onPrimary : AppTheme.slate700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayTab(BuildContext context, List<Operation> todayOps) {
    final dateLabel = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              dateLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
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
                '${todayOps.length} scheduled',
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
          child: todayOps.isEmpty
              ? _buildEmptyState(
                  icon: Icons.event_busy_outlined,
                  message: 'No operations scheduled for today.',
                )
              : ListView.separated(
                  itemCount: todayOps.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) => _buildOperationCard(
                    context,
                    todayOps[idx],
                    showDate: false,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSearchTab(BuildContext context, List<Operation> filtered) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search & Filter Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.slate50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Search patient',
                  hintText: 'Search by patient name or phone...',
                  prefixIcon: Icon(Icons.person_search_outlined, size: 18),
                  suffixIcon: Icon(Icons.search_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildDateFilter(
                      icon: Icons.event_outlined,
                      label: 'From',
                      value: _fromDate != null
                          ? DateFormat('yyyy-MM-dd').format(_fromDate!)
                          : 'Any date',
                      onTap: _pickFromDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDateFilter(
                      icon: Icons.event_available_outlined,
                      label: 'To',
                      value: _toDate != null
                          ? DateFormat('yyyy-MM-dd').format(_toDate!)
                          : 'Any date',
                      onTap: _pickToDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _fromDate = null;
                        _toDate = null;
                      });
                    },
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 14),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(
                  icon: Icons.search_off_rounded,
                  message: 'No operations match your search.',
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) =>
                      _buildOperationCard(context, filtered[idx]),
                ),
        ),
      ],
    );
  }

  Widget _buildDateFilter({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: AppTheme.slate500),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: AppTheme.slate400),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.slate500),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationCard(
    BuildContext context,
    Operation op, {
    bool showDate = true,
  }) {
    final dt = op.dateTime;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                      dt != null ? DateFormat('HH:mm').format(dt) : '--:--',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      dt != null ? DateFormat('dd MMM').format(dt) : '',
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
                          '${op.graftsExpected ?? 0} expected',
                          AppTheme.primary,
                        ),
                        _buildChip(
                          '${op.graftsDone ?? 0} done',
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
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildActionIcon(
                tooltip: 'Edit Operation',
                icon: Icons.edit_outlined,
                color: AppTheme.primary,
                onTap: () => _editOperation(context, op),
              ),
              _buildActionIcon(
                tooltip: 'Manage Images',
                icon: Icons.add_photo_alternate_outlined,
                color: AppTheme.purple,
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => OperationImagesEditorDialog(operation: op),
                ),
              ),
              _buildActionIcon(
                tooltip: 'Print Operative Report',
                icon: Icons.print_outlined,
                color: AppTheme.success,
                onTap: () => _printOperativeReport(context, op),
              ),
            ],
          ),
          if (op.operativeNotes != null &&
              op.operativeNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 14,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      op.operativeNotes!.trim(),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.slate500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionIcon({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return IconButton(
      tooltip: tooltip,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(2),
      iconSize: 18,
      icon: Icon(icon, color: color),
      splashRadius: 16,
      onPressed: onTap,
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
