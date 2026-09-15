import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/clinic_provider.dart';
import '../../widgets/active_queue_view.dart';

/// Full-screen view of the Active Queue only.
///
/// Rendered as a fullscreen dialog so it can be projected on a secondary
/// display while the rest of the receptionist workspace stays available.
/// Reuses [ActiveQueueView] so it shares the exact same live-updating
/// logic as the inline queue tab.
class ActiveQueueScreen extends StatefulWidget {
  const ActiveQueueScreen({super.key});

  @override
  State<ActiveQueueScreen> createState() => _ActiveQueueScreenState();
}

class _ActiveQueueScreenState extends State<ActiveQueueScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    // final visits = provider.visits;
    final todayVisitsCount = provider.todayVisits.length;

    final bool live = provider.realtimeConnected;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.cardBg,
        foregroundColor: AppTheme.secondary,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.primary),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.queue_music_outlined,
                color: AppTheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Active Queue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.secondary,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$todayVisitsCount Visit${todayVisitsCount == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: live ? AppTheme.successLight : AppTheme.dangerLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 4,
                  backgroundColor: live ? AppTheme.success : AppTheme.danger,
                ),
                const SizedBox(width: 6),
                Text(
                  live ? 'Live' : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: live ? AppTheme.success : AppTheme.danger,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search queue by name or phone...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: AppTheme.slate400,
                        ),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Close Full-Screen Queue',
                  icon: const Icon(Icons.close_rounded),
                  color: AppTheme.slate700,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: ActiveQueueView(searchQuery: _searchController.text)),
        ],
      ),
    );
  }
}
