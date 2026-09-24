import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/pdf_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/visit.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clinic_provider.dart';
import '../../widgets/custom_badge.dart';
import '../../widgets/image_dropzone.dart';
import '../../widgets/image_viewer_dialog.dart';
import '../../widgets/operation_booking_dialog.dart';
import '../../widgets/operations_calendar_widget.dart';
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
  bool _showOperationsCalendar = false;
  List<StagedImageFile> _stagedPrescriptionFiles = [];
  bool _isUploadingPrescription = false;
  String _selectedVisitType = AppConstants.notSpecified;

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
    _selectedVisitType = visit.visitType ?? AppConstants.notSpecified;
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
        visitType: _selectedVisitType,
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

  Future<void> _sendBackToResident(Visit visit) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.undo_rounded, color: AppTheme.warning),
            const SizedBox(width: 8),
            const Text('Send Back to Resident'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will move patient ${visit.patient?.name ?? "this patient"} back to the Resident Doctor queue for re-intake or further evaluation.',
              style: TextStyle(fontSize: 13, color: AppTheme.slate700),
            ),
            const SizedBox(height: 14),
            const Text(
              'Instructions / Notes for Resident (Optional):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText:
                    'e.g. Please check blood pressure again, take clearer scalp photo...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.undo_rounded, size: 16),
            label: const Text('Send Back'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final provider = context.read<ClinicProvider>();
        final combinedNotes = [
          if (_notesController.text.trim().isNotEmpty)
            _notesController.text.trim(),
          if (noteController.text.trim().isNotEmpty)
            'Consultant note to resident: ${noteController.text.trim()}',
        ].join('\n');

        await provider.sendVisitBackToResident(
          visit,
          notes: combinedNotes,
          consultantName: _currentOperatorName(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.warning,
              content: const Text(
                'Patient has been sent back to the Resident Doctor queue.',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.danger,
              content: Text('Failed to send visit back to resident: $e'),
            ),
          );
        }
      }
    }
    noteController.dispose();
  }

  Future<void> _sendToManagement(Visit visit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.calendar_month_rounded, color: AppTheme.purple),
            const SizedBox(width: 8),
            const Text('Refer to Management'),
          ],
        ),
        content: Text(
          'Send patient ${visit.patient?.name ?? "this patient"} to the Management screen for operation scheduling and pre-op booking?',
          style: TextStyle(fontSize: 13, color: AppTheme.slate700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.purple,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Send to Management'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final provider = context.read<ClinicProvider>();
        await provider.sendVisitToManagement(
          visit,
          diagnosis: _diagnosisController.text,
          plan: _planController.text,
          prescription: _prescriptionController.text,
          notes: _notesController.text,
          consultantName: _currentOperatorName(),
          visitType: _selectedVisitType,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.purple,
              content: const Text(
                'Patient referred to Management for operation scheduling!',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.danger,
              content: Text('Failed to refer patient to management: $e'),
            ),
          );
        }
      }
    }
  }

  String _currentOperatorName() {
    final operatorName = context.read<AuthProvider>().currentUser?.name?.trim();
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
      final updatedVisit = visit.id == _currentLoadedVisitId
          ? visit.copyWith(
              consultantDiagnosis: _diagnosisController.text,
              consultantPlan: _planController.text,
              consultantPrescription: _prescriptionController.text,
              consultantNotes: _notesController.text,
              consultantName: _currentOperatorName(),
            )
          : visit;

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

  Future<void> _pickPrescriptionImages() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'],
      );
      if (result.isNotEmpty) {
        final newFiles = <StagedImageFile>[];
        for (final file in result) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            newFiles.add(StagedImageFile(name: file.name, bytes: bytes));
          }
        }
        if (newFiles.isNotEmpty && mounted) {
          setState(() {
            _stagedPrescriptionFiles = [
              ..._stagedPrescriptionFiles,
              ...newFiles,
            ];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking prescription file: $e')),
        );
      }
    }
  }

  Future<void> _attachPrescriptionImage(Visit visit) async {
    if (_stagedPrescriptionFiles.isEmpty) return;
    final provider = context.read<ClinicProvider>();
    final consultantName = _currentOperatorName();
    setState(() => _isUploadingPrescription = true);
    try {
      final files = _stagedPrescriptionFiles
          .map(
            (s) => s.toMultipartFile(
              field: '${AppConstants.visitPrescriptionImagesField}+',
            ),
          )
          .toList();
      await provider.addVisitPrescriptionImages(
        visit,
        files,
        consultantName: consultantName,
      );
      if (mounted) {
        setState(() => _stagedPrescriptionFiles.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: const Text(
              'Prescription image attached & the resident has been notified!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('Error attaching prescription image: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPrescription = false);
    }
  }

  Future<void> _printPrescription(Visit visit) async {
    try {
      final updatedVisit = visit.id == _currentLoadedVisitId
          ? visit.copyWith(
              consultantPrescription: _prescriptionController.text,
              consultantName: _currentOperatorName(),
            )
          : visit;
      await PdfService.printPrescriptionPdf(updatedVisit);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('Error generating prescription PDF: $e'),
          ),
        );
      }
    }
  }

  Widget _buildPrescriptionImageSection(Visit visit) {
    final provider = context.watch<ClinicProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.medication_outlined, color: AppTheme.success, size: 18),
            const SizedBox(width: 8),
            Text(
              'Prescription Image / Medication Sheet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.secondary,
              ),
            ),
            const Spacer(),
            // if (visit.prescriptionImages.isNotEmpty)
            OutlinedButton.icon(
              onPressed: _isGeneratingPdf
                  ? null
                  : () => _printPrescription(visit),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text('Print Prescription'),
            ),
            if (visit.prescriptionImages.isNotEmpty) const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: provider.isLoading || _isUploadingPrescription
                  ? null
                  : _pickPrescriptionImages,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              icon: const Icon(Icons.upload_file_rounded, size: 16),
              label: const Text('Attach Image'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visit.prescriptionImages.isEmpty &&
            _stagedPrescriptionFiles.isEmpty)
          Container(
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
                  'No prescription image attached yet.',
                  style: TextStyle(color: AppTheme.slate500, fontSize: 12),
                ),
              ],
            ),
          ),
        if (visit.prescriptionImages.isNotEmpty ||
            _stagedPrescriptionFiles.isNotEmpty) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ...visit.prescriptionImages.map((filename) {
                final url = visit.getImageUrl(filename);
                return _buildPrescriptionImageCard(visit, filename, url);
              }),
              ..._stagedPrescriptionFiles.asMap().entries.map((entry) {
                return _buildStagedPrescriptionCard(entry.key, entry.value);
              }),
            ],
          ),
          if (_stagedPrescriptionFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                  ),
                  onPressed: provider.isLoading || _isUploadingPrescription
                      ? null
                      : () => _attachPrescriptionImage(visit),
                  icon: _isUploadingPrescription
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text(
                    _isUploadingPrescription
                        ? 'Uploading...'
                        : 'Upload & Notify Resident',
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () =>
                      setState(() => _stagedPrescriptionFiles.clear()),
                  child: const Text('Clear staged'),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildPrescriptionImageCard(Visit visit, String filename, String url) {
    return Container(
      width: 150,
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
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                child: SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      color: AppTheme.slate100,
                      child: Icon(Icons.broken_image, color: AppTheme.slate400),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => ImageViewerDialog.show(
                        context,
                        imageUrl: url,
                        title: filename,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.fullscreen,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => providerDeletePrescription(visit, filename),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              filename,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> providerDeletePrescription(Visit visit, String filename) async {
    final provider = context.read<ClinicProvider>();
    try {
      await provider.deleteVisitPrescriptionImage(visit, filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: const Text('Prescription image removed.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('Failed to remove prescription image: $e'),
          ),
        );
      }
    }
  }

  Widget _buildStagedPrescriptionCard(int index, StagedImageFile stagedFile) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
        color: AppTheme.cardBg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                child: SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: Image.memory(
                    stagedFile.bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      color: AppTheme.primaryLight,
                      child: Center(
                        child: Icon(
                          Icons.insert_drive_file,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: () => setState(() {
                    _stagedPrescriptionFiles.removeAt(index);
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              stagedFile.name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showPastVisitsDialog(
    Visit currentVisit,
    List<Visit> pastVisits,
    bool isLoading,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
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
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Patient Visit History',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.secondary,
                              ),
                            ),
                            Text(
                              '${currentVisit.patient?.name ?? "Patient"} • ${pastVisits.length} previous visit${pastVisits.length == 1 ? "" : "s"}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.slate500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : pastVisits.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder_open_outlined,
                                size: 48,
                                color: AppTheme.slate400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No previous visits recorded for this patient.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.slate700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'This is the patient\'s first consultation.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.slate400,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: pastVisits.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, idx) {
                            final pastVisit = pastVisits[idx];
                            return _buildPastVisitCard(
                              pastVisit,
                              isDialog: true,
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPastVisitReviseDialog(Visit pastVisit) {
    final diagCtrl = TextEditingController(
      text: pastVisit.consultantDiagnosis ?? '',
    );
    final planCtrl = TextEditingController(
      text: pastVisit.consultantPlan ?? '',
    );
    final rxCtrl = TextEditingController(
      text: pastVisit.consultantPrescription ?? '',
    );
    final notesCtrl = TextEditingController(
      text: pastVisit.consultantNotes ?? '',
    );
    final nameCtrl = TextEditingController(
      text: (pastVisit.consultantName?.isNotEmpty == true)
          ? pastVisit.consultantName!
          : _currentOperatorName(),
    );

    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 850,
                  maxHeight: 750,
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.edit_note_rounded,
                                color: AppTheme.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Review & Revise Visit Record',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.secondary,
                                  ),
                                ),
                                Text(
                                  'Visit Date: ${pastVisit.visitDate ?? "Historical"} • Queue #${pastVisit.queueNumber ?? "-"} • Patient: ${pastVisit.patient?.name ?? "Patient"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.slate500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            CustomBadge.fromStatus(pastVisit.status),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(dialogCtx).pop(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.slate50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.slate200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.assignment_outlined,
                                        size: 16,
                                        color: AppTheme.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Resident Intake Details',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: AppTheme.secondary,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (pastVisit.residentName?.isNotEmpty ==
                                          true)
                                        Text(
                                          'Dr. ${pastVisit.residentName}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.slate500,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _buildHistoryRow(
                                    'Chief Complaint:',
                                    pastVisit.chiefComplaint,
                                  ),
                                  const SizedBox(height: 6),
                                  _buildHistoryRow(
                                    'HPI:',
                                    pastVisit.historyPresentIllness,
                                  ),
                                  const SizedBox(height: 6),
                                  _buildHistoryRow(
                                    'Medical History:',
                                    pastVisit.pastMedicalHistory,
                                  ),
                                  const SizedBox(height: 6),
                                  _buildHistoryRow(
                                    'Drug History & Allergies:',
                                    pastVisit.drugHistoryAllergies,
                                  ),
                                  const SizedBox(height: 6),
                                  _buildHistoryRow(
                                    'Exam / Assessment:',
                                    pastVisit.examinationNotes ??
                                        pastVisit.residentAssessment,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            _buildVitalsMatrix(pastVisit),
                            const SizedBox(height: 14),

                            if (pastVisit.images.isNotEmpty) ...[
                              _buildImageGallerySection(pastVisit),
                              const SizedBox(height: 16),
                            ],

                            // Editable Consultant Assessment Section
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                // color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.successLight,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.health_and_safety_outlined,
                                        color: AppTheme.success,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Consultant Assessment & Prescription (Editable)',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Clinical Diagnosis',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: diagCtrl,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter clinical diagnosis...',
                                      // fillColor: Colors.white,
                                      filled: true,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Treatment Plan',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            TextField(
                                              controller: planCtrl,
                                              maxLines: 3,
                                              decoration: const InputDecoration(
                                                hintText:
                                                    'Management and recommendations...',
                                                // fillColor: Colors.white,
                                                filled: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Prescription / Medications',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            TextField(
                                              controller: rxCtrl,
                                              maxLines: 3,
                                              decoration: const InputDecoration(
                                                hintText:
                                                    'Prescribed medications...',
                                                // fillColor: Colors.white,
                                                filled: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Special Notes / Follow-up',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            TextField(
                                              controller: notesCtrl,
                                              decoration: const InputDecoration(
                                                hintText: 'Follow-up notes...',
                                                // fillColor: Colors.white,
                                                filled: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Consultant Name',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            TextField(
                                              controller: nameCtrl,
                                              decoration: const InputDecoration(
                                                prefixIcon: Icon(
                                                  Icons.badge_outlined,
                                                  size: 16,
                                                ),
                                                // fillColor: Colors.white,
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
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _printReport(pastVisit),
                          icon: const Icon(Icons.print_rounded, size: 16),
                          label: const Text('Print Visit PDF'),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.of(dialogCtx).pop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.success,
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      setModalState(() => isSaving = true);
                                      try {
                                        final provider = context
                                            .read<ClinicProvider>();
                                        final revised = await provider
                                            .reviseVisitAssessment(
                                              visit: pastVisit,
                                              diagnosis: diagCtrl.text,
                                              plan: planCtrl.text,
                                              prescription: rxCtrl.text,
                                              notes: notesCtrl.text,
                                              consultantName: nameCtrl.text,
                                            );

                                        if (dialogCtx.mounted) {
                                          Navigator.of(dialogCtx).pop();
                                        }

                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              backgroundColor: AppTheme.success,
                                              content: Text(
                                                'Visit record of ${revised.visitDate ?? "past date"} updated successfully!',
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setModalState(() => isSaving = false);
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              backgroundColor: AppTheme.danger,
                                              content: Text(
                                                'Error updating visit: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Save Revised Assessment'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final visits = provider.visits;

    final readyVisits = visits.where((v) {
      return v.status == AppConstants.statusWaitingConsultant ||
          v.status == AppConstants.statusWithConsultant;
    }).toList();

    // Patients referred to management remain visible in the consultant queue.
    final sentToManagementVisits = visits
        .where((v) => v.status == AppConstants.statusSentToManagement)
        .toList();

    final completedVisits = visits
        .where((v) => v.status == AppConstants.statusCompleted)
        .toList();

    final selectedVisit =
        provider.selectedVisit ??
        (readyVisits.isNotEmpty
            ? readyVisits.first
            : (sentToManagementVisits.isNotEmpty
                  ? sentToManagementVisits.first
                  : (completedVisits.isNotEmpty
                        ? completedVisits.first
                        : null)));

    if (selectedVisit != null && _currentLoadedVisitId != selectedVisit.id) {
      _loadVisitData(selectedVisit);
    }

    // Patient History & Visit Counts
    final patientId = selectedVisit?.patientId ?? '';
    final patientHistory = patientId.isNotEmpty
        ? (provider.getPatientVisits(patientId) ?? [])
        : <Visit>[];
    final isLoadingHistory =
        patientId.isNotEmpty && provider.isPatientVisitsLoading(patientId);
    final totalPatientVisitsCount = patientHistory.isNotEmpty
        ? patientHistory.length
        : (selectedVisit != null ? 1 : 0);
    final pastVisits = selectedVisit != null
        ? patientHistory.where((v) => v.id != selectedVisit.id).toList()
        : <Visit>[];

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Top Stats Banner (Only Today's Visits)
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
                    title: 'Today\'s Completed',
                    value: '${completedVisits.length}',
                    icon: Icons.task_alt_rounded,
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Today\'s Total Visits',
                    value: '${visits.length}',
                    icon: Icons.analytics_outlined,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // View Toggle: Case Management | Operation Schedule
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.slate100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.slate200),
                  ),
                  child: Row(
                    children: [
                      _buildViewToggle(
                        icon: Icons.assessment_outlined,
                        label: 'Case Management',
                        selected: !_showOperationsCalendar,
                        onTap: () =>
                            setState(() => _showOperationsCalendar = false),
                      ),
                      _buildViewToggle(
                        icon: Icons.calendar_month_outlined,
                        label: 'Operation Schedule',
                        selected: _showOperationsCalendar,
                        onTap: () =>
                            setState(() => _showOperationsCalendar = true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

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
                                      sentToManagementVisits.isEmpty &&
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
                                            padding: const EdgeInsets.symmetric(
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
                                        if (sentToManagementVisits
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 6,
                                            ),
                                            child: Text(
                                              'SENT TO MANAGEMENT',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.slate500,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          ...sentToManagementVisits.map(
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
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 6,
                                            ),
                                            child: Text(
                                              'TODAY\'S COMPLETED VISITS',
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
                    child: _showOperationsCalendar
                        ? Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryLight,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.calendar_month_rounded,
                                          color: AppTheme.primary,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Operations Schedule',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.secondary,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Consultant bookable • Management is notified',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.slate500,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      OutlinedButton.icon(
                                        onPressed: _bookOperation,
                                        icon: const Icon(Icons.add, size: 14),
                                        label: const Text('Book Operation'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: OperationsCalendarPanel(
                                      operations: provider.operations,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : selectedVisit == null
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
                                  // Top Header & Visit Count Indicator & Print PDF Button
                                  _buildConsultantHeaderBanner(
                                    selectedVisit,
                                    totalPatientVisitsCount,
                                    pastVisits,
                                    isLoadingHistory,
                                  ),
                                  const SizedBox(height: 20),
                                  const Divider(),
                                  const SizedBox(height: 20),

                                  // Medical History Summary Box (Collected by Resident)
                                  _buildIntakeReviewCard(selectedVisit),
                                  const SizedBox(height: 20),

                                  // Vital Signs Matrix
                                  _buildVitalsMatrix(selectedVisit),
                                  const SizedBox(height: 20),

                                  // Attached Clinical Images Gallery
                                  _buildImageGallerySection(selectedVisit),
                                  const SizedBox(height: 24),

                                  // Consultant Clinical Decision & Prescription Section
                                  _buildConsultantDecisionForm(selectedVisit),
                                  const SizedBox(height: 24),

                                  // Patient Past Visits History Section
                                  _buildPatientHistorySection(
                                    selectedVisit,
                                    pastVisits,
                                    totalPatientVisitsCount,
                                    isLoadingHistory,
                                  ),
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

  Future<void> _bookOperation() async {
    final provider = context.read<ClinicProvider>();
    final selected = provider.selectedVisit;
    final preselectedPatient =
        selected?.patient ??
        provider.patients.where((p) => p.id == selected?.patientId).firstOrNull;

    final op = await OperationBookingDialog.show(
      context,
      preselectedPatient: preselectedPatient,
    );
    if (op != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.success,
          content: Text(
            'Operation booked for ${op.patient?.name ?? "patient"}!',
          ),
        ),
      );
    }
  }

  Widget _buildViewToggle({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppTheme.onPrimary : AppTheme.slate500,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? AppTheme.onPrimary : AppTheme.slate700,
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
                children: [
                  Text(
                    '#${visit.queueNumber ?? "1"} ${visit.patient?.name ?? "Patient"}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
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

  Widget _buildConsultantHeaderBanner(
    Visit visit,
    int totalVisitsCount,
    List<Visit> pastVisits,
    bool isLoadingHistory,
  ) {
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
                    const SizedBox(width: 10),

                    // Indicator of the number of visits the patient has visited
                    Tooltip(
                      message: totalVisitsCount > 1
                          ? 'This patient has $totalVisitsCount total visits on record (${pastVisits.length} previous).'
                          : 'This is the patient\'s first visit at the clinic.',
                      child: InkWell(
                        onTap: pastVisits.isNotEmpty
                            ? () => _showPastVisitsDialog(
                                visit,
                                pastVisits,
                                isLoadingHistory,
                              )
                            : null,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: totalVisitsCount > 1
                                ? const Color(0xFFEFF6FF)
                                : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: totalVisitsCount > 1
                                  ? const Color(0xFF93C5FD)
                                  : const Color(0xFF86EFAC),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                totalVisitsCount > 1
                                    ? Icons.history_rounded
                                    : Icons.stars_rounded,
                                size: 14,
                                color: totalVisitsCount > 1
                                    ? AppTheme.primary
                                    : AppTheme.success,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                totalVisitsCount > 1
                                    ? '$totalVisitsCount Visits (${pastVisits.length} Past)'
                                    : '1st Visit',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: totalVisitsCount > 1
                                      ? AppTheme.primary
                                      : AppTheme.success,
                                ),
                              ),
                              if (totalVisitsCount > 1) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.open_in_new_rounded,
                                  size: 11,
                                  color: AppTheme.primary,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
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
            if (pastVisits.isNotEmpty) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(
                    color: AppTheme.primary.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onPressed: () =>
                    _showPastVisitsDialog(visit, pastVisits, isLoadingHistory),
                icon: const Icon(Icons.history_edu_outlined, size: 18),
                label: Text('Old Visits (${pastVisits.length})'),
              ),
              const SizedBox(width: 10),
            ],
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

          // Visit Type Selector
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Visit Type',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedVisitType,
                hint: const Text('Select visit type'),
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.category_outlined, size: 18),
                ),
                items: [
                  // const DropdownMenuItem<String>(
                  //   value: null,
                  //   child: Text('Not specified'),
                  // ),
                  ...AppConstants.visitTypeValues.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(
                        AppConstants.formatVisitType(type),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedVisitType = value);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Diagnosis
          const Text(
            'Final Clinical Diagnosis *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _diagnosisController,
            decoration: const InputDecoration(
              hintText:
                  'e.g. Male Pattern Alopecia Norwood IV, Scalp Folliculitis...',
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
                            'Lifestyle advice, surgical recommendation, follow-up timeline...',
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
                            'e.g. Minoxidil 5% topical spray, Finasteride 1mg OD x 3 months...',
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
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Prescription Image / Medication Sheet Section
          _buildPrescriptionImageSection(visit),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 20),

          // Action Buttons: Routing Actions (Send Back / Send to Management) & Saving Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Routing Actions (Left)
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.warning,
                      side: BorderSide(color: AppTheme.warning),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onPressed: provider.isLoading
                        ? null
                        : () => _sendBackToResident(visit),
                    icon: const Icon(Icons.undo_rounded, size: 16),
                    label: const Text('Send Back to Resident'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onPressed: provider.isLoading
                        ? null
                        : () => _sendToManagement(visit),
                    icon: const Icon(Icons.calendar_month_rounded, size: 16),
                    label: const Text('Send to Management'),
                  ),
                ],
              ),

              // Saving / Finalizing Actions (Right)
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: provider.isLoading
                        ? null
                        : () => _saveAssessment(visit, markCompleted: false),
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Save Draft'),
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
        ],
      ),
    );
  }

  Widget _buildPatientHistorySection(
    Visit currentVisit,
    List<Visit> pastVisits,
    int totalVisitsCount,
    bool isLoadingHistory,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200),
      ),
      padding: const EdgeInsets.all(20),
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
                      Icons.history_edu_outlined,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Patient Visit History & Previous Consultations',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$totalVisitsCount total visit${totalVisitsCount == 1 ? "" : "s"}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              if (isLoadingHistory)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          if (pastVisits.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.slate400,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No previous visits found on record. This is the patient\'s first visit at the clinic.',
                      style: TextStyle(color: AppTheme.slate700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pastVisits.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final pastVisit = pastVisits[idx];
                return _buildPastVisitCard(pastVisit, isDialog: false);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPastVisitCard(Visit pastVisit, {required bool isDialog}) {
    final v = pastVisit.vitalSigns;
    final hasVitals = !v.isEmpty;
    final hasDiagnosis = pastVisit.consultantDiagnosis?.isNotEmpty == true;
    final hasPrescription =
        pastVisit.consultantPrescription?.isNotEmpty == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      'Date: ${pastVisit.visitDate ?? "Historical"}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (pastVisit.queueNumber != null) ...[
                    Text(
                      'Queue #${pastVisit.queueNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slate700,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  CustomBadge.fromStatus(pastVisit.status),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _printReport(pastVisit),
                    icon: const Icon(Icons.print_outlined, size: 14),
                    label: const Text('Print Report'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _showPastVisitReviseDialog(pastVisit),
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: const Text('View & Revise Record'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          if (pastVisit.chiefComplaint?.isNotEmpty == true) ...[
            _buildHistoryRow('Chief Complaint:', pastVisit.chiefComplaint),
            const SizedBox(height: 6),
          ],
          if (pastVisit.examinationNotes?.isNotEmpty == true ||
              pastVisit.residentAssessment?.isNotEmpty == true) ...[
            _buildHistoryRow(
              'Resident Notes:',
              pastVisit.examinationNotes ?? pastVisit.residentAssessment,
            ),
            const SizedBox(height: 6),
          ],

          if (hasDiagnosis) ...[
            _buildHistoryRow(
              'Consultant Diagnosis:',
              pastVisit.consultantDiagnosis,
            ),
            const SizedBox(height: 6),
          ],
          if (hasPrescription) ...[
            _buildHistoryRow(
              'Past Prescription:',
              pastVisit.consultantPrescription,
            ),
            const SizedBox(height: 6),
          ],
          if (pastVisit.consultantPlan?.isNotEmpty == true) ...[
            _buildHistoryRow('Management Plan:', pastVisit.consultantPlan),
            const SizedBox(height: 6),
          ],

          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (hasVitals) ...[
                if (v.bloodPressure != null)
                  _buildMiniVitalChip('BP', v.bloodPressure!),
                if (v.heartRate != null)
                  _buildMiniVitalChip('HR', '${v.heartRate} bpm'),
                if (v.temperature != null)
                  _buildMiniVitalChip('Temp', '${v.temperature}°C'),
                if (v.weight != null)
                  _buildMiniVitalChip('Weight', '${v.weight} kg'),
              ],
              if (pastVisit.images.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 13,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${pastVisit.images.length} Attached Scans',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniVitalChip(String label, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Text(
        '$label: $val',
        style: TextStyle(
          fontSize: 11,
          color: AppTheme.slate700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
