import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/clinic_provider.dart';
import 'custom_badge.dart';

/// Live-updating Active Queue list tied to ClinicProvider.
///
/// Watches the provider directly so it stays in sync with realtime
/// updates, matching the logic used inside the receptionist tab. Shows
/// only today's visits; the optional [searchQuery] narrows the queue by
/// patient name/phone.
class ActiveQueueView extends StatelessWidget {
  const ActiveQueueView({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final visits = provider.visits.where((v) => v.visitDate == today).toList();

    final query = searchQuery.toLowerCase().trim();
    final filtered = visits.where((v) {
      if (query.isEmpty) return true;
      final name = v.patient?.name.toLowerCase() ?? '';
      final phone = v.patient?.phone.toLowerCase() ?? '';
      return name.contains(query) || phone.contains(query);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: AppTheme.slate400),
            const SizedBox(height: 8),
            Text(
              query.isEmpty
                  ? 'No active visits in the queue.'
                  : 'No visits match your search.',
              style: TextStyle(color: AppTheme.slate500, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final visit = filtered[index];
        final patient = visit.patient;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          leading: CircleAvatar(
            backgroundColor: AppTheme.primaryLight,
            child: Text(
              '#${visit.queueNumber ?? (index + 1)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppTheme.primary,
              ),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  patient?.name ?? 'Unknown Patient',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (patient?.gender != null) ...[
                Text(
                  '(${patient!.gender})',
                  style: TextStyle(fontSize: 12, color: AppTheme.slate400),
                ),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                'Phone: ${patient?.phone ?? "-"} • DOB: ${patient?.dob ?? "-"} • Date: ${visit.visitDate ?? "-"}',
                style: TextStyle(fontSize: 12, color: AppTheme.slate500),
              ),
              if (visit.chiefComplaint != null &&
                  visit.chiefComplaint!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Complaint: ${visit.chiefComplaint}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.slate700,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          trailing: CustomBadge.fromStatus(visit.status),
        );
      },
    );
  }
}
