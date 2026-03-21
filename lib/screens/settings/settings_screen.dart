import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(userProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Profile header
          if (user != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(user.email, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),

          // Preferences
          const _SectionHeader(title: 'PREFERENCES'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: settings.darkMode,
            activeColor: AppColors.primary,
            onChanged: (_) => ref.read(settingsProvider.notifier).toggleDarkMode(),
          ),
          SwitchListTile(
            title: const Text('App Notifications'),
            secondary: const Icon(Icons.notifications_outlined),
            value: settings.notifications,
            activeColor: AppColors.primary,
            onChanged: (_) => ref.read(settingsProvider.notifier).toggleNotifications(),
          ),
          SwitchListTile(
            title: const Text('Biometric Authentication'),
            subtitle: const Text('Require Face ID / Touch ID to open'),
            secondary: const Icon(Icons.fingerprint_rounded),
            value: settings.biometricAuth,
            activeColor: AppColors.primary,
            onChanged: (_) => ref.read(settingsProvider.notifier).toggleBiometric(),
          ),
          ListTile(
            title: const Text('Default Focus Duration'),
            subtitle: Text('${settings.defaultFocusDuration} minutes'),
            leading: const Icon(Icons.timer_outlined),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              // Show picker dialog
            },
          ),
          const Divider(),

          // Support
          const _SectionHeader(title: 'SUPPORT'),
          ListTile(
            title: const Text('Help Center'),
            leading: const Icon(Icons.help_outline_rounded),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Submit Feedback'),
            leading: const Icon(Icons.feedback_outlined),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            leading: const Icon(Icons.shield_outlined),
            onTap: () {},
          ),
          const Divider(),

          // Account Actions
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                onPressed: () async {
                  await ref.read(userProfileProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                },
                child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9CA3AF),
          letterSpacing: 1,
        ),
      ),
    );
  }
}
