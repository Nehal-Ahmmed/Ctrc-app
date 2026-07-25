import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ctrc/features/Report/domain/models/report_model.dart';

class ReportCardWidget extends StatelessWidget {
  final ReportModel report;
  final LatLng? currentLocation;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;
  final VoidCallback onComment;
  final VoidCallback? onSave;

  const ReportCardWidget({
    super.key,
    required this.report,
    this.currentLocation,
    required this.onUpvote,
    required this.onDownvote,
    required this.onComment,
    this.onSave,
  });

  String _formatDistance() {
    if (currentLocation == null || report.location == null) return '';
    final distance = const Distance().as(
      LengthUnit.Meter,
      currentLocation!,
      LatLng(report.location!.latitude, report.location!.longitude),
    );
    if (distance < 1000) {
      return '${distance.toInt()}m away';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km away';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.red[100],
                  child: const Icon(Icons.warning, color: Colors.red),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Category: ${report.category}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onSave != null)
                  IconButton(
                    icon: Icon(
                      report.isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: report.isSaved ? Colors.blue : Colors.grey,
                    ),
                    onPressed: onSave,
                  ),
                Text(
                  _formatDistance(),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            if (report.description != null && report.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                report.description!,
                style: const TextStyle(fontSize: 15),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 20),
                      onPressed: onUpvote,
                      color: Colors.grey[600],
                    ),
                    Text('${report.upvoteCount}'),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward, size: 20),
                      onPressed: onDownvote,
                      color: Colors.grey[600],
                    ),
                    Text('${report.downvoteCount}'),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.comment_outlined, size: 20),
                      onPressed: onComment,
                      color: Colors.grey[600],
                    ),
                    Text('${report.commentCount}'),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
