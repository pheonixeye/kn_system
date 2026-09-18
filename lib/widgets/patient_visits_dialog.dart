import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/services/pdf_service.dart';
import '../core/theme/app_theme.dart';
import '../models/visit.dart';
import '../providers/clinic_provider.dart';
import 'custom_badge.dart';

/// Lists every visit on record for a patient in a read-only dialog.
///
/// Used from the receptionist "All Patients" directory so the front desk can
/// review a patient's previous visits at a glance.
class PatientVisitsDialog extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientVisitsDialog({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  static Future<void> show(
    BuildContext context, {
    required String patientId,
    required String patientName,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => PatientVisitsDialog(
        patientId: patientId,
        patientName: patientName,
      ),
    );
  }

  @override
  State<PatientVisitsDialog> createState() => _PatientVisitsDialogState();
}

class _PatientVisitsDialogState extends State<PatientVisitsDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ClinicProvider>();
      if (provider.getPatientVisits(widget.patientId) == null) {
        provider.fetchPatientVisitsHistory(widget.patientId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final visits = provider.getPatientVisits(widget.patientId) ?? <Visit>[];
    final isLoading =
        provider.isPatientVisitsLoading(widget.patientId) && visits.isEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
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
                      Icons.history_edu_outlined,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Previous Visits',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.secondary,
                          ),
                        ),
                        Text(
                          '${widget.patientName} • ${visits.length} visit${visits.length == 1 ? "" : "s"} on record',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.slate500,
                          ),
                        ),
                      ],
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
            Flexible(
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : visits.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 40,
                        horizontal: 20,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_open_outlined,
                            size: 42,
                            color: AppTheme.slate400,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No previous visits recorded for this patient yet.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.slate500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: visits.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) =>
                          _buildVisitCard(context, visits[idx]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitCard(BuildContext context, Visit visit) {
    final date = visit.visitDate != null
        ? DateTime.tryParse(visit.visitDate!)
        : null;
    final hasImages =
        visit.images.isNotEmpty || visit.prescriptionImages.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  date != null
                      ? DateFormat('MMM d, yyyy').format(date)
                      : (visit.visitDate ?? 'Date not recorded'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (visit.queueNumber != null) ...[
                const SizedBox(width: 8),
                _chip('#${visit.queueNumber}', AppTheme.accent),
              ],
              const SizedBox(width: 8),
              CustomBadge.fromStatus(visit.status),
              const Spacer(),
              IconButton(
                tooltip: 'Print Visit PDF',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 18,
                icon: Icon(
                  Icons.print_outlined,
                  size: 18,
                  color: AppTheme.primary,
                ),
                onPressed: () async {
                  try {
                    await PdfService.printVisitReport(visit);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppTheme.danger,
                          content: Text('Error printing visit PDF: $e'),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow('Chief Complaint', visit.chiefComplaint),
          if (visit.consultantDiagnosis?.trim().isNotEmpty == true)
            _infoRow('Diagnosis', visit.consultantDiagnosis),
          if (visit.consultantPlan?.trim().isNotEmpty == true)
            _infoRow('Treatment Plan', visit.consultantPlan),
          if (visit.consultantPrescription?.trim().isNotEmpty == true)
            _infoRow('Prescription', visit.consultantPrescription),
          if (visit.consultantName?.trim().isNotEmpty == true)
            _infoRow('Consultant', 'Dr. ${visit.consultantName}'),
          if (hasImages) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (visit.images.isNotEmpty)
                  _chip('${visit.images.length} intake image(s)', AppTheme.purple),
                if (visit.prescriptionImages.isNotEmpty)
                  _chip(
                    '${visit.prescriptionImages.length} prescription image(s)',
                    AppTheme.success,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: AppTheme.slate500),
            ),
          ),
          Expanded(
            child: Text(
              (value == null || value.trim().isEmpty) ? '-' : value.trim(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
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
