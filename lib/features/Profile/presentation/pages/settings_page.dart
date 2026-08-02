import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/widgets/sub_page_app_bar.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../Auth/presentation/providers/auth_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${strings.logOut}?'),
        content: const Text('You will need to sign in again to report, vote or '
            'comment.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              strings.logOut,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(authProvider.notifier).signOut();
    if (context.mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final strings = ref.watch(appStringsProvider);
    final isAuthenticated = ref.watch(authProvider).user != null;
    final theme = Theme.of(context);
    final radiusKm = settings.reportRadius.toInt();

    return Scaffold(
      appBar: SubPageAppBar(
        title: strings.settings,
        showOverflowMenu: false,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSectionHeader(strings.accountAndSecurity, theme),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(strings.editProfile),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/edit-profile'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(strings.changePassword),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/change-password'),
          ),
          if (isAuthenticated)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                strings.logOut,
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () => _confirmSignOut(context, ref, strings),
            )
          else
            ListTile(
              leading: const Icon(Icons.login, color: Colors.blue),
              title: Text(
                strings.logIn,
                style: const TextStyle(color: Colors.blue),
              ),
              onTap: () => context.push('/sign-in'),
            ),
          const Divider(),
          _buildSectionHeader(strings.appPreferences, theme),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: Text(strings.theme),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text(strings.themeSystem),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text(strings.themeLight),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text(strings.themeDark),
                ),
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
            title: Text(strings.language),
            trailing: DropdownButton<String>(
              value: settings.languageCode,
              underline: const SizedBox(),
              items: AppStrings.supportedCodes
                  .map(
                    (code) => DropdownMenuItem(
                      value: code,
                      child: Text(AppStrings.languageName(code)),
                    ),
                  )
                  .toList(),
              onChanged: (code) {
                if (code != null) {
                  ref.read(settingsProvider.notifier).updateLanguage(code);
                }
              },
            ),
          ),
          const Divider(),
          _buildSectionHeader(strings.mapAndLocation, theme),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: Text(strings.reportRadius),
            subtitle: Text('$radiusKm km'),
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
          _buildSectionHeader(strings.notifications, theme),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: Text(strings.nearbyAlerts),
            subtitle: Text(strings.nearbyAlertsSubtitle(radiusKm)),
            value: settings.nearbyAlertsEnabled,
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).updateNearbyAlerts(value),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_none),
            title: Text(strings.viewNotifications),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/notifications'),
          ),
          const Divider(),
          _buildSectionHeader(strings.aboutAndSupport, theme),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(strings.helpCenter),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/help'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(strings.privacyPolicy),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(strings.appVersion),
            trailing: const Text('v1.0.0'),
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
