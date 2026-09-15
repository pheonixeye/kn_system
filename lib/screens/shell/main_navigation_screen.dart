import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clinic_provider.dart';
import '../../providers/theme_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final visits = provider.visits;

    final userType = auth.currentUser?.type ?? UserType.receptionist;

    final screens = <Widget>[
      ReceptionistScreen(),
      if (userType.canAccessResidentScreen) ResidentScreen(),
      if (userType.canAccessConsultantScreen) ConsultantScreen(),
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

    final tabs = <
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
                  const SizedBox(width: 32),

                  // Navigation Tabs
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < tabs.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _buildNavTab(
                          index: i,
                          title: tabs[i].title,
                          icon: tabs[i].icon,
                          activeIcon: tabs[i].activeIcon,
                          badgeCount: tabs[i].badgeCount,
                          badgeColor: tabs[i].badgeColor,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(width: 32),

                  // Signed-in user
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.indigoLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: AppTheme.indigo,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${auth.currentUser?.name?.isNotEmpty == true ? auth.currentUser!.name : auth.currentUser?.email ?? ''} · ${userType.label}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.indigo,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Right Status & Actions
                  _buildConnectionPill(provider),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: themeProvider.isDark
                        ? 'Switch to Light Mode'
                        : 'Switch to Dark Mode',
                    icon: Icon(
                      themeProvider.isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: AppTheme.slate700,
                      size: 20,
                    ),
                    onPressed: () => themeProvider.toggleTheme(),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Sync / Refresh All',
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: AppTheme.slate700,
                      size: 20,
                    ),
                    onPressed: () => provider.loadData(),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Sign Out',
                    icon: Icon(
                      Icons.logout_rounded,
                      color: AppTheme.slate700,
                      size: 20,
                    ),
                    onPressed: () => context.read<AuthProvider>().logout(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(index: index, children: screens),
    );
  }

  Widget _buildConnectionPill(ClinicProvider provider) {
    final bool loading = provider.isLoading;
    final bool live = provider.realtimeConnected;

    final Color bg;
    final Color fg;
    final String label;
    if (loading) {
      bg = AppTheme.warningLight;
      fg = AppTheme.warning;
      label = 'Loading PocketBase…';
    } else if (live) {
      bg = AppTheme.successLight;
      fg = AppTheme.success;
      label = 'Live Sync On';
    } else {
      bg = AppTheme.dangerLight;
      fg = AppTheme.danger;
      label = 'Live Sync Off';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(fg),
              ),
            )
          else
            CircleAvatar(radius: 4, backgroundColor: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
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
