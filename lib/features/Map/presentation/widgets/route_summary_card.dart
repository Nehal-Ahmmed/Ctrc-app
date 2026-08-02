import 'package:flutter/material.dart';

import '../../domain/models/route_models.dart';

/// Bottom card shown while a route is drawn: distance, time, road status and
/// a shortcut into the list of incidents beside the road.
class RouteSummaryCard extends StatelessWidget {
  final RouteAnalysis analysis;
  final VoidCallback onShowAlerts;
  final VoidCallback onClear;
  final VoidCallback onEdit;

  const RouteSummaryCard({
    super.key,
    required this.analysis,
    required this.onShowAlerts,
    required this.onClear,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final worst = analysis.worstLevel;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(worst.icon, color: worst.color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${analysis.plan.distanceLabel} · '
                    '${analysis.plan.durationLabel}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit route',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_location_alt_outlined),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: 'Clear route',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close),
                  onPressed: onClear,
                ),
              ],
            ),
            Text(
              '${analysis.fromLabel}  →  ${analysis.toLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _legendDot(CongestionLevel.clear, 'Clear'),
                _legendDot(
                  CongestionLevel.slow,
                  'Congested (${analysis.slowCount})',
                ),
                _legendDot(
                  CongestionLevel.blocked,
                  'Blocked (${analysis.blockedCount})',
                ),
              ],
            ),
            if (analysis.corridorScanTruncated)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Long trip — the corridor scan was sampled, a few incidents '
                  'may be missing.',
                  style: TextStyle(fontSize: 11.5, color: Colors.orange[800]),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onShowAlerts,
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(
                  analysis.hazards.isEmpty
                      ? 'No incidents within 2 km of this road'
                      : 'View ${analysis.hazards.length} alert'
                          '${analysis.hazards.length == 1 ? '' : 's'} '
                          'along this road',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      analysis.hazards.isEmpty ? Colors.grey[200] : worst.color,
                  foregroundColor:
                      analysis.hazards.isEmpty ? Colors.black87 : Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(CongestionLevel level, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: level.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
