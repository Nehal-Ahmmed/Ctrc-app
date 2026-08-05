import '../../../../core/utils/app_time.dart';
import 'package:flutter/material.dart';

import '../../../Map/domain/services/incident_severity.dart';
import '../../../Map/domain/utils/geo_utils.dart';
import '../../domain/models/report_category.dart';
import '../../domain/models/report_model.dart';
import '../../domain/services/incident_match.dart';

class IncidentLinkChoice {
  
  final ReportModel? parent;

  const IncidentLinkChoice.linkTo(ReportModel this.parent);

  const IncidentLinkChoice.newIncident() : parent = null;

  bool get isLink => parent != null;
}

class LinkIncidentSheet extends StatelessWidget {
  final List<IncidentCandidate> candidates;
  final String radiusLabel;

  const LinkIncidentSheet({
    super.key,
    required this.candidates,
    required this.radiusLabel,
  });

  static Future<IncidentLinkChoice?> show(
    BuildContext context, {
    required List<IncidentCandidate> candidates,
    required String radiusLabel,
  }) {
    return showModalBottomSheet<IncidentLinkChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LinkIncidentSheet(
        candidates: candidates,
        radiusLabel: radiusLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Is this the same incident?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  '${candidates.length} incident'
                  '${candidates.length == 1 ? ' is' : 's are'} already reported '
                  '$radiusLabel in the last ${kLinkMaxAge.inDays} days, '
                  'closest first. Linking keeps everything about the same '
                  'event in one place.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: candidates.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 68),
              itemBuilder: (context, index) => _buildCandidate(
                context,
                candidates[index],
              ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        const IncidentLinkChoice.newIncident(),
                      ),
                      icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                      label: const Text('Report as new incident'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidate(BuildContext context, IncidentCandidate candidate) {
    final report = candidate.report;
    final level = IncidentSeverity.of(report);
    final category = ReportCategory.fromLabel(report.category);
    final createdAt = AppTime.parseTimestamp(report.createdAt);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: level.color.withValues(alpha: 0.15),
        child: Icon(category.icon, color: level.color, size: 20),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              report.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          
          if (candidate.titleScore >= IncidentMatch.strongTitleScore) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'similar wording',
                style: TextStyle(fontSize: 10, color: Color(0xFF1A73E8)),
              ),
            ),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          [
            category.label,
            '${GeoUtils.formatDistance(candidate.distanceMeters)} away',
            if (createdAt != null) AppTime.formatRelativeTime(createdAt),
          ].join(' · '),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ),
      trailing: TextButton(
        onPressed: () => Navigator.pop(
          context,
          IncidentLinkChoice.linkTo(report),
        ),
        child: const Text('Link'),
      ),
      onTap: () => Navigator.pop(
        context,
        IncidentLinkChoice.linkTo(report),
      ),
    );
  }
}
