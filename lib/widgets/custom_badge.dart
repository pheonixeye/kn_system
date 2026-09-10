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
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        ic = Icons.hourglass_top_rounded;
        break;
      case AppConstants.statusWithResident:
        bg = const Color(0xFFE0E7FF);
        fg = const Color(0xFF4338CA);
        ic = Icons.medical_services_outlined;
        break;
      case AppConstants.statusWaitingConsultant:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        ic = Icons.assignment_late_outlined;
        break;
      case AppConstants.statusWithConsultant:
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        ic = Icons.person_search_outlined;
        break;
      case AppConstants.statusCompleted:
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF047857);
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
        vertical: isSmall ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color ?? AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: isSmall ? 12 : 14,
              color: textColor ?? AppTheme.primary,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: isSmall ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: textColor ?? AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
