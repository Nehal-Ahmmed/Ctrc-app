import '../../../../core/utils/app_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/sub_page_app_bar.dart';
import '../../../Auth/presentation/providers/auth_provider.dart';
import '../../../Map/domain/utils/geo_utils.dart';
import '../../data/datasources/report_remote_datasource.dart';
import '../../domain/models/comment_model.dart';
import '../../domain/models/report_category.dart';
import '../../domain/models/sub_report_model.dart';
import '../../domain/services/vote_toggle.dart';
import '../widgets/comment_vote_bar.dart';

class SubReportDetailsPage extends ConsumerStatefulWidget {
  final int subReportId;

  const SubReportDetailsPage({super.key, required this.subReportId});

  @override
  ConsumerState<SubReportDetailsPage> createState() => _SubReportDetailsPageState();
}

class _SubReportDetailsPageState extends ConsumerState<SubReportDetailsPage> {
  final ReportRemoteDataSource _dataSource = ReportRemoteDataSourceImpl();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocus = FocusNode();

  final GlobalKey _commentsKey = GlobalKey();

  SubReportModel? _subReport;
  List<CommentModel> _comments = const [];
  bool _isLoading = true;
  bool _isLoadingComments = true;
  bool _isPostingComment = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

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

  int? get _currentUserId {
    final idString = ref.read(authProvider).user?.user_id;
    return idString != null ? int.tryParse(idString) : null;
  }

  bool _requireLogin(String action) {
    if (_currentUserId == null) {
      AppToast.error(context, 'You must be logged in to $action.');
      return false;
    }
    return true;
  }

  Future<void> _load() async {
    await Future.wait([_loadSubReport(), _loadComments()]);
  }

  Future<void> _loadSubReport() async {
    try {
      final subReport = await _dataSource.getSubReportById(
        widget.subReportId,
        userId: _currentUserId,
      );
      if (!mounted) return;
      setState(() {
        _subReport = subReport;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (_subReport == null) _error = AppError.messageOf(e);
      });
    }
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _dataSource.getSubReportComments(
        widget.subReportId,
        userId: _currentUserId,
      );
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

  Future<void> _vote(String type) async {
    if (!_requireLogin('vote')) return;

    final subReport = _subReport;
    if (subReport == null) return;

    try {
      await _dataSource.voteSubReport(
        subReportId: subReport.subReportId,
        userId: _currentUserId!,
        type: type,
      );
      await _loadSubReport(); 
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, e, title: 'Could not submit vote');
    }
  }

  Future<void> _postComment() async {
    if (!_requireLogin('comment')) return;

    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isPostingComment = true);
    try {
      await _dataSource.addSubReportComment(
        subReportId: widget.subReportId,
        userId: _currentUserId!,
        content: content,
      );
      _commentController.clear();
      await _loadComments();

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, e, title: 'Could not post comment');
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: SubPageAppBar(title: 'Update Details'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: const SubPageAppBar(title: 'Update Details'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _load();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final subReport = _subReport!;

    return Scaffold(
      appBar: const SubPageAppBar(title: 'Update Details'),
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _buildHeader(subReport),
                  if (subReport.imageUrl != null) _buildPhoto(subReport),
                  if (subReport.location != null) _buildMap(subReport),
                  _buildActions(subReport),
                  _buildCommentsList(subReport),
                ],
              ),
            ),
          ),
          _buildCommentComposer(),
        ],
      ),
    );
  }

  Widget _buildHeader(SubReportModel subReport) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subReport.parentTitle != null)
            GestureDetector(
              onTap: () => context.push('/report/${subReport.reportId}'),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back_ios_new, size: 12, color: Color(0xFF1A73E8)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Part of: ${subReport.parentTitle}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A73E8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue[50],
                backgroundImage: subReport.authorImageUrl != null
                    ? NetworkImage(subReport.authorImageUrl!)
                    : null,
                child: subReport.authorImageUrl == null
                    ? const Icon(Icons.person, color: Color(0xFF1A73E8))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subReport.authorName ?? 'User #${subReport.userId}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (subReport.createdAt != null)
                          AppTime.formatRelativeTime(subReport.createdAt!),
                        if (subReport.distFromParent != null)
                          '${GeoUtils.formatDistance(subReport.distFromParent!)} from the report',
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (subReport.description != null && subReport.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              subReport.description!,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhoto(SubReportModel subReport) {
    return Container(
      width: double.infinity,
      color: Colors.black,
      child: Image.network(
        subReport.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 200,
          color: Colors.grey[200],
          child: const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
        ),
      ),
    );
  }

  Widget _buildMap(SubReportModel subReport) {
    final lat = subReport.location!.latitude;
    final lng = subReport.location!.longitude;
    final point = LatLng(lat, lng);
    final category = ReportCategory.fromLabel(subReport.category);

    return Container(
      height: 140,
      width: double.infinity,
      color: Colors.grey[200],
      child: FlutterMap(
        options: MapOptions(
          initialCenter: point,
          initialZoom: 15.5,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.ctrc.app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: point,
                width: 44,
                height: 44,
                child: Icon(category.icon, color: category.color, size: 34),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions(SubReportModel subReport) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => _vote('up'),
            icon: const Icon(Icons.arrow_upward, size: 20),
            label: Text('${subReport.upvoteCount}'),
            style: TextButton.styleFrom(
              foregroundColor: subReport.userVoteType == 'up'
                  ? const Color(0xFF1A73E8)
                  : Colors.grey[800],
            ),
          ),
          TextButton.icon(
            onPressed: () => _vote('down'),
            icon: const Icon(Icons.arrow_downward, size: 20),
            label: Text('${subReport.downvoteCount}'),
            style: TextButton.styleFrom(
              foregroundColor: subReport.userVoteType == 'down'
                  ? const Color(0xFFD93025)
                  : Colors.grey[800],
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _jumpToComments,
            icon: const Icon(Icons.comment_outlined, size: 20),
            label: Text('${subReport.commentCount}'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[800]),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList(SubReportModel subReport) {
    return Container(
      key: _commentsKey,
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _comments.isEmpty ? 'Comments' : 'Comments (${_comments.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (_isLoadingComments)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No comments yet. Be the first to share your thoughts.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          else ...[
            const SizedBox(height: 16),
            ..._comments.indexed.map(
              (entry) => _buildComment(entry.$2, entry.$1),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _voteComment(int index, String type) async {
    final userId = _currentUserId;
    if (userId == null) {
      AppToast.info(context, 'Please log in to vote on a comment');
      return;
    }
    if (index < 0 || index >= _comments.length) return;

    final original = _comments[index];
    setState(() {
      _comments = [..._comments]
        ..[index] = VoteToggle.applyToComment(original, type);
    });

    try {
      final serverVote = await _dataSource.voteComment(
        commentId: original.commentId,
        userId: userId,
        type: type,
      );
      if (!mounted) return;
      setState(() {
        _comments = [..._comments]
          ..[index] = VoteToggle.withVote(original, serverVote);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _comments = [..._comments]..[index] = original;
      });
      AppToast.error(context, e, title: 'Vote not saved');
    }
  }

  Widget _buildComment(CommentModel comment, int index) {
    final hasAvatar = comment.userImageUrl != null && comment.userImageUrl!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue[50],
            backgroundImage: hasAvatar ? NetworkImage(comment.userImageUrl!) : null,
            child: !hasAvatar ? const Icon(Icons.person, size: 18, color: Color(0xFF1A73E8)) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName ?? 'User #${comment.userId}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.createdAt != null
                          ? AppTime.formatRelativeTime(comment.createdAt!)
                          : '',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 14, height: 1.35),
                ),
                CommentVoteBar(
                  comment: comment,
                  enabled: _currentUserId != null,
                  onVote: (type) => _voteComment(index, type),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentComposer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              focusNode: _commentFocus,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedOpacity(
            opacity: _commentController.text.trim().isNotEmpty ? 1.0 : 0.5,
            duration: const Duration(milliseconds: 200),
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1A73E8),
              ),
              child: IconButton(
                icon: _isPostingComment
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                onPressed: _commentController.text.trim().isEmpty || _isPostingComment
                    ? null
                    : _postComment,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
