import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/visit.dart';
import '../../models/vital_signs.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clinic_provider.dart';
import '../../widgets/custom_badge.dart';
import '../../widgets/image_dropzone.dart';

class ResidentScreen extends StatefulWidget {
  const ResidentScreen({super.key});

  @override
  State<ResidentScreen> createState() => _ResidentScreenState();
}

class _ResidentScreenState extends State<ResidentScreen> {
  final _chiefComplaintController = TextEditingController();
  final _hpiController = TextEditingController();
  final _pmhController = TextEditingController();
  final _drugAllergiesController = TextEditingController();
  final _examNotesController = TextEditingController();
  final _assessmentController = TextEditingController();
  final _residentNameController = TextEditingController(
    text: 'Resident Doctor',
  );

  // Vitals
  final _bpController = TextEditingController();
  final _hrController = TextEditingController();
  final _tempController = TextEditingController();
  final _spo2Controller = TextEditingController();
  final _respController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _bloodSugarController = TextEditingController();

  final GlobalKey<ImageDropzoneState> _dropzoneKey =
      GlobalKey<ImageDropzoneState>();
  List<StagedImageFile> _stagedImages = [];
  String? _currentLoadedVisitId;

  @override
  void dispose() {
    _chiefComplaintController.dispose();
    _hpiController.dispose();
    _pmhController.dispose();
    _drugAllergiesController.dispose();
    _examNotesController.dispose();
    _assessmentController.dispose();
    _residentNameController.dispose();

    _bpController.dispose();
    _hrController.dispose();
    _tempController.dispose();
    _spo2Controller.dispose();
    _respController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _bloodSugarController.dispose();
    super.dispose();
  }

  void _loadVisitData(Visit visit) {
    _currentLoadedVisitId = visit.id;
    _chiefComplaintController.text = visit.chiefComplaint ?? '';
    _hpiController.text = visit.historyPresentIllness ?? '';
    _pmhController.text = visit.pastMedicalHistory ?? '';
    _drugAllergiesController.text = visit.drugHistoryAllergies ?? '';
    _examNotesController.text = visit.examinationNotes ?? '';
    _assessmentController.text = visit.residentAssessment ?? '';
    if (visit.residentName != null && visit.residentName!.isNotEmpty) {
      _residentNameController.text = visit.residentName!;
    }

    final v = visit.vitalSigns;
    _bpController.text = v.bloodPressure ?? '';
    _hrController.text = v.heartRate ?? '';
    _tempController.text = v.temperature ?? '';
    _spo2Controller.text = v.spo2 ?? '';
    _respController.text = v.respiratoryRate ?? '';
    _weightController.text = v.weight ?? '';
    _heightController.text = v.height ?? '';
    _bloodSugarController.text = v.bloodSugar ?? '';

    _stagedImages.clear();
  }

  double? _calculateBmi() {
    final w = double.tryParse(_weightController.text);
    final h = double.tryParse(_heightController.text);
    if (w != null && h != null && h > 0) {
      final hMeters = h / 100.0;
      return w / (hMeters * hMeters);
    }
    return null;
  }

  VitalSigns _buildVitalSigns() {
    return VitalSigns(
      bloodPressure: _bpController.text.isNotEmpty ? _bpController.text : null,
      heartRate: _hrController.text.isNotEmpty ? _hrController.text : null,
      temperature: _tempController.text.isNotEmpty
          ? _tempController.text
          : null,
      spo2: _spo2Controller.text.isNotEmpty ? _spo2Controller.text : null,
      respiratoryRate: _respController.text.isNotEmpty
          ? _respController.text
          : null,
      weight: _weightController.text.isNotEmpty ? _weightController.text : null,
      height: _heightController.text.isNotEmpty ? _heightController.text : null,
      bloodSugar: _bloodSugarController.text.isNotEmpty
          ? _bloodSugarController.text
          : null,
    );
  }

  Future<void> _saveIntake(Visit visit, {bool sendToConsultant = false}) async {
    final provider = context.read<ClinicProvider>();
    final operatorName = context.read<AuthProvider>().currentUser?.name?.trim();
    final residentName = (operatorName != null && operatorName.isNotEmpty)
        ? operatorName
        : _residentNameController.text.trim();
    if (residentName.isNotEmpty) {
      _residentNameController.text = residentName;
    }

    final multipartFiles = _stagedImages
        .map((s) => s.toMultipartFile())
        .toList();

    try {
      await provider.saveResidentIntake(
        visit: visit,
        chiefComplaint: _chiefComplaintController.text,
        historyPresentIllness: _hpiController.text,
        pastMedicalHistory: _pmhController.text,
        drugHistoryAllergies: _drugAllergiesController.text,
        vitalSigns: _buildVitalSigns(),
        examinationNotes: _examNotesController.text,
        residentAssessment: _assessmentController.text,
        residentName: residentName,
        newImages: multipartFiles.isNotEmpty ? multipartFiles : null,
        sendToConsultant: sendToConsultant,
      );

      _dropzoneKey.currentState?.clearStaged();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text(
              sendToConsultant
                  ? 'Patient medical intake submitted & forwarded to Consultant!'
                  : 'Medical intake draft saved successfully!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('Error saving medical intake: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final visits = provider.visits;

    // Filter queue for resident
    final residentQueue = visits.where((v) {
      return v.status == AppConstants.statusWaitingResident ||
          v.status == AppConstants.statusWithResident;
    }).toList();

    final selectedVisit =
        provider.selectedVisit ??
        (residentQueue.isNotEmpty ? residentQueue.first : null);

    if (selectedVisit != null && _currentLoadedVisitId != selectedVisit.id) {
      _loadVisitData(selectedVisit);
    }

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Resident Queue Panel
            SizedBox(
              width: 340,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                  Icons.queue_rounded,
                                  color: AppTheme.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Resident Queue',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.secondary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.warningLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${residentQueue.length} Waiting',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Queue List
                      Expanded(
                        child: residentQueue.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      size: 40,
                                      color: AppTheme.success,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No patients waiting in queue',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.slate500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: residentQueue.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final visit = residentQueue[index];
                                  final isSelected =
                                      selectedVisit?.id == visit.id;
                                  final isWithResident =
                                      visit.status ==
                                      AppConstants.statusWithResident;

                                  return InkWell(
                                    onTap: () {
                                      provider.selectVisit(visit);
                                      _loadVisitData(visit);
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryLight.withValues(
                                                alpha: 0.5,
                                              )
                                            : AppTheme.cardBg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primary
                                              : AppTheme.slate200,
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            // mainAxisAlignment:
                                            //     MainAxisAlignment.spaceBetween,
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              Text(
                                                '#${visit.queueNumber ?? (index + 1)} ${visit.patient?.name ?? "Patient"}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: AppTheme.secondary,
                                                ),
                                              ),
                                              CustomBadge.fromStatus(
                                                visit.status,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Age: ${visit.patient?.calculatedAge ?? visit.patient?.dob ?? "-"} • ${visit.patient?.gender ?? "-"}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.slate500,
                                            ),
                                          ),
                                          if (visit.chiefComplaint != null &&
                                              visit
                                                  .chiefComplaint!
                                                  .isNotEmpty) ...[
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
                                          if (!isWithResident) ...[
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: double.infinity,
                                              height: 30,
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppTheme.primary,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                      ),
                                                ),
                                                onPressed: () => provider
                                                    .acceptPatientByResident(
                                                      visit,
                                                    ),
                                                icon: const Icon(
                                                  Icons.person_add,
                                                  size: 14,
                                                ),
                                                label: const Text(
                                                  'Accept Patient',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),

            // Right: Medical History & Intake Workspace
            Expanded(
              child: selectedVisit == null
                  ? Card(
                      child: Center(
                        child: Text(
                          'Select a patient from the queue to start intake.',
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
                            // Patient Info Banner
                            _buildPatientHeaderBanner(selectedVisit),
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 20),

                            // Section 1: Chief Complaint & HPI
                            Row(
                              children: [
                                Icon(
                                  Icons.medical_information_outlined,
                                  color: AppTheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '1. Clinical Presentation & History',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Chief Complaint (Reason for consultation)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _chiefComplaintController,
                                        maxLines: 2,
                                        decoration: const InputDecoration(
                                          hintText:
                                              'e.g. Sharp chest pain radiating to left shoulder...',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'History of Present Illness (HPI)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _hpiController,
                                        maxLines: 2,
                                        decoration: const InputDecoration(
                                          hintText:
                                              'Onset, duration, character, aggravating/relieving factors...',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Past Medical & Surgical History',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _pmhController,
                                        maxLines: 2,
                                        decoration: const InputDecoration(
                                          hintText:
                                              'Hypertension, Diabetes, previous surgeries, hospitalizations...',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Drug History & Known Allergies',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _drugAllergiesController,
                                        maxLines: 2,
                                        decoration: const InputDecoration(
                                          hintText:
                                              'Current medications, Penicillin allergy, food allergies...',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Section 2: Vital Signs
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.monitor_heart_outlined,
                                      color: AppTheme.primary,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '2. Vital Signs & Anthropometrics',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_calculateBmi() != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'BMI: ${_calculateBmi()!.toStringAsFixed(1)} kg/m²',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Vitals Inputs Grid
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _buildVitalField(
                                  'Blood Pressure',
                                  _bpController,
                                  '120/80',
                                  'mmHg',
                                  width: 140,
                                ),
                                _buildVitalField(
                                  'Heart Rate',
                                  _hrController,
                                  '72',
                                  'bpm',
                                  width: 120,
                                ),
                                _buildVitalField(
                                  'Temperature',
                                  _tempController,
                                  '37.0',
                                  '°C',
                                  width: 120,
                                ),
                                _buildVitalField(
                                  'SpO2',
                                  _spo2Controller,
                                  '98',
                                  '%',
                                  width: 110,
                                ),
                                _buildVitalField(
                                  'Resp. Rate',
                                  _respController,
                                  '16',
                                  'breaths/min',
                                  width: 130,
                                ),
                                _buildVitalField(
                                  'Weight',
                                  _weightController,
                                  '75',
                                  'kg',
                                  width: 110,
                                  onChanged: () => setState(() {}),
                                ),
                                _buildVitalField(
                                  'Height',
                                  _heightController,
                                  '175',
                                  'cm',
                                  width: 110,
                                  onChanged: () => setState(() {}),
                                ),
                                _buildVitalField(
                                  'Blood Sugar',
                                  _bloodSugarController,
                                  '110',
                                  'mg/dL',
                                  width: 130,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Section 3: Physical Examination & Resident Impressions
                            Row(
                              children: [
                                Icon(
                                  Icons.rate_review_outlined,
                                  color: AppTheme.primary,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '3. Physical Examination & Initial Assessment',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Clinical Examination Notes',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _examNotesController,
                                        maxLines: 3,
                                        decoration: const InputDecoration(
                                          hintText:
                                              'General appearance, Chest, CVS, Abdomen, Neuro exam findings...',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Resident Preliminary Assessment / Impressions',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _assessmentController,
                                        maxLines: 3,
                                        decoration: const InputDecoration(
                                          hintText:
                                              'Differential diagnosis, summary of clinical intake...',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Section 4: Drag & Drop Clinical Images
                            ImageDropzone(
                              key: _dropzoneKey,
                              existingImages: selectedVisit.images,
                              getImageUrl: (name) =>
                                  selectedVisit.getImageUrl(name),
                              onDeleteExistingImage: (name) => provider
                                  .deleteVisitImage(selectedVisit, name),
                              onFilesChanged: (files) {
                                _stagedImages = files;
                              },
                            ),
                            const SizedBox(height: 28),
                            const Divider(),
                            const SizedBox(height: 20),

                            // Actions Bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: 200,
                                  child: TextField(
                                    controller: _residentNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Resident Doctor Name',
                                      prefixIcon: Icon(Icons.badge, size: 16),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: provider.isLoading
                                          ? null
                                          : () => _saveIntake(
                                              selectedVisit,
                                              sendToConsultant: false,
                                            ),
                                      icon: const Icon(
                                        Icons.save_outlined,
                                        size: 16,
                                      ),
                                      label: const Text('Save Draft'),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      onPressed: provider.isLoading
                                          ? null
                                          : () => _saveIntake(
                                              selectedVisit,
                                              sendToConsultant: true,
                                            ),
                                      icon: const Icon(
                                        Icons.send_rounded,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Submit & Send to Consultant',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientHeaderBanner(Visit visit) {
    final patient = visit.patient;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Row(
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CustomBadge.fromStatus(visit.status),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Phone: ${patient?.phone ?? "-"} • DOB: ${patient?.dob ?? "-"} (${patient?.calculatedAge != null ? "${patient!.calculatedAge} yrs" : "-"}) • Gender: ${patient?.gender ?? "-"}',
                    style: TextStyle(fontSize: 12, color: AppTheme.slate500),
                  ),
                ],
              ),
            ],
          ),
          Text(
            'Visit Date: ${visit.visitDate ?? DateFormat("yyyy-MM-dd").format(DateTime.now())}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.slate500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalField(
    String label,
    TextEditingController controller,
    String hint,
    String unit, {
    double width = 120,
    VoidCallback? onChanged,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate700,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            onChanged: (_) => onChanged?.call(),
            decoration: InputDecoration(
              hintText: hint,
              suffixText: unit,
              suffixStyle: TextStyle(fontSize: 10, color: AppTheme.slate400),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
