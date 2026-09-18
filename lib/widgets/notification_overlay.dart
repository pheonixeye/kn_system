import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/notification.dart';
import '../providers/clinic_provider.dart';

/// Wraps the app and shows transient notification cards that slide in from
/// the left edge whenever a new notification is created for the current user.
///
/// Cards are automatically dismissed after [autoDismiss] or when tapped. When
/// a newer notification arrives it is inserted on top and the older cards slide
/// downwards to make room.
class NotificationOverlay extends StatefulWidget {
  final Widget child;
  final Duration autoDismiss;

  const NotificationOverlay({
    super.key,
    required this.child,
    this.autoDismiss = const Duration(seconds: 5),
  });

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _ToastEntry {
  final AppNotification notification;
  bool visible = false;
  bool leaving = false;

  _ToastEntry(this.notification);
}

class _NotificationOverlayState extends State<NotificationOverlay> {
  static const double _cardWidth = 360;
  static const double _cardHeight = 120;
  static const double _gap = 12;
  static const double _margin = 16;
  static const int _maxVisible = 4;
  static const Duration _slideDuration = Duration(milliseconds: 320);

  final List<_ToastEntry> _toasts = [];
  StreamSubscription<AppNotification>? _subscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscription != null) return;
    final provider = context.read<ClinicProvider>();
    _subscription = provider.incomingNotifications.listen(_onIncoming);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onIncoming(AppNotification notification) {
    if (!mounted) return;
    if (_toasts.any((t) => t.notification.id == notification.id)) return;

    final entry = _ToastEntry(notification);
    setState(() {
      _toasts.insert(0, entry);
      while (_toasts.length > _maxVisible) {
        _toasts.removeLast();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _toasts.contains(entry)) {
        setState(() => entry.visible = true);
      }
    });

    Timer(widget.autoDismiss, () => _dismiss(entry));
  }

  void _dismiss(_ToastEntry entry) {
    if (entry.leaving || !_toasts.contains(entry)) return;
    entry.leaving = true;
    setState(() => entry.visible = false);
    Timer(_slideDuration, () {
      if (mounted) {
        setState(() => _toasts.remove(entry));
      }
    });
  }

  void _handleTap(_ToastEntry entry) {
    context.read<ClinicProvider>().markNotificationRead(entry.notification);
    _dismiss(entry);
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[widget.child];

    for (var index = 0; index < _toasts.length; index++) {
      final entry = _toasts[index];
      final double top = _margin + index * (_cardHeight + _gap);
      final double left = entry.visible
          ? _margin
          : -(_cardWidth + _margin + 24);

      children.add(
        AnimatedPositioned(
          duration: _slideDuration,
          curve: Curves.easeOutCubic,
          top: top,
          left: left,
          child: AnimatedOpacity(
            duration: _slideDuration,
            opacity: entry.visible ? 1 : 0,
            child: SizedBox(
              width: _cardWidth,
              height: _cardHeight,
              child: _NotificationToastCard(
                notification: entry.notification,
                onTap: () => _handleTap(entry),
                onClose: () => _dismiss(entry),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(clipBehavior: Clip.none, children: children);
  }
}

class _NotificationToastCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _NotificationToastCard({
    required this.notification,
    required this.onTap,
    required this.onClose,
  });

  IconData _iconFor(String type) {
    switch (type) {
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

  Color _colorFor(String type) {
    switch (type) {
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
    final color = _colorFor(notification.type);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.slate200),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadow,
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _iconFor(notification.type),
                                size: 16,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                notification.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.secondary,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: onClose,
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: AppTheme.slate400,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            notification.body,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.25,
                              color: AppTheme.slate700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
