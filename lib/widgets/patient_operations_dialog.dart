import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/operation.dart';
import '../providers/clinic_provider.dart';
import 'image_dropzone.dart';
import 'operation_booking_dialog.dart';
import 'operation_details_dialog.dart';

/// Lists every operation on record for a patient and allows viewing,
/// editing and managing intra-operative images.
///
/// Used from the receptionist "All Patients" directory so that residents
/// and consultants can find and modify operation details.
class PatientOperationsDialog extends StatelessWidget {
  final String patientId;
  final String patientName;
  final bool canModify;

  const PatientOperationsDialog({
    super.key,
    required this.patientId,
    required this.patientName,
    this.canModify = true,
  });

  static Future<void> show(
    BuildContext context, {
    required String patientId,
    required String patientName,
    bool canModify = true,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => PatientOperationsDialog(
        patientId: patientId,
        patientName: patientName,
        canModify: canModify,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final operations = provider.getPatientOperations(patientId);

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
                      Icons.local_hospital_rounded,
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
                          'Patient Operations',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.secondary,
                          ),
                        ),
                        Text(
                          '$patientName • ${operations.length} operation${operations.length == 1 ? "" : "s"} on record',
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
              child: operations.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 40,
                        horizontal: 20,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_busy_outlined,
                            size: 42,
                            color: AppTheme.slate400,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No operations scheduled for this patient yet.',
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
                      itemCount: operations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final op = operations[idx];
                        return _buildOperationCard(context, op);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationCard(BuildContext context, Operation op) {
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
                  op.dateTime != null
                      ? DateFormat('MMM d, yyyy • hh:mm a').format(
                          op.dateTime!.toLocal(),
                        )
                      : 'Pending',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _chip(
                      '${op.graftsExpected ?? 0} expected',
                      AppTheme.primary,
                    ),
                    _chip('${op.graftsDone ?? 0} done', AppTheme.success),
                    if (op.totalPrice != null)
                      _chip(
                        'Total ${op.totalPrice!.toStringAsFixed(0)}',
                        AppTheme.primary,
                      ),
                    if (op.remainingAtOperation != null)
                      _chip(
                        'Remaining ${op.remainingAtOperation!.toStringAsFixed(0)}',
                        AppTheme.warning,
                      ),
                    if (op.intraOpImages.isNotEmpty)
                      _chip(
                        '${op.intraOpImages.length} images',
                        AppTheme.purple,
                      ),
                    _chip('Added by ${op.addedByLabel}', AppTheme.slate500),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => OperationDetailsDialog.show(context, op),
                icon: const Icon(Icons.visibility_outlined, size: 14),
                label: const Text('View Details'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              ),
              if (canModify) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => OperationBookingDialog.show(
                    context,
                    operationToEdit: op,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) =>
                        OperationImagesEditorDialog(operation: op),
                  ),
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 14,
                  ),
                  label: const Text('Images'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                ),
              ],
            ],
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

/// Adds and removes intra-operative images for an operation.
class OperationImagesEditorDialog extends StatefulWidget {
  final Operation operation;

  const OperationImagesEditorDialog({super.key, required this.operation});

  @override
  State<OperationImagesEditorDialog> createState() =>
      _OperationImagesEditorDialogState();
}

class _OperationImagesEditorDialogState
    extends State<OperationImagesEditorDialog> {
  final GlobalKey<ImageDropzoneState> _dropzoneKey =
      GlobalKey<ImageDropzoneState>();
  List<StagedImageFile> _stagedFiles = [];
  bool _isSaving = false;

  Future<void> _saveImages() async {
    if (_stagedFiles.isEmpty) return;
    final uploadedCount = _stagedFiles.length;
    setState(() => _isSaving = true);
    try {
      final provider = context.read<ClinicProvider>();
      await provider.addOperationImages(
        _latestOperation(provider) ?? widget.operation,
        _stagedFiles
            .map((s) => s.toMultipartFile(field: 'intra_op_images+'))
            .toList(),
      );
      if (mounted) {
        _dropzoneKey.currentState?.clearStaged();
        setState(() => _stagedFiles = []);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text(
              '$uploadedCount intra-operative image(s) added to the record!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('Failed to add operation images: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Operation? _latestOperation(ClinicProvider provider) {
    return provider.operations
        .where((o) => o.id == widget.operation.id)
        .firstOrNull;
  }

  Future<void> _deleteImage(String filename) async {
    try {
      final provider = context.read<ClinicProvider>();
      await provider.removeOperationImage(
        _latestOperation(provider) ?? widget.operation,
        filename,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('Failed to remove image: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final op = _latestOperation(provider) ?? widget.operation;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 680),
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
                      Icons.add_photo_alternate_outlined,
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
                          'Intra-Operative Images',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.secondary,
                          ),
                        ),
                        Text(
                          '${op.patient?.name ?? "Patient"} • ${op.dateTime != null ? DateFormat("MMM d, yyyy • hh:mm a").format(op.dateTime!.toLocal()) : "Pending"}',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: ImageDropzone(
                  key: _dropzoneKey,
                  title: 'Intra-Operative Images',
                  subtitle:
                      'Upload only intra-operative photos (PNG, JPG, WEBP — up to 50MB each)',
                  acceptedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
                  existingImages: op.intraOpImages,
                  getImageUrl: (name) => op.getImageUrl(name),
                  onDeleteExistingImage: _deleteImage,
                  onFilesChanged: (files) =>
                      setState(() => _stagedFiles = files),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving || _stagedFiles.isEmpty
                        ? null
                        : _saveImages,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.upload_rounded, size: 16),
                    label: Text(
                      _stagedFiles.isEmpty
                          ? 'No Pending Files'
                          : 'Upload ${_stagedFiles.length}',
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
}
