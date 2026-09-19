import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/operation.dart';
import '../models/patient.dart';
import '../providers/clinic_provider.dart';

/// Dialog that lets a user book a new operation or edit an existing one.
/// Booking notifies the consultant, reception and (when booked by the
/// consultant) management.
class OperationBookingDialog extends StatefulWidget {
  final Patient? preselectedPatient;
  final DateTime? initialDate;
  final String? patientIdFilter;

  /// When provided, the dialog runs in edit mode and updates this operation.
  final Operation? operationToEdit;

  const OperationBookingDialog({
    super.key,
    this.preselectedPatient,
    this.initialDate,
    this.patientIdFilter,
    this.operationToEdit,
  });

  static Future<Operation?> show(
    BuildContext context, {
    Patient? preselectedPatient,
    DateTime? initialDate,
    String? patientIdFilter,
    Operation? operationToEdit,
  }) {
    return showDialog<Operation>(
      context: context,
      builder: (_) => OperationBookingDialog(
        preselectedPatient: preselectedPatient,
        initialDate: initialDate,
        patientIdFilter: patientIdFilter,
        operationToEdit: operationToEdit,
      ),
    );
  }

  @override
  State<OperationBookingDialog> createState() => _OperationBookingDialogState();
}

class _OperationBookingDialogState extends State<OperationBookingDialog> {
  Patient? _selectedPatient;
  DateTime _date;
  TimeOfDay _time;
  final _graftsExpectedController = TextEditingController();
  final _graftsDoneController = TextEditingController();
  final _totalPriceController = TextEditingController();
  final _depositController = TextEditingController();
  final _remainingController = TextEditingController();
  final _operativeNotesController = TextEditingController();
  bool _isSaving = false;

  _OperationBookingDialogState()
    : _date = DateTime.now(),
      _time = const TimeOfDay(hour: 9, minute: 0);

  bool get _isEditing => widget.operationToEdit != null;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedPatient != null) {
      _selectedPatient = widget.preselectedPatient;
    }
    if (widget.initialDate != null) {
      _date = widget.initialDate!;
    }

    final edit = widget.operationToEdit;
    if (edit != null) {
      _selectedPatient = edit.patient;
      if (_selectedPatient == null && edit.patientId.isNotEmpty) {
        _selectedPatient = context
            .read<ClinicProvider>()
            .patients
            .where((p) => p.id == edit.patientId)
            .firstOrNull;
      }
      if (edit.dateTime != null) {
        final local = edit.dateTime!.toLocal();
        _date = local;
        _time = TimeOfDay(hour: local.hour, minute: local.minute);
      }
      _graftsExpectedController.text = edit.graftsExpected?.toString() ?? '';
      _graftsDoneController.text = edit.graftsDone?.toString() ?? '';
      if (edit.totalPrice != null) {
        _totalPriceController.text = edit.totalPrice!.toStringAsFixed(0);
      }
      if (edit.deposit != null) {
        _depositController.text = edit.deposit!.toStringAsFixed(0);
      }
      if (edit.remainingAtOperation != null) {
        _remainingController.text = edit.remainingAtOperation!.toStringAsFixed(
          0,
        );
      }
      if (edit.operativeNotes != null) {
        _operativeNotesController.text = edit.operativeNotes!;
      }
    }

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
    _operativeNotesController.dispose();
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _save() async {
    if (_selectedPatient == null) {
      _showSnack(AppTheme.danger, 'Please select a patient for the operation.');
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<ClinicProvider>();

    final opDateTime = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );

    try {
      final graftingExpected = int.tryParse(
        _graftsExpectedController.text.trim(),
      );
      final graftingDone = int.tryParse(_graftsDoneController.text.trim());
      final total = double.tryParse(_totalPriceController.text.trim());
      final deposit = double.tryParse(_depositController.text.trim());
      final remaining = double.tryParse(_remainingController.text.trim());

      final edit = widget.operationToEdit;
      final operativeNotes = _operativeNotesController.text.trim();
      final op = edit != null
          ? await provider.updateOperation(
              edit.id,
              patientId: _selectedPatient!.id,
              dateTime: opDateTime,
              graftsExpected: graftingExpected,
              graftsDone: graftingDone,
              totalPrice: total,
              deposit: deposit,
              remainingAtOperation: remaining,
              operativeNotes: operativeNotes,
            )
          : await provider.scheduleOperation(
              patientId: _selectedPatient!.id,
              dateTime: opDateTime,
              graftsExpected: graftingExpected,
              graftsDone: graftingDone,
              totalPrice: total,
              deposit: deposit,
              remainingAtOperation: remaining,
              operativeNotes: operativeNotes,
              // Booked by the consultant -> also notify Management
              notifyTarget: AppConstants.userTypeManager,
            );

      if (mounted) {
        Navigator.of(context).pop(op);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnack(AppTheme.danger, 'Error scheduling operation: $e');
      }
    }
  }

  void _showSnack(Color color, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(backgroundColor: color, content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final patients = widget.patientIdFilter != null
        ? provider.patients
              .where((p) => p.id == widget.patientIdFilter)
              .toList()
        : provider.patients;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadow,
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isEditing
                          ? Icons.edit_calendar_outlined
                          : Icons.event_available_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit Operation' : 'Book Operation',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.secondary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient selector
                    const Text(
                      'Select Patient *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Autocomplete<Patient>(
                      displayStringForOption: (p) => '${p.name} (${p.phone})',
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return patients.take(10);
                        }
                        final q = textEditingValue.text.toLowerCase();
                        return patients.where((p) {
                          return p.name.toLowerCase().contains(q) ||
                              p.phone.contains(q) ||
                              (p.nationalId?.contains(q) ?? false);
                        });
                      },
                      onSelected: (patient) {
                        setState(() => _selectedPatient = patient);
                      },
                      fieldViewBuilder:
                          (
                            context,
                            textEditingController,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            if (_selectedPatient != null &&
                                textEditingController.text.isEmpty) {
                              textEditingController.text =
                                  '${_selectedPatient!.name} (${_selectedPatient!.phone})';
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
                                suffixIcon: _selectedPatient != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () {
                                          textEditingController.clear();
                                          setState(
                                            () => _selectedPatient = null,
                                          );
                                        },
                                      )
                                    : null,
                              ),
                            );
                          },
                    ),
                    if (_selectedPatient != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
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
                                'Selected: ${_selectedPatient!.name} (Age: ${_selectedPatient!.calculatedAge ?? _selectedPatient!.dob ?? "-"})',
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

                    // Date & Time
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildPickerField(
                            label: 'Operation Date *',
                            icon: Icons.calendar_today_outlined,
                            value: DateFormat('yyyy-MM-dd').format(_date),
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _buildPickerField(
                            label: 'Time *',
                            icon: Icons.access_time_rounded,
                            value: _time.format(context),
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Grafts
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _graftsExpectedController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Grafts Expected',
                              hintText: 'e.g. 3500',
                              prefixIcon: Icon(
                                Icons.format_list_numbered_rounded,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _graftsDoneController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Grafts Done',
                              hintText: 'e.g. 3600',
                              prefixIcon: Icon(
                                Icons.done_all_rounded,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Operative Notes
                    TextField(
                      controller: _operativeNotesController,
                      maxLines: 3,
                      minLines: 2,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        labelText: 'Operative Notes',
                        hintText:
                            'e.g. Surgical plan, grafts detail, anesthesia notes...',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 40),
                          child: Icon(Icons.edit_note_rounded, size: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Financials
                    // Row(
                    //   children: [
                    //     Expanded(
                    //       child: TextField(
                    //         controller: _totalPriceController,
                    //         keyboardType: const TextInputType.numberWithOptions(
                    //           decimal: true,
                    //         ),
                    //         decoration: const InputDecoration(
                    //           labelText: 'Total Price',
                    //           hintText: 'e.g. 25000',
                    //           prefixIcon: Icon(
                    //             Icons.payments_outlined,
                    //             size: 16,
                    //           ),
                    //         ),
                    //       ),
                    //     ),
                    //     const SizedBox(width: 12),
                    //     Expanded(
                    //       child: TextField(
                    //         controller: _depositController,
                    //         keyboardType: const TextInputType.numberWithOptions(
                    //           decimal: true,
                    //         ),
                    //         decoration: const InputDecoration(
                    //           labelText: 'Deposit Paid',
                    //           hintText: 'e.g. 5000',
                    //           prefixIcon: Icon(Icons.savings_outlined, size: 16),
                    //         ),
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    // const SizedBox(height: 14),
                    // TextField(
                    //   controller: _remainingController,
                    //   keyboardType: const TextInputType.numberWithOptions(
                    //     decimal: true,
                    //   ),
                    //   decoration: const InputDecoration(
                    //     labelText: 'Remaining',
                    //     hintText: 'e.g. 20000',
                    //     prefixIcon: Icon(
                    //       Icons.account_balance_wallet_outlined,
                    //       size: 16,
                    //     ),
                    //     helperText:
                    //         'Remaining = Total Price - Deposit (auto-calculated)',
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
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
                            _isEditing
                                ? Icons.save_outlined
                                : Icons.event_available_rounded,
                            size: 16,
                          ),
                    label: Text(
                      _isSaving
                          ? (_isEditing ? 'Saving...' : 'Booking...')
                          : (_isEditing ? 'Save Changes' : 'Book Operation'),
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

  Widget _buildPickerField({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.slate200),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  value,
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
    );
  }
}
