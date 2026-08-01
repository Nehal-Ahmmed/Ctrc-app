import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/sub_page_app_bar.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../Auth/presentation/providers/auth_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const SubPageAppBar(title: 'Settings'),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSectionHeader('Account & Security', theme),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to Edit Profile
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to Change Password
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log Out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/sign-in');
              }
            },
          ),
          const Divider(),
          _buildSectionHeader('App Preferences', theme),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Theme'),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (mode) {
                if (mode != null) {
                  ref.read(settingsProvider.notifier).updateThemeMode(mode);
                }
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            trailing: DropdownButton<String>(
              value: settings.languageCode,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'bn', child: Text('Bangla')),
              ],
              onChanged: (code) {
                if (code != null) {
                  ref.read(settingsProvider.notifier).updateLanguage(code);
                }
              },
            ),
          ),
          const Divider(),
          _buildSectionHeader('Map & Location', theme),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('Report Radius'),
            subtitle: Text('${settings.reportRadius.toInt()} km'),
            trailing: DropdownButton<double>(
              value: settings.reportRadius,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 5.0, child: Text('5 km')),
                DropdownMenuItem(value: 10.0, child: Text('10 km')),
                DropdownMenuItem(value: 20.0, child: Text('20 km')),
              ],
              onChanged: (radius) {
                if (radius != null) {
                  ref.read(settingsProvider.notifier).updateReportRadius(radius);
                }
              },
            ),
          ),
          const Divider(),
          _buildSectionHeader('Notifications', theme),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Nearby Incident Alerts'),
            subtitle: const Text('Get notified about traffic and accidents near you'),
            value: false, // Disabled for now (no FCM)
            onChanged: (value) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Push notifications will be available soon.')),
              );
            },
          ),
          const Divider(),
          _buildSectionHeader('About & Support', theme),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help Center / FAQ'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () {},
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('App Version'),
            trailing: Text('v1.0.0'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
