import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/services/pdf_service.dart';
import '../core/theme/app_theme.dart';
import '../models/consultant_case_report.dart';
import '../models/operation.dart';
import '../models/visit.dart';
import '../providers/clinic_provider.dart';

/// Lets the consultant build a comprehensive case report for a patient.
///
/// - Picks one visit as the source of diagnosis / management plan / prescription.
/// - Assigns each visit's intake images to one of three documentation categories
///   (initial assessment, FU post FUE, final result).
/// - Selects which operations (with intra-operative images) to include.
typedef _VisitImageGroup = ({Visit visit, List<String> images});

class ConsultantCaseReportDialog extends StatefulWidget {
  final String patientId;
  final String patientName;

  const ConsultantCaseReportDialog({
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
      builder: (_) => ConsultantCaseReportDialog(
        patientId: patientId,
        patientName: patientName,
      ),
    );
  }

  @override
  State<ConsultantCaseReportDialog> createState() =>
      _ConsultantCaseReportDialogState();
}

class _ConsultantCaseReportDialogState
    extends State<ConsultantCaseReportDialog> {
  String? _sourceVisitId;
  final Map<String, ReportImageCategory?> _categoryByVisit = {};
  final Map<String, bool> _includeOperation = {};
  bool _isGenerating = false;
  bool _isLoading = true;

  ClinicProvider get _provider => context.read<ClinicProvider>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await _provider.fetchPatientVisitsHistory(widget.patientId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      final visits = _sortedVisits();
      List<Visit> candidates = [];
      for (final v in visits) {
        if (v.consultantDiagnosis?.trim().isNotEmpty == true ||
            v.consultantPlan?.trim().isNotEmpty == true ||
            v.consultantPrescription?.trim().isNotEmpty == true) {
          candidates.add(v);
        }
      }
      if (candidates.isEmpty && visits.isNotEmpty) {
        candidates = [visits.first];
      }
      _sourceVisitId = candidates.isNotEmpty ? candidates.first.id : null;
      for (final v in visits) {
        _categoryByVisit[v.id] = null;
      }
      for (final op in _provider.getPatientOperations(widget.patientId)) {
        _includeOperation[op.id] = true;
      }
    });
  }

  List<Visit> _sortedVisits() {
    final visits = _provider.getPatientVisits(widget.patientId) ?? <Visit>[];
    final list = List<Visit>.from(visits);
    list.sort((a, b) {
      final da = DateTime.tryParse(a.visitDate ?? '');
      final db = DateTime.tryParse(b.visitDate ?? '');
      if (da != null && db != null) return da.compareTo(db);
      return (a.visitDate ?? '').compareTo(b.visitDate ?? '');
    });
    return list;
  }

  List<_VisitImageGroup> _visitImageGroups() {
    final groups = <_VisitImageGroup>[];
    for (final v in _sortedVisits()) {
      if (v.images.isNotEmpty) {
        groups.add((visit: v, images: List<String>.from(v.images)));
      }
    }
    return groups;
  }

  ConsultantCaseReportData _buildReport() {
    final visitsById = {for (final v in _sortedVisits()) v.id: v};

    final initial = <ReportImageGroup>[];
    final fu = <ReportImageGroup>[];
    final finalResult = <ReportImageGroup>[];

    for (final entry in _categoryByVisit.entries) {
      final visit = visitsById[entry.key];
      if (visit == null || entry.value == null) continue;
      final images = List<String>.from(visit.images);
      if (images.isEmpty) continue;
      final group = ReportImageGroup(visit: visit, images: images);
      switch (entry.value!) {
        case ReportImageCategory.initialAssessment:
          initial.add(group);
        case ReportImageCategory.fuPostFue:
          fu.add(group);
        case ReportImageCategory.finalResult:
          finalResult.add(group);
      }
    }

    final operations = _provider
        .getPatientOperations(widget.patientId)
        .where((op) => _includeOperation[op.id] ?? false)
        .toList();

    final source = visitsById[_sourceVisitId];

    return ConsultantCaseReportData(
      patient: _provider.patients
          .where((p) => p.id == widget.patientId)
          .firstOrNull!,
      sourceVisit: source,
      initialAssessment: initial,
      fuPostFue: fu,
      finalResult: finalResult,
      operations: operations,
    );
  }

  Future<void> _generate() async {
    final report = _buildReport();
    if (report.sourceVisit == null) {
      _showSnack(AppTheme.warning, 'Please select a source visit first.');
      return;
    }
    setState(() => _isGenerating = true);
    try {
      await PdfService.printConsultantCaseReport(report);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: const Text(
              'Consultant case report sent to the print dialog!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack(AppTheme.danger, 'Error generating case report: $e');
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showSnack(Color color, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(backgroundColor: color, content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final visits = _sortedVisits();
    final imageGroups = _visitImageGroups();
    final operations = _provider.getPatientOperations(widget.patientId);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
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
                      Icons.description_outlined,
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
                          'Consultant Case Report',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.secondary,
                          ),
                        ),
                        Text(
                          '${widget.patientName} • ${visits.length} visits • ${operations.length} operations',
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

            // Content
            Flexible(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          text('Visit Type and Clinical Source'),
                          if (visits.isEmpty)
                            _emptyBox('No visits recorded for this patient.')
                          else
                            DropdownButtonFormField<String>(
                              initialValue: _sourceVisitId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(
                                  Icons.assignment_outlined,
                                  size: 18,
                                ),
                              ),
                              items: visits.map((v) {
                                final date = v.visitDate ?? 'unknown date';
                                final hasClinical =
                                    v.consultantDiagnosis?.trim().isNotEmpty ==
                                    true;
                                return DropdownMenuItem<String>(
                                  value: v.id,
                                  child: Text(
                                    'Visit ${DateFormat("dd MMM yyyy").format(DateTime.tryParse(date) ?? DateTime.now())}${hasClinical ? " • has diagnosis" : ""}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _sourceVisitId = value);
                              },
                            ),
                          if (_sourceVisitId != null) ...[
                            const SizedBox(height: 8),
                            _sourceVisitPreview(),
                          ],
                          const SizedBox(height: 20),
                          text('Documentation Categories (by visit)'),
                          if (imageGroups.isEmpty)
                            _emptyBox(
                              'No intake images on any visit to categorise.',
                            )
                          else
                            ...imageGroups.map(
                              (g) => _buildImageCategoryRow(g),
                            ),
                          const SizedBox(height: 20),
                          text('Operative Details & Intra-Operative Images'),
                          if (operations.isEmpty)
                            _emptyBox(
                              'No operations recorded for this patient.',
                            )
                          else
                            ...operations.map(
                              (op) => _buildOperationRow(context, op),
                            ),
                        ],
                      ),
                    ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _chip(
                    '${_categoryByVisit.values.where((c) => c != null).length} categorised',
                    AppTheme.primary,
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isGenerating ? null : _generate,
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.print_outlined, size: 16),
                        label: Text(
                          _isGenerating
                              ? 'Generating...'
                              : 'Generate & Print Report',
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
    );
  }

  Widget text(String s) {
    return Text(
      s,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppTheme.secondary,
      ),
    );
  }

  Widget _sourceVisitPreview() {
    final source = _sortedVisits()
        .where((v) => v.id == _sourceVisitId)
        .firstOrNull;
    if (source == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.successLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.successLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _previewRow('Diagnosis', source.consultantDiagnosis),
          _previewRow('Management Plan', source.consultantPlan),
          _previewRow('Prescription', source.consultantPrescription),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: AppTheme.slate500),
            ),
          ),
          Expanded(
            child: Text(
              value == null || value.trim().isEmpty
                  ? 'Not recorded'
                  : value.trim(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCategoryRow(_VisitImageGroup group) {
    final visit = group.visit;
    final date = visit.visitDate != null
        ? DateFormat(
            'dd MMM yyyy',
          ).format(DateTime.tryParse(visit.visitDate!) ?? DateTime.now())
        : 'unknown date';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.photo_library_outlined,
              size: 20,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondary,
                  ),
                ),
                Text(
                  '${group.images.length} image${group.images.length == 1 ? "" : "s"}',
                  style: TextStyle(fontSize: 11, color: AppTheme.slate500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          DropdownButtonHideUnderline(
            child: DropdownButton<ReportImageCategory?>(
              value: _categoryByVisit[visit.id],
              isDense: true,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondary,
              ),
              items: [
                const DropdownMenuItem<ReportImageCategory?>(
                  value: null,
                  child: Text('Not categorised'),
                ),
                ...ReportImageCategory.values.map((c) {
                  return DropdownMenuItem<ReportImageCategory?>(
                    value: c,
                    child: Text(c.label),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() => _categoryByVisit[visit.id] = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationRow(BuildContext context, Operation op) {
    final date = op.dateTime != null
        ? DateFormat('dd MMM yyyy hh:mm a').format(op.dateTime!)
        : 'pending';
    final included = _includeOperation[op.id] ?? false;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: included
            ? AppTheme.purpleLight.withValues(alpha: 0.25)
            : AppTheme.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: included ? AppTheme.purple : AppTheme.slate200,
          width: included ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: included,
            activeColor: AppTheme.purple,
            onChanged: (v) {
              setState(() => _includeOperation[op.id] = v ?? false);
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$date • ${op.patient?.name ?? "Patient"}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondary,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 3,
                  children: [
                    _chip(
                      '${op.graftsExpected ?? 0} expected',
                      AppTheme.primary,
                    ),
                    _chip('${op.graftsDone ?? 0} done', AppTheme.success),
                    _chip(
                      '${op.intraOpImages.length} intra-op images',
                      AppTheme.purple,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 12, color: AppTheme.slate500),
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
