import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/theme.dart';
import '../../providers/app_blocker_provider.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> with WidgetsBindingObserver {
  bool _notificationGranted = false;
  bool _storageGranted = true; // Auto-granted on modern Android typically, but we track it.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
      ref.read(permissionsProvider.notifier).refresh();
    }
  }

  Future<void> _checkPermissions() async {
    final notif = await Permission.notification.isGranted;
    setState(() {
      _notificationGranted = notif;
    });
  }

  Future<void> _requestNotification() async {
    final status = await Permission.notification.request();
    setState(() => _notificationGranted = status.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    final blockerPerms = ref.watch(permissionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.go('/onboarding/user-type'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A few permissions to\nunlock all features.',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3),
            ),
            const SizedBox(height: 8),
            const Text(
              'We need these to ensure the app functions correctly. You can change these anytime in Settings.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            const SizedBox(height: 28),
            
            Expanded(
              child: ListView(
                children: [
                  _PermissionTile(
                    title: 'Notifications',
                    description: 'Get reminded about tasks and focus session completions.',
                    icon: Icons.notifications_outlined,
                    isGranted: _notificationGranted,
                    onRequest: _requestNotification,
                  ),
                  _PermissionTile(
                    title: 'Storage Access',
                    description: 'Save and share your exported reports.',
                    icon: Icons.folder_outlined,
                    isGranted: _storageGranted, // Auto-granted mock
                    onRequest: () {},
                  ),
                  _PermissionTile(
                    title: 'Usage Access',
                    description: 'Required to detect when distracting apps are opened.',
                    icon: Icons.query_stats_rounded,
                    isGranted: blockerPerms.hasUsageStats,
                    onRequest: () => ref.read(permissionsProvider.notifier).requestUsageStats(),
                  ),
                  _PermissionTile(
                    title: 'Overlay Permission',
                    description: 'Allows the focus screen to appear over blocked apps.',
                    icon: Icons.layers_rounded,
                    isGranted: blockerPerms.hasOverlay,
                    onRequest: () => ref.read(permissionsProvider.notifier).requestOverlay(),
                  ),
                ],
              ),
            ),
            
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => context.go('/onboarding/tutorial'),
                child: const Text('Continue'),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => context.go('/onboarding/tutorial'),
                child: const Text(
                  'Skip for now',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isGranted;
  final VoidCallback onRequest;

  const _PermissionTile({
    required this.title,
    required this.description,
    required this.icon,
    required this.isGranted,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isGranted ? AppColors.success.withOpacity(0.5) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: (isGranted ? AppColors.success : AppColors.primary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isGranted ? Icons.check_circle_rounded : icon, 
                color: isGranted ? AppColors.success : AppColors.primary, 
                size: 24
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF6B7280), height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            isGranted
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Granted',
                        style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  )
                : TextButton(
                    onPressed: onRequest,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Allow', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
          ],
        ),
      ),
    );
  }
}
