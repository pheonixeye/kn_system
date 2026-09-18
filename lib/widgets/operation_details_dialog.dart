import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/services/pdf_service.dart';
import '../core/theme/app_theme.dart';
import '../models/operation.dart';
import 'image_viewer_dialog.dart';

/// Read-only operation details dialog with a Print Operation PDF action.
/// Used by the consultant schedule (and reused where operations are shown).
class OperationDetailsDialog extends StatelessWidget {
  final Operation operation;

  const OperationDetailsDialog({super.key, required this.operation});

  static void show(BuildContext context, Operation operation) {
    showDialog(
      context: context,
      builder: (_) => OperationDetailsDialog(operation: operation),
    );
  }

  Future<void> _print(BuildContext context) async {
    Navigator.of(context).pop();
    await PdfService.printOperationReport(operation);
  }

  @override
  Widget build(BuildContext context) {
    final op = operation;
    final patient = op.patient;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 700),
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
                          'Operation Details',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.secondary,
                          ),
                        ),
                        Text(
                          op.dateTime != null
                              ? DateFormat('EEEE, MMMM d, yyyy • hh:mm a')
                                  .format(op.dateTime!)
                              : 'Date not set',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Patient info
                    _buildInfoSection(
                      icon: Icons.person_outline,
                      title: 'PATIENT',
                      children: [
                        _infoRow(
                          'Name',
                          patient?.name ?? 'Unknown Patient',
                          bold: true,
                        ),
                        _infoRow('Phone', patient?.phone ?? '-'),
                        _infoRow(
                          'Age / Gender',
                          '${patient?.calculatedAge != null ? "${patient!.calculatedAge} yrs" : (patient?.dob ?? "-")} • ${patient?.gender ?? "-"}',
                        ),
                        if (patient?.nationalId?.isNotEmpty == true)
                          _infoRow('National ID', patient!.nationalId!),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Operation info
                    _buildInfoSection(
                      icon: Icons.schedule_rounded,
                      title: 'OPERATION',
                      children: [
                        _infoRow(
                          'Booked At',
                          op.dateTime != null
                              ? DateFormat('EEEE, dd MMMM yyyy • hh:mm a')
                                  .format(op.dateTime!)
                              : '-',
                        ),
                        _infoRow(
                          'Grafts Expected',
                          '${op.graftsExpected ?? 0}',
                        ),
                        _infoRow('Grafts Done', '${op.graftsDone ?? 0}'),
                        _infoRow(
                          'Added By',
                          op.addedBy != null
                              ? '${op.addedByLabel} • ${op.addedBy!.type.label}'
                              : '-',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Financial summary
                    _buildInfoSection(
                      icon: Icons.payments_outlined,
                      title: 'FINANCIAL SUMMARY',
                      children: [
                        _infoRow(
                          'Total Price',
                          op.totalPrice != null
                              ? '${op.totalPrice!.toStringAsFixed(0)} EGP'
                              : '-',
                        ),
                        _infoRow(
                          'Deposit',
                          op.deposit != null
                              ? '${op.deposit!.toStringAsFixed(0)} EGP'
                              : '-',
                          accent: AppTheme.success,
                        ),
                        _infoRow(
                          'Remaining at Operation',
                          op.remainingAtOperation != null
                              ? '${op.remainingAtOperation!.toStringAsFixed(0)} EGP'
                              : '-',
                          accent: AppTheme.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Intra-op images
                    _buildInfoSection(
                      icon: Icons.image_outlined,
                      title:
                          'INTRA-OP IMAGES (${op.intraOpImages.length})',
                      children: [
                        if (op.intraOpImages.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              'No intra-operative images attached.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.slate500,
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: op.intraOpImages.map((filename) {
                              final url = op.getImageUrl(filename);
                              return InkWell(
                                onTap: () => ImageViewerDialog.show(
                                  context,
                                  imageUrl: url,
                                  title: filename,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 120,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.slate200,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        color: AppTheme.slate100,
                                        child: Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            color: AppTheme.slate400,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
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
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Close'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _print(context),
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Print Operation PDF'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
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
              Icon(icon, size: 15, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? accent, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppTheme.slate500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: accent ?? AppTheme.slate700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}