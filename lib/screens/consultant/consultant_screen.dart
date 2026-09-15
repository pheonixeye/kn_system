import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/pdf_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/visit.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clinic_provider.dart';
import '../../widgets/custom_badge.dart';
import '../../widgets/image_viewer_dialog.dart';
import '../../widgets/stat_card.dart';

class ConsultantScreen extends StatefulWidget {
  const ConsultantScreen({super.key});

  @override
  State<ConsultantScreen> createState() => _ConsultantScreenState();
}

class _ConsultantScreenState extends State<ConsultantScreen> {
  final _diagnosisController = TextEditingController();
  final _planController = TextEditingController();
  final _prescriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _consultantNameController = TextEditingController(
    text: 'Consultant Physician',
  );

  String? _currentLoadedVisitId;
  bool _isGeneratingPdf = false;

  @override
  void dispose() {
    _diagnosisController.dispose();
    _planController.dispose();
    _prescriptionController.dispose();
    _notesController.dispose();
    _consultantNameController.dispose();
    super.dispose();
  }

  void _loadVisitData(Visit visit) {
    _currentLoadedVisitId = visit.id;
    _diagnosisController.text = visit.consultantDiagnosis ?? '';
    _planController.text = visit.consultantPlan ?? '';
    _prescriptionController.text = visit.consultantPrescription ?? '';
    _notesController.text = visit.consultantNotes ?? '';
    if (visit.consultantName != null && visit.consultantName!.isNotEmpty) {
      _consultantNameController.text = visit.consultantName!;
    }
  }

  Future<void> _saveAssessment(
    Visit visit, {
    bool markCompleted = false,
  }) async {
    final provider = context.read<ClinicProvider>();
    final consultantName = _currentOperatorName();
    try {
      await provider.saveConsultantAssessment(
        visit: visit,
        diagnosis: _diagnosisController.text,
        plan: _planController.text,
        prescription: _prescriptionController.text,
        notes: _notesController.text,
        consultantName: consultantName,
        markCompleted: markCompleted,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text(
              markCompleted
                  ? 'Consultation finalized & visit marked as Completed!'
                  : 'Consultation assessment saved successfully!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('Error saving assessment: $e'),
          ),
        );
      }
    }
  }

  String _currentOperatorName() {
    final operatorName =
        context.read<AuthProvider>().currentUser?.name?.trim();
    final name = (operatorName != null && operatorName.isNotEmpty)
        ? operatorName
        : _consultantNameController.text.trim();
    if (name.isNotEmpty) {
      _consultantNameController.text = name;
    }
    return name;
  }

  Future<void> _printReport(Visit visit) async {
    setState(() => _isGeneratingPdf = true);
    try {
      // First update the visit locally so the PDF has the current form values
      final updatedVisit = visit.copyWith(
        consultantDiagnosis: _diagnosisController.text,
        consultantPlan: _planController.text,
        consultantPrescription: _prescriptionController.text,
        consultantNotes: _notesController.text,
        consultantName: _currentOperatorName(),
      );

      await PdfService.printVisitReport(updatedVisit);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('Error generating PDF report: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final visits = provider.visits;

    final readyVisits = visits.where((v) {
      return v.status == AppConstants.statusWaitingConsultant ||
          v.status == AppConstants.statusWithConsultant;
    }).toList();

    final completedVisits = visits
        .where((v) => v.status == AppConstants.statusCompleted)
        .toList();

    final selectedVisit =
        provider.selectedVisit ??
        (readyVisits.isNotEmpty
            ? readyVisits.first
            : (completedVisits.isNotEmpty ? completedVisits.first : null));

    if (selectedVisit != null && _currentLoadedVisitId != selectedVisit.id) {
      _loadVisitData(selectedVisit);
    }

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
                    title: 'Ready for Consultation',
                    value: '${readyVisits.length}',
                    icon: Icons.assignment_late_outlined,
                    color: AppTheme.warning,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'In Consultation',
                    value:
                        '${visits.where((v) => v.status == AppConstants.statusWithConsultant).length}',
                    icon: Icons.person_search_outlined,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Completed Consultations',
                    value: '${completedVisits.length}',
                    icon: Icons.task_alt_rounded,
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Total Clinic Visits',
                    value: '${visits.length}',
                    icon: Icons.analytics_outlined,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Main Dashboard Workspace
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Consultant Queue & Completed List
                  SizedBox(
                    width: 330,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                    Icons.dashboard_customize_outlined,
                                    color: AppTheme.primary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Consultant Queue',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),

                            // Queue Items
                            Expanded(
                              child:
                                  (readyVisits.isEmpty &&
                                      completedVisits.isEmpty)
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.inbox_outlined,
                                            size: 40,
                                            color: AppTheme.slate400,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'No patients waiting for consultation',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.slate500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView(
                                      children: [
                                        if (readyVisits.isNotEmpty) ...[
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 6,
                                            ),
                                            child: Text(
                                              'READY FOR CONSULTATION',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.slate500,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          ...readyVisits.map(
                                            (v) => _buildQueueCard(
                                              provider,
                                              v,
                                              selectedVisit,
                                            ),
                                          ),
                                        ],
                                        if (completedVisits.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 6,
                                            ),
                                            child: Text(
                                              'COMPLETED VISITS',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.slate500,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          ...completedVisits.map(
                                            (v) => _buildQueueCard(
                                              provider,
                                              v,
                                              selectedVisit,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Right: Comprehensive Case Dashboard & Clinical Assessment
                  Expanded(
                    child: selectedVisit == null
                        ? Card(
                            child: Center(
                              child: Text(
                                'Select a patient to review clinical history and manage case.',
                                style: TextStyle(color: AppTheme.slate500),
                              ),
                            ),
                          )
                        : Card(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Header & Print PDF Button
                                  _buildConsultantHeaderBanner(selectedVisit),
                                  const SizedBox(height: 20),
                                  const Divider(),
                                  const SizedBox(height: 20),

                                  // Medical History Summary Box (Collected by Resident)
                                  _buildIntakeReviewCard(selectedVisit),
                                  const SizedBox(height: 20),

                                  // Vital Signs Matrix
                                  _buildVitalsMatrix(selectedVisit),
                                  const SizedBox(height: 20),

                                  // Clinical Images Gallery
                                  _buildImageGallerySection(selectedVisit),
                                  const SizedBox(height: 24),

                                  // Consultant Clinical Decision & Prescription Section
                                  _buildConsultantDecisionForm(selectedVisit),
                                ],
                              ),
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

  Widget _buildQueueCard(
    ClinicProvider provider,
    Visit visit,
    Visit? selectedVisit,
  ) {
    final isSelected = selectedVisit?.id == visit.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          provider.selectVisit(visit);
          _loadVisitData(visit);
          if (visit.status == AppConstants.statusWaitingConsultant) {
            provider.acceptPatientByConsultant(visit);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryLight.withValues(alpha: 0.5)
                : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.slate200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${visit.queueNumber ?? "1"} ${visit.patient?.name ?? "Patient"}',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  CustomBadge.fromStatus(visit.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Age: ${visit.patient?.calculatedAge ?? visit.patient?.dob ?? "-"} • Phone: ${visit.patient?.phone ?? "-"}',
                style: TextStyle(fontSize: 11, color: AppTheme.slate500),
              ),
              if (visit.chiefComplaint != null &&
                  visit.chiefComplaint!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  visit.chiefComplaint!,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.slate700,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsultantHeaderBanner(Visit visit) {
    final patient = visit.patient;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primary,
              child: Text(
                '#${visit.queueNumber ?? "1"}',
                style: TextStyle(
                  color: AppTheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      patient?.name ?? 'Unknown Patient',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    CustomBadge.fromStatus(visit.status),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'DOB: ${patient?.dob ?? "-"} (${patient?.calculatedAge != null ? "${patient!.calculatedAge} yrs" : "-"}) • Phone: ${patient?.phone ?? "-"} • Gender: ${patient?.gender ?? "-"}',
                  style: TextStyle(fontSize: 12, color: AppTheme.slate500),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: AppTheme.onSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onPressed: _isGeneratingPdf ? null : () => _printReport(visit),
              icon: _isGeneratingPdf
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print_rounded, size: 18),
              label: const Text('Print / Export PDF'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIntakeReviewCard(Visit visit) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.slate200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.folder_shared_outlined,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Resident Doctor Intake & Medical History',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.secondary,
                    ),
                  ),
                ],
              ),
              Text(
                'Recorded by: ${visit.residentName?.isNotEmpty == true ? "Dr. ${visit.residentName}" : "Resident Doctor"}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.slate500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),

          _buildHistoryRow('Chief Complaint:', visit.chiefComplaint),
          const SizedBox(height: 8),
          _buildHistoryRow(
            'History of Present Illness (HPI):',
            visit.historyPresentIllness,
          ),
          const SizedBox(height: 8),
          _buildHistoryRow(
            'Past Medical & Surgical History:',
            visit.pastMedicalHistory,
          ),
          const SizedBox(height: 8),
          _buildHistoryRow(
            'Drug History & Allergies:',
            visit.drugHistoryAllergies,
          ),
          const SizedBox(height: 8),
          _buildHistoryRow(
            'Clinical Examination & Resident Assessment:',
            visit.examinationNotes ?? visit.residentAssessment,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(String label, String? value) {
    final text = (value != null && value.trim().isNotEmpty)
        ? value.trim()
        : 'None recorded';
    final hasValue = value != null && value.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 220,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: hasValue ? AppTheme.secondary : AppTheme.slate400,
              fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVitalsMatrix(Visit visit) {
    final v = visit.vitalSigns;
    if (v.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.slate50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.monitor_heart_outlined,
              color: AppTheme.slate400,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'No vital signs recorded during resident intake.',
              style: TextStyle(color: AppTheme.slate500, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.monitor_heart_outlined,
                color: AppTheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Vital Signs',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildVitalBadge('BP', v.bloodPressure ?? '-', 'mmHg'),
              _buildVitalBadge('Heart Rate', v.heartRate ?? '-', 'bpm'),
              _buildVitalBadge('Temp', v.temperature ?? '-', '°C'),
              _buildVitalBadge('SpO2', v.spo2 ?? '-', '%'),
              _buildVitalBadge('Weight', v.weight ?? '-', 'kg'),
              _buildVitalBadge('Height', v.height ?? '-', 'cm'),
              _buildVitalBadge(
                'BMI',
                v.bmi != null ? v.bmi!.toStringAsFixed(1) : '-',
                'kg/m²',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalBadge(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.slate500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondary,
          ),
        ),
        Text(unit, style: TextStyle(fontSize: 10, color: AppTheme.slate400)),
      ],
    );
  }

  Widget _buildImageGallerySection(Visit visit) {
    if (visit.images.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.slate50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              color: AppTheme.slate400,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'No clinical images or investigation files attached.',
              style: TextStyle(color: AppTheme.slate500, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.photo_library_outlined,
              color: AppTheme.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Attached Investigations & Scans (${visit.images.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: visit.images.map((filename) {
            final url = visit.getImageUrl(filename);
            return InkWell(
              onTap: () => ImageViewerDialog.show(
                context,
                imageUrl: url,
                title: filename,
              ),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.slate200),
                  color: AppTheme.cardBg,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.shadow,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      child: SizedBox(
                        height: 90,
                        width: double.infinity,
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: AppTheme.slate100,
                            child: Icon(
                              Icons.broken_image,
                              color: AppTheme.slate400,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Text(
                        filename,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildConsultantDecisionForm(Visit visit) {
    final provider = context.watch<ClinicProvider>();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // color: const Color(0xFFF0FDF4), // soft emerald tint
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.successLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment_turned_in_outlined,
                color: AppTheme.success,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Consultant Diagnosis, Plan & Prescription',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Diagnosis
          const Text(
            'Final Clinical Diagnosis *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _diagnosisController,
            decoration: const InputDecoration(
              hintText: 'e.g. Acute Bronchitis, Essential Hypertension...',
            ),
          ),
          const SizedBox(height: 14),

          // Treatment Plan & Prescription
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Management / Treatment Plan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _planController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText:
                            'Lifestyle advice, follow-up timeline, tests ordered...',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Prescription / Medications',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _prescriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText:
                            'e.g. Amoxicillin 500mg TDS x 7 days, Paracetamol 1g PRN...',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Additional Notes & Consultant Name
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Special Notes / Follow-up',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        hintText: 'Review in 2 weeks or if symptoms worsen...',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Consultant Name',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _consultantNameController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.badge_outlined, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: provider.isLoading
                    ? null
                    : () => _saveAssessment(visit, markCompleted: false),
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('Save Assessment Draft'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                ),
                onPressed: provider.isLoading
                    ? null
                    : () => _saveAssessment(visit, markCompleted: true),
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text('Finalize & Complete Visit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
