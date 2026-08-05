import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/widgets/sub_page_app_bar.dart';
import '../../../Map/domain/utils/geo_utils.dart';
import '../../../../core/utils/app_time.dart';
import '../../domain/models/app_notification.dart';
import '../providers/notification_provider.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);
    final controller = ref.read(notificationsProvider.notifier);
    final alertsEnabled = ref.watch(settingsProvider).nearbyAlertsEnabled;
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: SubPageAppBar(
        title: strings.notifications,
        menuItems: [
          SubPageMenuItem(
            label: strings.markAllRead,
            icon: Icons.done_all,
            onSelected: controller.markAllRead,
          ),
          SubPageMenuItem(
            label: strings.clearAll,
            icon: Icons.delete_outline,
            isDestructive: true,
            onSelected: () => _confirmClear(context, controller),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!alertsEnabled) _buildDisabledBanner(context, ref),
          Expanded(
            child: state.items.isEmpty
                ? _buildEmpty(alertsEnabled, strings)
                : ListView.separated(
                    itemCount: state.items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) => _buildTile(
                      context,
                      ref,
                      state.items[index],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    NotificationController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear notifications?'),
        content: const Text(
          'This removes every alert from the list. Incidents themselves are '
          'not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.clearAll();
  }

  Widget _buildDisabledBanner(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      color: Colors.orange.withValues(alpha: 0.12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          const Icon(Icons.notifications_off_outlined,
              size: 20, color: Color(0xFFE8710A)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Nearby incident alerts are turned off.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => ref
                .read(settingsProvider.notifier)
                .updateNearbyAlerts(true),
            child: const Text('Turn on'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool alertsEnabled, AppStrings strings) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              alertsEnabled
                  ? strings.noNotificationsYet
                  : 'Alerts are off, so nothing is being collected.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) {
    final category = notification.categoryInfo;

    return Dismissible(
      key: ValueKey(notification.reportId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: Colors.red,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => ref
          .read(notificationsProvider.notifier)
          .remove(notification.reportId),
      child: Container(
        color: notification.isRead
            ? Colors.white
            : const Color(0xFF1A73E8).withValues(alpha: 0.05),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: category.color.withValues(alpha: 0.15),
            child: Icon(category.icon, color: category.color),
          ),
          title: Text(
            notification.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight:
                  notification.isRead ? FontWeight.w500 : FontWeight.bold,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              [
                category.label,
                if (notification.distanceMeters != null)
                  '${GeoUtils.formatDistance(notification.distanceMeters!)} away',
                AppTime.formatRelativeTime(notification.receivedAt),
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          trailing: notification.isRead
              ? null
              : Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A73E8),
                    shape: BoxShape.circle,
                  ),
                ),
          onTap: () {
            ref
                .read(notificationsProvider.notifier)
                .markRead(notification.reportId);
            context.push('/report/${notification.reportId}');
          },
        ),
      ),
    );
  }
}
