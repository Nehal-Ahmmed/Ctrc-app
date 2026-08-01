import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/widgets/sub_page_app_bar.dart';
import '../../../Auth/presentation/providers/auth_provider.dart';
import '../../../Map/domain/services/incident_severity.dart';
import '../../../Map/domain/utils/geo_utils.dart';
import '../../data/datasources/report_remote_datasource.dart';
import '../../domain/models/comment_model.dart';
import '../../domain/models/report_category.dart';
import '../../domain/models/report_model.dart';
import '../widgets/create_report_bottom_sheet.dart';

/// Full detail view for a single incident report.
///
/// This is what an alert opens into — from the map's area alerts, the route
/// alerts, or anywhere else a report is listed.
class ReportDetailsPage extends ConsumerStatefulWidget {
  final int reportId;

  /// Optional pre-fetched report so the page can render instantly while the
  /// authoritative copy loads.
  final ReportModel? initialReport;

  /// Where the viewer is, used only for the "x km away" line.
  final LatLng? viewerLocation;

  const ReportDetailsPage({
    super.key,
    required this.reportId,
    this.initialReport,
    this.viewerLocation,
  });

  @override
  ConsumerState<ReportDetailsPage> createState() => _ReportDetailsPageState();
}

class _ReportDetailsPageState extends ConsumerState<ReportDetailsPage> {
  final ReportRemoteDataSource _dataSource = ReportRemoteDataSourceImpl();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocus = FocusNode();

  /// Anchors the "jump to comments" action on the comment counter.
  final GlobalKey _commentsKey = GlobalKey();

  ReportModel? _report;
  List<CommentModel> _comments = const [];
  bool _isLoadingReport = true;
  bool _isLoadingComments = true;
  bool _isPostingComment = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _report = widget.initialReport;
    _isLoadingReport = widget.initialReport == null;
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  /// Scrolls the comment thread into view and drops the caret in the composer,
  /// which is what tapping the comment counter should have done all along.
  void _jumpToComments() {
    final target = _commentsKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    } else if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    _commentFocus.requestFocus();
  }

  /// Files a sub-report against this incident — the other half of the
  /// link-or-create flow, reached from an incident you are already looking at.
  Future<void> _addUpdate() async {
    final report = _report;
    if (report == null) return;
    if (!_requireLogin('add an update')) return;

    final location = report.location;
    if (location == null) {
      _notify('This report has no location to attach an update to.');
      return;
    }

    final result = await showModalBottomSheet<CreateReportResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CreateReportBottomSheet(
        latitude: location.latitude,
        longitude: location.longitude,
        parentReportId: report.reportId,
        parentTitle: report.title,
        locationLabel: [location.address, location.city]
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .join(', '),
      ),
    );

    if (result == null || !mounted) return;
    _notify(result.message);
    await _load();
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _load() async {
    await Future.wait([_loadReport(), _loadComments()]);
  }

  Future<void> _loadReport() async {
    try {
      final report = await _dataSource.getReportById(
        widget.reportId,
        userId: _currentUserId,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoadingReport = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingReport = false;
        // Keep whatever we were handed; only surface the error if we have
        // nothing at all to show.
        if (_report == null) _error = '$e';
      });
    }
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _dataSource.getComments(widget.reportId);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingComments = false);
    }
  }

  int? get _currentUserId {
    final user = ref.read(authProvider).user;
    if (user == null) return null;
    return int.tryParse(user.user_id);
  }

  bool _requireLogin(String action) {
    if (_currentUserId != null) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please log in to $action')),
    );
    return false;
  }

  Future<void> _vote(String type) async {
    if (!_requireLogin('vote')) return;
    final report = _report;
    if (report == null) return;

    // Mirror the server: voting the same way again removes the vote, voting the
    // other way moves it across.
    final currentVote = report.userVoteType;
    String? newVote;
    var upDelta = 0;
    var downDelta = 0;

    if (type == 'up') {
      if (currentVote == 'up') {
        upDelta = -1;
      } else {
        newVote = 'up';
        upDelta = 1;
        if (currentVote == 'down') downDelta = -1;
      }
    } else {
      if (currentVote == 'down') {
        downDelta = -1;
      } else {
        newVote = 'down';
        downDelta = 1;
        if (currentVote == 'up') upDelta = -1;
      }
    }

    setState(() {
      _report = report.copyWith(
        userVoteType: newVote,
        clearUserVoteType: newVote == null,
        upvoteCount: report.upvoteCount + upDelta,
        downvoteCount: report.downvoteCount + downDelta,
      );
    });

    try {
      await _dataSource.voteReport(
        reportId: report.reportId,
        userId: _currentUserId!,
        type: type,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _report = report);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to vote: $e')));
    }
  }

  Future<void> _toggleSave() async {
    if (!_requireLogin('save posts')) return;
    final report = _report;
    if (report == null) return;

    final wasSaved = report.isSaved;
    setState(() => _report = report.copyWith(isSaved: !wasSaved));

    try {
      if (wasSaved) {
        await _dataSource.unsaveReport(report.reportId, _currentUserId!);
      } else {
        await _dataSource.saveReport(report.reportId, _currentUserId!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _report = report);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to update save: $e')));
    }
  }

  Future<void> _postComment() async {
    if (!_requireLogin('comment')) return;
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    final report = _report;
    if (report == null) return;

    setState(() => _isPostingComment = true);

    try {
      await _dataSource.addComment(
        reportId: report.reportId,
        userId: _currentUserId!,
        content: content,
      );
      if (!mounted) return;
      _commentController.clear();
      setState(() {
        _isPostingComment = false;
        _report = report.copyWith(commentCount: report.commentCount + 1);
      });
      FocusScope.of(context).unfocus();
      await _loadComments();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPostingComment = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to comment: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: SubPageAppBar(
        title: 'Report details',
        menuItems: [
          SubPageMenuItem(
            label: 'Add an update',
            icon: Icons.add_comment_outlined,
            onSelected: _addUpdate,
          ),
          SubPageMenuItem(
            label: 'Refresh',
            icon: Icons.refresh,
            onSelected: _load,
          ),
          if (report != null)
            SubPageMenuItem(
              label: report.isSaved ? 'Remove from saved' : 'Save post',
              icon: report.isSaved ? Icons.bookmark : Icons.bookmark_border,
              onSelected: _toggleSave,
            ),
        ],
      ),
      body: _isLoadingReport && report == null
          ? const Center(child: CircularProgressIndicator())
          : report == null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      _buildHeader(report),
                      if (report.location != null) _buildMapPreview(report),
                      _buildActions(report),
                      _buildComments(),
                    ],
                  ),
                ),
      bottomNavigationBar: report == null ? null : _buildCommentComposer(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Report not found',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ReportModel report) {
    final level = IncidentSeverity.of(report);
    final category = ReportCategory.fromLabel(report.category);
    final createdAt = CommentModel.parseTimestamp(report.createdAt);
    final location = report.location;

    final distance = (widget.viewerLocation != null && location != null)
        ? GeoUtils.metersBetween(
            widget.viewerLocation!,
            LatLng(location.latitude, location.longitude),
          )
        : null;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: level.color.withValues(alpha: 0.15),
                child: Icon(category.icon, color: level.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        category.label,
                        if (createdAt != null) formatRelativeTime(createdAt),
                        if (distance != null)
                          '${GeoUtils.formatDistance(distance)} away',
                      ].join(' · '),
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                    ),
                    if (report.authorName != null &&
                        report.authorName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Reported by ${report.authorName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: level.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(level.icon, size: 16, color: level.color),
                const SizedBox(width: 6),
                Text(
                  'Road impact: ${level.label}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: level.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (report.description != null && report.description!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              report.description!,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          ],
          if (location?.address != null || location?.city != null) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_outlined, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [location?.address, location?.city]
                        .whereType<String>()
                        .where((e) => e.isNotEmpty)
                        .join(', '),
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMapPreview(ReportModel report) {
    final point = LatLng(report.location!.latitude, report.location!.longitude);
    final level = IncidentSeverity.of(report);

    return Container(
      height: 180,
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: point,
          initialZoom: 15,
          interactionOptions:
              const InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.ctrc.app',
          ),
          CircleLayer(
            circles: [
              CircleMarker(
                point: point,
                radius: 300,
                useRadiusInMeter: true,
                color: level.color.withValues(alpha: 0.15),
                borderColor: level.color.withValues(alpha: 0.6),
                borderStrokeWidth: 1.5,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: point,
                width: 44,
                height: 44,
                child: Icon(level.icon, color: level.color, size: 34),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ReportModel report) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => _vote('up'),
            icon: const Icon(Icons.arrow_upward, size: 20),
            label: Text('${report.upvoteCount}'),
            style: TextButton.styleFrom(
              foregroundColor: report.userVoteType == 'up'
                  ? const Color(0xFF1A73E8)
                  : Colors.grey[800],
            ),
          ),
          TextButton.icon(
            onPressed: () => _vote('down'),
            icon: const Icon(Icons.arrow_downward, size: 20),
            label: Text('${report.downvoteCount}'),
            style: TextButton.styleFrom(
              foregroundColor: report.userVoteType == 'down'
                  ? const Color(0xFFD93025)
                  : Colors.grey[800],
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _jumpToComments,
            icon: const Icon(Icons.comment_outlined, size: 20),
            label: Text('${report.commentCount}'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[800]),
          ),
          IconButton(
            tooltip: 'Add an update to this incident',
            onPressed: _addUpdate,
            icon: Icon(Icons.add_comment_outlined, color: Colors.grey[700]),
          ),
          IconButton(
            tooltip: report.isSaved ? 'Remove from saved' : 'Save post',
            onPressed: _toggleSave,
            icon: Icon(
              report.isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: report.isSaved ? const Color(0xFF1A73E8) : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComments() {
    return Container(
      key: _commentsKey,
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comments (${_comments.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_isLoadingComments)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No comments yet. Be the first to add context.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          else
            ..._comments.map(_buildCommentTile),
        ],
      ),
    );
  }

  Widget _buildCommentTile(CommentModel comment) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue[50],
            backgroundImage:
                (comment.userImageUrl != null && comment.userImageUrl!.isNotEmpty)
                    ? NetworkImage(comment.userImageUrl!)
                    : null,
            child: (comment.userImageUrl == null || comment.userImageUrl!.isEmpty)
                ? const Icon(Icons.person, size: 18, color: Color(0xFF1A73E8))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      (comment.userName != null && comment.userName!.isNotEmpty)
                          ? comment.userName!
                          : 'User #${comment.userId}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatRelativeTime(comment.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.content, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentComposer() {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[300]!)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocus,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Add a comment...',
                  border: InputBorder.none,
                ),
              ),
            ),
            _isPostingComment
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF1A73E8)),
                    onPressed: _postComment,
                  ),
          ],
        ),
      ),
    );
  }
}
