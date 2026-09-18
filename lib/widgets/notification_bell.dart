import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/notification.dart';
import '../providers/clinic_provider.dart';

/// Bell icon with unread badge; opens the in-app notification center.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  void _openNotifications(BuildContext context) {
    final provider = context.read<ClinicProvider>();
    provider.markAllNotificationsRead();
    showDialog(
      context: context,
      builder: (_) => const _NotificationsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final unread = provider.unreadNotificationCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          icon: Icon(
            Icons.notifications_none_rounded,
            size: 22,
            color: unread > 0 ? AppTheme.accent : AppTheme.slate700,
          ),
          onPressed: () => _openNotifications(context),
        ),
        if (unread > 0)
          Positioned(
            top: 6,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.danger,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBg, width: 1.5),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationsDialog extends StatelessWidget {
  const _NotificationsDialog();

  IconData _iconFor(AppNotification n) {
    switch (n.type) {
      case AppConstants.notifTypePatientSentBack:
        return Icons.undo_rounded;
      case AppConstants.notifTypeReferredToManagement:
        return Icons.forward_to_inbox_rounded;
      case AppConstants.notifTypeOperationScheduled:
        return Icons.event_available_rounded;
      case AppConstants.notifTypeOperationUpdated:
        return Icons.event_note_rounded;
      case AppConstants.notifTypeOperationImagesAdded:
        return Icons.add_photo_alternate_outlined;
      case AppConstants.notifTypePrescriptionAdded:
        return Icons.medication_outlined;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(AppNotification n) {
    switch (n.type) {
      case AppConstants.notifTypePatientSentBack:
        return AppTheme.accent;
      case AppConstants.notifTypeReferredToManagement:
        return AppTheme.warning;
      case AppConstants.notifTypeOperationScheduled:
        return AppTheme.success;
      case AppConstants.notifTypeOperationUpdated:
        return AppTheme.primary;
      case AppConstants.notifTypeOperationImagesAdded:
        return AppTheme.purple;
      case AppConstants.notifTypePrescriptionAdded:
        return AppTheme.success;
      default:
        return AppTheme.slate500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final notifications = provider.notifications;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
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
                      Icons.notifications_active_outlined,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Notifications',
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
              child: notifications.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 40,
                        horizontal: 20,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 42,
                            color: AppTheme.slate400,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No notifications yet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.slate700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Updates about visits and operations will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.slate500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final n = notifications[idx];
                        return _buildNotificationTile(context, n);
                      },
                    ),
            ),

            if (notifications.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: TextButton.icon(
                  onPressed: () => context
                      .read<ClinicProvider>()
                      .markAllNotificationsRead(),
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: const Text('Mark all as read'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(BuildContext context, AppNotification n) {
    final color = _colorFor(n);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_iconFor(n), size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondary,
                  ),
                ),
                if (n.body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    n.body,
                    style: TextStyle(fontSize: 12, color: AppTheme.slate700),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  n.created != null
                      ? DateFormat('MMM d, yyyy • hh:mm a').format(n.created!)
                      : '',
                  style: TextStyle(fontSize: 10.5, color: AppTheme.slate500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}