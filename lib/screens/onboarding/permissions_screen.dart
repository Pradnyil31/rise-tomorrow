import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/theme.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  Map<String, bool> _granted = {};

  final _perms = [
    {
      'key': 'notification',
      'title': 'Notifications',
      'description': 'Get reminded about tasks and focus session completions.',
      'icon': Icons.notifications_outlined,
    },
    {
      'key': 'storage',
      'title': 'Storage Access',
      'description': 'Save and share your exported reports.',
      'icon': Icons.folder_outlined,
    },
  ];

  Future<void> _request(String key) async {
    bool result = false;
    if (key == 'notification') {
      final status = await Permission.notification.request();
      result = status.isGranted;
    } else if (key == 'storage') {
      // Storage permission is auto-granted on modern Android
      result = true;
    }
    setState(() => _granted[key] = result);
  }

  @override
  Widget build(BuildContext context) {
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
              'You can change these anytime in Settings.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            const SizedBox(height: 28),
            ...(_perms.map((p) => _PermissionTile(
                  title: p['title'] as String,
                  description: p['description'] as String,
                  icon: p['icon'] as IconData,
                  isGranted: _granted[p['key']] ?? false,
                  onRequest: () => _request(p['key'] as String),
                ))),
            const Spacer(),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF6B7280))),
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
                    child: const Text('Allow'),
                  ),
          ],
        ),
      ),
    );
  }
}
