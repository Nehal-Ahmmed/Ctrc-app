import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ctrc/features/Report/domain/models/report_model.dart';
import 'package:ctrc/features/Report/presentation/widgets/voters_bottom_sheet.dart';

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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Upvote Button
                    Container(
                      decoration: BoxDecoration(
                        color: report.userVoteType == 'up' ? Colors.blue[50] : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: report.userVoteType == 'up' ? Colors.blue : Colors.grey[300]!,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            icon: Icon(
                              Icons.arrow_upward,
                              size: 18,
                              color: report.userVoteType == 'up' ? Colors.blue : Colors.grey[600],
                            ),
                            onPressed: onUpvote,
                          ),
                          InkWell(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => VotersBottomSheet(reportId: report.reportId),
                              );
                            },
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(24),
                              bottomRight: Radius.circular(24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12, top: 6, bottom: 6),
                              child: Text(
                                '${report.upvoteCount}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: report.userVoteType == 'up' ? Colors.blue : Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Downvote Button
                    Container(
                      decoration: BoxDecoration(
                        color: report.userVoteType == 'down' ? Colors.red[50] : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: report.userVoteType == 'down' ? Colors.red : Colors.grey[300]!,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            icon: Icon(
                              Icons.arrow_downward,
                              size: 18,
                              color: report.userVoteType == 'down' ? Colors.red : Colors.grey[600],
                            ),
                            onPressed: onDownvote,
                          ),
                          InkWell(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => VotersBottomSheet(reportId: report.reportId),
                              );
                            },
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(24),
                              bottomRight: Radius.circular(24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12, top: 6, bottom: 6),
                              child: Text(
                                '${report.downvoteCount}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: report.userVoteType == 'down' ? Colors.red : Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Comment Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: onComment,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${report.commentCount}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
