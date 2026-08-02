import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:ctrc/features/Report/domain/models/comment_model.dart';
import 'package:ctrc/features/Report/domain/models/report_category.dart';
import 'package:ctrc/features/Report/domain/models/report_model.dart';
import 'package:ctrc/features/Report/domain/services/report_share.dart';
import 'package:ctrc/features/Report/presentation/widgets/voters_bottom_sheet.dart';

/// Card surface. Kept a plain sheet of white with the feed's grey showing
/// through the gaps, which is what makes a run of posts read as a feed instead
/// of a stack of separate boxes.
const Color _cardSurface = Colors.white;
const Color _hairline = Color(0xFFE4E6EB);
const Color _secondaryText = Color(0xFF65676B);
const Color _upvoteBlue = Color(0xFF1877F2);
const Color _downvoteRed = Color(0xFFD93025);

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
  final VoidCallback? onEdit;

  const ReportCardWidget({
    super.key,
    required this.report,
    this.currentLocation,
    required this.onUpvote,
    required this.onDownvote,
    required this.onComment,
    this.onSave,
    this.onOpen,
    this.onEdit,
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

  /// Passes the incident to the phone's own share sheet — WhatsApp, Messenger,
  /// SMS and the rest come from there rather than from a list the app keeps.
  void _share(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    ReportShare.share(
      report,
      origin: box != null && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = ReportCategory.fromLabel(report.category);
    final createdAt = CommentModel.parseTimestamp(report.createdAt);
    final distance = _formatDistance();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: _cardSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: InkWell(
        onTap: () => _open(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Everything above the photo keeps the normal card padding. The
            // photo itself goes edge to edge, the way a feed post looks.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                                if (report.updatedAt != null) 'edited',
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
                      if (onEdit != null)
                        IconButton(
                          tooltip: 'Edit report',
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: onEdit,
                        ),
                      if (onSave != null)
                        IconButton(
                          tooltip: report.isSaved
                              ? 'Remove from saved'
                              : 'Save post',
                          icon: Icon(
                            report.isSaved
                                ? Icons.bookmark
                                : Icons.bookmark_border,
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
                ],
              ),
            ),
            if (report.imageUrl != null && report.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildPhoto(),
            ],
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  /// The tally line and the action bar, laid out the way a social post is: what
  /// the crowd already said on top, what you can do about it underneath, with a
  /// single hairline between the two.
  Widget _buildFooter(BuildContext context) {
    final hasTally = report.upvoteCount > 0 ||
        report.downvoteCount > 0 ||
        report.commentCount > 0;

    return Column(
      children: [
        if (hasTally) _buildTally(context),
        Padding(
          padding: EdgeInsets.fromLTRB(12, hasTally ? 0 : 8, 12, 0),
          child: const Divider(height: 1, thickness: 1, color: _hairline),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            children: [
              _FooterAction(
                icon: Icons.arrow_upward,
                label: 'Upvote',
                isActive: report.userVoteType == 'up',
                activeColor: _upvoteBlue,
                onTap: onUpvote,
              ),
              _FooterAction(
                icon: Icons.arrow_downward,
                label: 'Downvote',
                isActive: report.userVoteType == 'down',
                activeColor: _downvoteRed,
                onTap: onDownvote,
              ),
              _FooterAction(
                icon: Icons.mode_comment_outlined,
                label: 'Comment',
                onTap: onComment,
              ),
              _FooterAction(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: () => _share(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// "12 · 2 · 3 comments". Tapping the votes opens who cast them, tapping the
  /// comments opens the thread — the same targets the action bar below has, but
  /// reached from the number you were already looking at.
  Widget _buildTally(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          if (report.upvoteCount > 0 || report.downvoteCount > 0)
            InkWell(
              onTap: () => _showVoters(context),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (report.upvoteCount > 0) ...[
                      const _TallyBadge(
                        icon: Icons.arrow_upward,
                        color: _upvoteBlue,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${report.upvoteCount}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: _secondaryText,
                        ),
                      ),
                    ],
                    if (report.upvoteCount > 0 && report.downvoteCount > 0)
                      const SizedBox(width: 10),
                    if (report.downvoteCount > 0) ...[
                      const _TallyBadge(
                        icon: Icons.arrow_downward,
                        color: _downvoteRed,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${report.downvoteCount}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: _secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const Spacer(),
          if (report.commentCount > 0)
            InkWell(
              onTap: onComment,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Text(
                  report.commentCount == 1
                      ? '1 comment'
                      : '${report.commentCount} comments',
                  style: const TextStyle(fontSize: 13, color: _secondaryText),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Full width photo of the incident, the way a feed post shows one. A photo
  /// that fails to load is dropped rather than leaving a broken box behind.
  Widget _buildPhoto() {
    return Image.network(
      report.imageUrl!,
      width: double.infinity,
      height: 220,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          height: 220,
          alignment: Alignment.center,
          color: Colors.grey[200],
          child: const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stack) => const SizedBox.shrink(),
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

}

/// The small filled circle a social feed puts in front of a count, so the
/// tally reads as a summary rather than as another row of buttons.
class _TallyBadge extends StatelessWidget {
  const _TallyBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, size: 10, color: Colors.white),
    );
  }
}

/// One of the flat, equal-width actions along the bottom of a card. Flat and
/// unboxed on purpose: four outlined pills competing with the post above them
/// is what made the old footer look busy.
class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? (activeColor ?? _upvoteBlue) : _secondaryText;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
