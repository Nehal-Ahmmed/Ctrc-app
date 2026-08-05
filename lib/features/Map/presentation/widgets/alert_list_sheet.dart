import 'package:flutter/material.dart';

import '../../../Report/domain/models/report_model.dart';
import '../../domain/models/route_models.dart';

class AlertEntry {
  final ReportModel report;
  final CongestionLevel level;

  final String distanceLabel;

  const AlertEntry({
    required this.report,
    required this.level,
    required this.distanceLabel,
  });
}

class AlertListSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<AlertEntry> entries;
  final ValueChanged<ReportModel> onOpenReport;
  final String emptyMessage;

  const AlertListSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.entries,
    required this.onOpenReport,
    this.emptyMessage = 'No incidents reported here right now.',
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<AlertEntry> entries,
    required ValueChanged<ReportModel> onOpenReport,
    String emptyMessage = 'No incidents reported here right now.',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AlertListSheet(
        title: title,
        subtitle: subtitle,
        entries: entries,
        onOpenReport: onOpenReport,
        emptyMessage: emptyMessage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[350],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${entries.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A73E8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            emptyMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) =>
                            _AlertTile(entry: entries[index], onOpen: onOpenReport),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AlertTile extends StatelessWidget {
  final AlertEntry entry;
  final ValueChanged<ReportModel> onOpen;

  const _AlertTile({required this.entry, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final report = entry.report;
    final color = entry.level.color;

    return ListTile(
      onTap: () => onOpen(report),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(entry.level.icon, color: color),
      ),
      title: Text(
        report.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            '${report.category} · ${entry.distanceLabel}',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          if (report.description != null && report.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                report.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
