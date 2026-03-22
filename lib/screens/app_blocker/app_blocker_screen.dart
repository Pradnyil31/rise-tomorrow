import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/app_blocker_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/app_blocking_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/user_profile.dart';

class AppBlockerScreen extends ConsumerStatefulWidget {
  const AppBlockerScreen({super.key});

  @override
  ConsumerState<AppBlockerScreen> createState() => _AppBlockerScreenState();
}

class _AppBlockerScreenState extends ConsumerState<AppBlockerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tab;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh permissions when user returns from system Settings
    if (state == AppLifecycleState.resumed) {
      ref.read(permissionsProvider.notifier).refresh();
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _toggleBlocking() async {
    final notifier = ref.read(blockingProvider.notifier);
    final blocking = ref.read(blockingProvider);
    if (blocking.isActive) {
      await notifier.stopBlocking();
    } else {
      await notifier.startBlocking();
      _persistBlockedApps();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🛡️ Focus mode enabled. Apps blocked!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _persistBlockedApps() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final selected = ref.read(blockingProvider).selectedPackages;
    final apps = selected
        .map((pkg) => {'appPackage': pkg, 'userId': user.uid})
        .toList();
    try {
      await FirebaseService().saveBlockedApps(user.uid, apps);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider);
    final blocking = ref.watch(blockingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Blocker'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Block Apps'),
            Tab(text: 'Scheduled'),
            Tab(text: 'Quick Block'),
          ],
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Color(0xFF6B7280),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _BlockAppsTab(
            perms: perms,
            blocking: blocking,
            searchQuery: _searchQuery,
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            onTogglePackage: (pkg) =>
                ref.read(blockingProvider.notifier).togglePackage(pkg),
            onToggleBlocking: _toggleBlocking,
          ),
          _ScheduledTab(),
          _QuickBlockTab(
            onQuickBlock: (minutes) async {
              final notifier = ref.read(blockingProvider.notifier);
              await notifier.startBlocking();
              _persistBlockedApps();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('🛡️ Blocking for $minutes minutes!'),
                  backgroundColor: AppColors.success,
                ));
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─── Block Apps Tab ───────────────────────────────────────────────────────────

class _BlockAppsTab extends StatelessWidget {
  final PermissionsState perms;
  final BlockingState blocking;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onTogglePackage;
  final VoidCallback onToggleBlocking;

  const _BlockAppsTab({
    required this.perms,
    required this.blocking,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onTogglePackage,
    required this.onToggleBlocking,
  });

  @override
  Widget build(BuildContext context) {
    if (!perms.allGranted) {
      return _PermissionGate(perms: perms);
    }

    final filtered = blocking.installedApps.where((a) {
      if (searchQuery.isEmpty) return true;
      return a['name']!.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search apps...',
              prefixIcon: const Icon(Icons.search_rounded),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.outlineColor),
              ),
            ),
            onChanged: onSearchChanged,
          ),
        ),
        // Active blocking banner
        if (blocking.isActive)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withOpacity(0.4)),
            ),
            child: Row(
              children: const [
                Icon(Icons.shield_rounded, color: AppColors.success, size: 18),
                SizedBox(width: 8),
                Text('Focus mode is ACTIVE',
                    style: TextStyle(
                        color: AppColors.success, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        Expanded(
          child: blocking.isLoading
              ? const Center(child: CircularProgressIndicator())
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final app = filtered[i];
                    final pkg = app['package']!;
                    final isSelected =
                        blocking.selectedPackages.contains(pkg);

                    return GestureDetector(
                      onTap: () => onTogglePackage(pkg),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.12)
                              : Theme.of(ctx).cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Theme.of(ctx).dividerColor.withOpacity(0.2),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.1),
                              child: app['icon'] != null
                                  ? ClipOval(
                                      child: Image.memory(
                                        app['icon'] as Uint8List,
                                        width: 28,
                                        height: 28,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : FutureBuilder<Uint8List?>(
                                      future: AppBlockingService().getAppIcon(pkg),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          );
                                        }
                                        if (snapshot.hasData && snapshot.data != null) {
                                          return ClipOval(
                                            child: Image.memory(
                                              snapshot.data!,
                                              width: 28,
                                              height: 28,
                                              fit: BoxFit.cover,
                                            ),
                                          );
                                        }
                                        return Icon(Icons.android_rounded,
                                            color: isSelected
                                                ? AppColors.primary
                                                : const Color(0xFF9CA3AF));
                                      },
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              app['name']!,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isSelected ? AppColors.primary : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Bottom action bar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              top: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.2)),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${blocking.selectedPackages.length} apps selected',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
                const Spacer(),
                // Stop is ALWAYS available when blocking is active
                if (blocking.isActive)
                  ElevatedButton.icon(
                    onPressed: onToggleBlocking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: const Text('Stop Blocking'),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: blocking.selectedPackages.isEmpty
                        ? null
                        : onToggleBlocking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.shield_rounded, size: 18),
                    label: const Text('Start Block'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Permission Gate ──────────────────────────────────────────────────────────

class _PermissionGate extends ConsumerWidget {
  final PermissionsState perms;
  const _PermissionGate({required this.perms});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                size: 44, color: AppColors.warning),
          ),
          const SizedBox(height: 24),
          const Text('Permissions Required',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'App Blocker needs two special permissions to monitor and block apps.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280), height: 1.5),
          ),
          const SizedBox(height: 32),
          _PermissionRow(
            icon: Icons.query_stats_rounded,
            title: 'Usage Access',
            subtitle: 'Detects which app is in the foreground',
            granted: perms.hasUsageStats,
            onGrant: () =>
                ref.read(permissionsProvider.notifier).requestUsageStats(),
          ),
          const SizedBox(height: 16),
          _PermissionRow(
            icon: Icons.layers_rounded,
            title: 'Overlay Permission',
            subtitle: 'Shows the block screen over other apps',
            granted: perms.hasOverlay,
            onGrant: () =>
                ref.read(permissionsProvider.notifier).requestOverlay(),
          ),
          const SizedBox(height: 32),
          const Text(
            'After granting both permissions in Settings,\nreturn to this screen.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback onGrant;

  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: granted
            ? AppColors.success.withOpacity(0.08)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: granted
              ? AppColors.success.withOpacity(0.4)
              : Theme.of(context).dividerColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: (granted ? AppColors.success : AppColors.primary)
                .withOpacity(0.12),
            child: Icon(granted ? Icons.check_rounded : icon,
                color: granted ? AppColors.success : AppColors.primary,
                size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
          ),
          if (!granted)
            TextButton(
              onPressed: onGrant,
              child: const Text('Grant'),
            )
          else
            const Icon(Icons.verified_rounded,
                color: AppColors.success, size: 20),
        ],
      ),
    );
  }
}

// ─── Scheduled Tab ────────────────────────────────────────────────────────────

class _ScheduledTab extends ConsumerWidget {
  const _ScheduledTab();

  void _showEditDialog(BuildContext context, WidgetRef ref, [BlockSchedule? schedule]) {
    showDialog(
      context: context,
      builder: (ctx) => _EditScheduleDialog(
        initialSchedule: schedule,
        onSave: (newSchedule) {
          final notifier = ref.read(settingsProvider.notifier);
          if (schedule == null) {
            notifier.addSchedule(newSchedule);
          } else {
            notifier.updateSchedule(newSchedule);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final schedules = settings.schedules;
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          const _SelectedAppsAction(),
          Expanded(
            child: schedules.isEmpty
                ? const Center(
                    child: Text('No schedules yet.\nTap below to add one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF6B7280))),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: schedules.length,
                    itemBuilder: (ctx, i) {
                      final s = schedules[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${s.startTime} - ${s.endTime}',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                  Switch(
                                    value: s.isEnabled,
                                    onChanged: (_) => notifier.toggleSchedule(s.id),
                                    activeColor: AppColors.primary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Wrap(
                                      spacing: 4,
                                      children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((e) {
                                        final dayNum = e.key + 1;
                                        final isSelected = s.days.contains(dayNum);
                                        return Container(
                                          width: 24,
                                          height: 24,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isSelected ? AppColors.primary : Theme.of(context).cardColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: isSelected ? AppColors.primary : Theme.of(context).dividerColor.withOpacity(0.2)),
                                          ),
                                          child: Text(
                                            e.value,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isSelected ? Colors.white : const Color(0xFF6B7280),
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
                                    onPressed: () => _showEditDialog(context, ref, s),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_rounded, color: AppColors.error, size: 20),
                                    onPressed: () => notifier.removeSchedule(s.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(context, ref),
        label: const Text('Add Schedule'),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _EditScheduleDialog extends StatefulWidget {
  final BlockSchedule? initialSchedule;
  final ValueChanged<BlockSchedule> onSave;

  const _EditScheduleDialog({this.initialSchedule, required this.onSave});

  @override
  State<_EditScheduleDialog> createState() => _EditScheduleDialogState();
}

class _EditScheduleDialogState extends State<_EditScheduleDialog> {
  late String _start;
  late String _end;
  late List<int> _days;

  @override
  void initState() {
    super.initState();
    _start = widget.initialSchedule?.startTime ?? '09:00';
    _end = widget.initialSchedule?.endTime ?? '17:00';
    _days = List.from(widget.initialSchedule?.days ?? [1, 2, 3, 4, 5]);
  }

  Future<void> _pickTime(bool isStart) async {
    final current = isStart ? _start : _end;
    final parts = current.split(':');
    final initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    final picked = await showTimePicker(context: context, initialTime: initialTime);
    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isStart) _start = formatted;
        else _end = formatted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialSchedule == null ? 'New Schedule' : 'Edit Schedule'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickTime(true),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Start Time', border: OutlineInputBorder()),
                    child: Text(_start, style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _pickTime(false),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'End Time', border: OutlineInputBorder()),
                    child: Text(_end, style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Active Days', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((e) {
              final dayNum = e.key + 1;
              final isSelected = _days.contains(dayNum);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) _days.remove(dayNum);
                    else _days.add(dayNum);
                  });
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: isSelected ? AppColors.primary : Theme.of(context).cardColor,
                  child: Text(
                    e.value,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF6B7280),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_days.isEmpty) return; // Prevent saving with no days
            widget.onSave(BlockSchedule(
              id: widget.initialSchedule?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
              startTime: _start,
              endTime: _end,
              days: _days,
              isEnabled: widget.initialSchedule?.isEnabled ?? true,
            ));
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ─── Quick Block Tab ──────────────────────────────────────────────────────────

class _QuickBlockTab extends StatelessWidget {
  final void Function(int minutes) onQuickBlock;
  const _QuickBlockTab({required this.onQuickBlock});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _SelectedAppsAction(),
          const Spacer(),
          const Icon(Icons.bolt_rounded, size: 64, color: AppColors.primary),
          const SizedBox(height: 16),
          const Text('Quick Block',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Start blocking selected apps for a preset duration.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 32),
          for (final mins in [15, 30, 60, 120])
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => onQuickBlock(mins),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    '⚡ Block for $mins minutes',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Shared UI for Selected Apps ───────────────────────────────────────────────

class _SelectedAppsAction extends ConsumerWidget {
  const _SelectedAppsAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocking = ref.watch(blockingProvider);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.15),
            child: const Icon(Icons.apps_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Target Apps', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text('${blocking.selectedPackages.length} apps selected for blocking',
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => const _AppSelectorBottomSheet(),
              );
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}

class _AppSelectorBottomSheet extends ConsumerStatefulWidget {
  const _AppSelectorBottomSheet();
  @override
  ConsumerState<_AppSelectorBottomSheet> createState() => _AppSelectorBottomSheetState();
}

class _AppSelectorBottomSheetState extends ConsumerState<_AppSelectorBottomSheet> {
  String _searchQuery = '';
  @override
  Widget build(BuildContext context) {
    final blocking = ref.watch(blockingProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final filtered = blocking.installedApps.where((a) {
      if (_searchQuery.isEmpty) return true;
      return a['name']!.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Apps to Block', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                 final app = filtered[i];
                 final pkg = app['package']!;
                 final isSelected = blocking.selectedPackages.contains(pkg);
                 return ListTile(
                   leading: app['icon'] != null 
                     ? ClipOval(child: Image.memory(app['icon'] as Uint8List, width: 32, height: 32, fit: BoxFit.cover)) 
                     : FutureBuilder<Uint8List?>(
                         future: AppBlockingService().getAppIcon(pkg),
                         builder: (context, snapshot) {
                           if (snapshot.hasData && snapshot.data != null) {
                             return ClipOval(child: Image.memory(snapshot.data!, width: 32, height: 32, fit: BoxFit.cover));
                           }
                           return const Icon(Icons.android, size: 32);
                         },
                       ),
                   title: Text(app['name']!),
                   trailing: Checkbox(
                     value: isSelected,
                     activeColor: AppColors.primary,
                     onChanged: (_) => ref.read(blockingProvider.notifier).togglePackage(pkg),
                   ),
                   onTap: () => ref.read(blockingProvider.notifier).togglePackage(pkg),
                 );
              },
            ),
          ),
        ],
      ),
    );
  }
}
