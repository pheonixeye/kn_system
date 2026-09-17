import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clinic_provider.dart';
import '../../providers/theme_provider.dart';
import '../consultant/consultant_screen.dart';
import '../management/management_screen.dart';
import '../receptionist/receptionist_screen.dart';
import '../resident/resident_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final visits = provider.visits;

    final userType = auth.currentUser?.type ?? UserType.receptionist;

    final screens = <Widget>[
      const ReceptionistScreen(),
      if (userType.canAccessResidentScreen) const ResidentScreen(),
      if (userType.canAccessConsultantScreen) const ConsultantScreen(),
      if (userType.canAccessManagementScreen) const ManagementScreen(),
    ];

    final index = _currentIndex < screens.length ? _currentIndex : 0;

    final residentCount = visits
        .where(
          (v) =>
              v.status == AppConstants.statusWaitingResident ||
              v.status == AppConstants.statusWithResident,
        )
        .length;

    final consultantCount = visits
        .where(
          (v) =>
              v.status == AppConstants.statusWaitingConsultant ||
              v.status == AppConstants.statusWithConsultant,
        )
        .length;

    final managementCount = visits
        .where((v) => v.status == AppConstants.statusSentToManagement)
        .length;

    final tabs =
        <
          ({
            String title,
            IconData icon,
            IconData activeIcon,
            int? badgeCount,
            Color? badgeColor,
          })
        >[
          (
            title: 'Receptionist',
            icon: Icons.person_add_alt_1_outlined,
            activeIcon: Icons.person_add_alt_1_rounded,
            badgeCount: null,
            badgeColor: null,
          ),
          if (userType.canAccessResidentScreen)
            (
              title: 'Resident Doctor',
              icon: Icons.medical_services_outlined,
              activeIcon: Icons.medical_services_rounded,
              badgeCount: residentCount,
              badgeColor: AppTheme.warning,
            ),
          if (userType.canAccessConsultantScreen)
            (
              title: 'Consultant Dashboard',
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              badgeCount: consultantCount,
              badgeColor: AppTheme.accent,
            ),
          if (userType.canAccessManagementScreen)
            (
              title: 'Management',
              icon: Icons.calendar_month_outlined,
              activeIcon: Icons.calendar_month_rounded,
              badgeCount: managementCount > 0 ? managementCount : null,
              badgeColor: AppTheme.purple,
            ),
        ];

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            border: Border(
              bottom: BorderSide(color: AppTheme.slate200, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadow,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SafeArea(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Clinic Brand Logo
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.local_hospital_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.appTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.secondary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'ProKliniK Clinical Workflow System',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.slate500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 40),

                  // Navigation Tabs
                  Row(
                    children: List.generate(tabs.length, (i) {
                      final item = tabs[i];
                      final isSelected = index == i;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setState(() => _currentIndex = i),
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? item.activeIcon : item.icon,
                                  size: 18,
                                  color: isSelected
                                      ? AppTheme.onPrimary
                                      : AppTheme.slate500,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? AppTheme.onPrimary
                                        : AppTheme.slate700,
                                  ),
                                ),
                                if (item.badgeCount != null &&
                                    item.badgeCount! > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white
                                          : (item.badgeColor ??
                                                AppTheme.accent),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${item.badgeCount}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? AppTheme.primary
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 40),

                  // Right Side Actions: Real-time Indicator, Theme, User Info & Logout
                  Row(
                    children: [
                      // Realtime Status Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppTheme.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Live Sync',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Dark/Light Theme Toggle
                      IconButton(
                        tooltip: themeProvider.isDark
                            ? 'Switch to Light Mode'
                            : 'Switch to Dark Mode',
                        icon: Icon(
                          themeProvider.isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_outlined,
                          size: 20,
                          color: AppTheme.slate700,
                        ),
                        onPressed: () => themeProvider.toggleTheme(),
                      ),
                      const SizedBox(width: 8),

                      // User Info Badge
                      if (auth.currentUser != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.slate100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.account_circle_outlined,
                                size: 16,
                                color: AppTheme.slate700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                auth.currentUser?.name ??
                                    auth.currentUser?.email ??
                                    '',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.slate700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  auth.currentUser!.type.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),

                      // Logout Button
                      IconButton(
                        tooltip: 'Logout',
                        icon: Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: AppTheme.danger,
                        ),
                        onPressed: () async {
                          await auth.logout();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: screens[index],
    );
  }
}
