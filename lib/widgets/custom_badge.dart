import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';

class CustomBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;
  final IconData? icon;
  final bool isSmall;

  const CustomBadge({
    super.key,
    required this.label,
    this.color,
    this.textColor,
    this.icon,
    this.isSmall = false,
  });

  factory CustomBadge.fromStatus(String status) {
    Color bg;
    Color fg;
    IconData ic;

    switch (status) {
      case AppConstants.statusWaitingResident:
        bg = AppTheme.warningLight;
        fg = AppTheme.warning;
        ic = Icons.hourglass_top_rounded;
        break;
      case AppConstants.statusWithResident:
        bg = AppTheme.indigoLight;
        fg = AppTheme.indigo;
        ic = Icons.medical_services_outlined;
        break;
      case AppConstants.statusWaitingConsultant:
        bg = AppTheme.primaryLight;
        fg = AppTheme.primary;
        ic = Icons.assignment_late_outlined;
        break;
      case AppConstants.statusWithConsultant:
        bg = AppTheme.purpleLight;
        fg = AppTheme.purple;
        ic = Icons.person_search_outlined;
        break;
      case AppConstants.statusSentToManagement:
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        ic = Icons.event_note_rounded;
        break;
      case AppConstants.statusCompleted:
        bg = AppTheme.successLight;
        fg = AppTheme.success;
        ic = Icons.check_circle_outline_rounded;
        break;
      default:
        bg = AppTheme.slate100;
        fg = AppTheme.slate700;
        ic = Icons.info_outline;
    }

    return CustomBadge(
      label: AppConstants.formatStatus(status),
      color: bg,
      textColor: fg,
      icon: ic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 10,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color ?? AppTheme.slate100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (textColor ?? AppTheme.slate700).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: isSmall ? 12 : 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: isSmall ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: textColor ?? AppTheme.slate700,
            ),
          ),
        ],
      ),
    );
  }
}
