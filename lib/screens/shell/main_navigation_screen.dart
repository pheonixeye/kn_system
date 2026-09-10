import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/clinic_provider.dart';
import '../consultant/consultant_screen.dart';
import '../receptionist/receptionist_screen.dart';
import '../resident/resident_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ReceptionistScreen(),
    ResidentScreen(),
    ConsultantScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final visits = provider.visits;

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

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              bottom: BorderSide(color: AppTheme.slate200, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
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
                      gradient: const LinearGradient(
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
                  const Column(
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
                  const SizedBox(width: 32),

                  // Navigation Tabs
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildNavTab(
                        index: 0,
                        title: 'Receptionist',
                        icon: Icons.person_add_alt_1_outlined,
                        activeIcon: Icons.person_add_alt_1_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildNavTab(
                        index: 1,
                        title: 'Resident Doctor',
                        icon: Icons.medical_services_outlined,
                        activeIcon: Icons.medical_services_rounded,
                        badgeCount: residentCount,
                        badgeColor: AppTheme.warning,
                      ),
                      const SizedBox(width: 8),
                      _buildNavTab(
                        index: 2,
                        title: 'Consultant Dashboard',
                        icon: Icons.dashboard_outlined,
                        activeIcon: Icons.dashboard_rounded,
                        badgeCount: consultantCount,
                        badgeColor: AppTheme.accent,
                      ),
                    ],
                  ),

                  const SizedBox(width: 32),

                  // Right Status & Actions
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.successLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 4,
                          backgroundColor: AppTheme.success,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'PocketBase Connected',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Sync / Refresh All',
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppTheme.slate700,
                      size: 20,
                    ),
                    onPressed: () => provider.loadData(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
    );
  }

  Widget _buildNavTab({
    required int index,
    required String title,
    required IconData icon,
    required IconData activeIcon,
    int? badgeCount,
    Color? badgeColor,
  }) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 18,
              color: isSelected ? AppTheme.primary : AppTheme.slate500,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : AppTheme.slate700,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor ?? AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
