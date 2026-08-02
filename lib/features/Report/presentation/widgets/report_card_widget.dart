import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:ctrc/features/Report/domain/models/comment_model.dart';
import 'package:ctrc/features/Report/domain/models/report_category.dart';
import 'package:ctrc/features/Report/domain/models/report_model.dart';
import 'package:ctrc/features/Report/presentation/widgets/voters_bottom_sheet.dart';

class ReportCardWidget extends StatelessWidget {
  final ReportModel report;
  final LatLng? currentLocation;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;
  final VoidCallback onComment;
  final VoidCallback? onSave;

  /// Tapping the card body opens the full report. Pass a callback to override
  /// the default push to `/report/:id`.
  final VoidCallback? onOpen;

  const ReportCardWidget({
    super.key,
    required this.report,
    this.currentLocation,
    required this.onUpvote,
    required this.onDownvote,
    required this.onComment,
    this.onSave,
    this.onOpen,
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

  void _open(BuildContext context) {
    if (onOpen != null) {
      onOpen!();
      return;
    }
    context.push(
      '/report/${report.reportId}',
      extra: {'report': report, 'viewerLocation': currentLocation},
    );
  }

  void _showVoters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VotersBottomSheet(reportId: report.reportId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = ReportCategory.fromLabel(report.category);
    final createdAt = CommentModel.parseTimestamp(report.createdAt);
    final distance = _formatDistance();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: category.color.withValues(alpha: 0.15),
                    child: Icon(category.icon, color: category.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          [
                            category.label,
                            if (report.evidenceType == 'heard')
                              'heard from others',
                            if (report.evidenceType == 'guessed') 'a guess',
                            if (createdAt != null)
                              formatRelativeTime(createdAt),
                            if (distance.isNotEmpty) distance,
                          ].join(' · '),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildStatusBadge(),
                      ],
                    ),
                  ),
                  if (onSave != null)
                    IconButton(
                      tooltip:
                          report.isSaved ? 'Remove from saved' : 'Save post',
                      icon: Icon(
                        report.isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: report.isSaved ? Colors.blue : Colors.grey,
                      ),
                      onPressed: onSave,
                    ),
                ],
              ),
              if (report.description != null &&
                  report.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  report.description!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15),
                ),
              ],
              if (report.subReportCount > 0) ...[
                const SizedBox(height: 12),
                _buildIncidentGroupPill(context),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildVoteButton(
                        context,
                        icon: Icons.arrow_upward,
                        count: report.upvoteCount,
                        isActive: report.userVoteType == 'up',
                        activeColor: Colors.blue,
                        onPressed: onUpvote,
                      ),
                      const SizedBox(width: 8),
                      _buildVoteButton(
                        context,
                        icon: Icons.arrow_downward,
                        count: report.downvoteCount,
                        isActive: report.userVoteType == 'down',
                        activeColor: Colors.red,
                        onPressed: onDownvote,
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
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: onComment,
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
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
      ),
    );
  }

  /// Whether the community has backed this report up yet. Worked out by a
  /// database trigger: how many upvotes it takes depends on how the reporter
  /// knew about the incident in the first place.
  Widget _buildStatusBadge() {
    final (label, color) = switch (report.status) {
      'verified' => ('Verified', const Color(0xFF1E8E3E)),
      'disputed' => ('Disputed', const Color(0xFFD93025)),
      _ => ('Not verified yet', const Color(0xFF5F6368)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  /// Shows that other people linked their reports to this one, which is the
  /// visible half of the incident-group idea — without it a card looks like a
  /// lone sighting no matter how many people confirmed it.
  Widget _buildIncidentGroupPill(BuildContext context) {
    final count = report.subReportCount;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: const Color(0xFF1A73E8).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link, size: 15, color: Color(0xFF1A73E8)),
                const SizedBox(width: 6),
                Text(
                  count == 1
                      ? '1 other person reported this'
                      : '$count others reported this',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A73E8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoteButton(
    BuildContext context, {
    required IconData icon,
    required int count,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive
            ? activeColor.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive ? activeColor : Colors.grey[300]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              icon,
              size: 18,
              color: isActive ? activeColor : Colors.grey[600],
            ),
            onPressed: onPressed,
          ),
          InkWell(
            onTap: () => _showVoters(context),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 12, top: 6, bottom: 6),
              child: Text(
                '$count',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isActive ? activeColor : Colors.grey[700],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
