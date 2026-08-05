import '../../../../core/utils/app_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ctrc/core/l10n/app_strings.dart';
import 'package:ctrc/core/widgets/app_toast.dart';
import 'package:ctrc/features/Auth/presentation/providers/auth_provider.dart';
import 'package:ctrc/features/Report/data/datasources/report_remote_datasource.dart';
import 'package:ctrc/features/Report/domain/models/comment_model.dart';
import 'package:ctrc/features/Report/domain/services/vote_toggle.dart';
import 'package:ctrc/features/Report/presentation/widgets/comment_vote_bar.dart';

class CommentsBottomSheet extends ConsumerStatefulWidget {
  final int reportId;
  final VoidCallback? onCommentAdded;

  const CommentsBottomSheet({
    super.key,
    required this.reportId,
    this.onCommentAdded,
  });

  @override
  ConsumerState<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends ConsumerState<CommentsBottomSheet> {
  final ReportRemoteDataSource _remoteDataSource = ReportRemoteDataSourceImpl();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<CommentModel> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int? get _currentUserId {
    final user = ref.read(authProvider).user;
    if (user == null) return null;
    return int.tryParse(user.user_id);
  }

  Future<void> _voteComment(int index, String type) async {
    final userId = _currentUserId;
    if (userId == null) {
      AppToast.info(context, 'Please log in to vote on a comment');
      return;
    }
    if (index < 0 || index >= _comments.length) return;

    final original = _comments[index];
    setState(() => _comments[index] = VoteToggle.applyToComment(original, type));

    try {
      final serverVote = await _remoteDataSource.voteComment(
        commentId: original.commentId,
        userId: userId,
        type: type,
      );
      if (!mounted) return;
      setState(() => _comments[index] = VoteToggle.withVote(original, serverVote));
    } catch (e) {
      if (!mounted) return;
      setState(() => _comments[index] = original);
      AppToast.error(context, e, title: 'Vote not saved');
    }
  }

  Future<void> _fetchComments() async {
    try {
      final comments = await _remoteDataSource.getComments(
        widget.reportId,
        userId: _currentUserId,
      );
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        AppToast.error(context, e, title: 'Could not load comments');
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authProvider).user;
    if (user == null) {
      AppToast.info(context, 'Please log in to add a comment');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _remoteDataSource.addComment(
        reportId: widget.reportId,
        userId: int.parse(user.user_id),
        content: text,
      );

      _commentController.clear();
      if (widget.onCommentAdded != null) {
        widget.onCommentAdded!();
      }

      await _fetchComments();
    } catch (e) {
      if (mounted) {
        AppToast.error(context, e, title: 'Comment not posted');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isAuthenticated = user != null;
    final strings = ref.watch(appStringsProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
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
            const SizedBox(height: 12),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${strings.comments} (${_comments.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'No comments yet. Be the first to reply!',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            final hasAvatar = comment.userImageUrl != null &&
                                comment.userImageUrl!.isNotEmpty;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.blue[50],
                                    backgroundImage:
                                        hasAvatar ? NetworkImage(comment.userImageUrl!) : null,
                                    child: !hasAvatar
                                        ? const Icon(Icons.person, size: 18, color: Colors.blue)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                comment.userName ?? 'User',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                comment.content,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(left: 8),
                                              child: Text(
                                                AppTime.formatRelativeTime(
                                                    comment.createdAt),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            CommentVoteBar(
                                              comment: comment,
                                              enabled: isAuthenticated,
                                              onVote: (type) =>
                                                  _voteComment(index, type),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            const Divider(height: 1),
            
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.blue[50],
                      backgroundImage: (isAuthenticated &&
                              user.image_url != null &&
                              user.image_url!.isNotEmpty)
                          ? NetworkImage(user.image_url!)
                          : null,
                      child: (!isAuthenticated ||
                              user.image_url == null ||
                              user.image_url!.isEmpty)
                          ? const Icon(Icons.person, size: 18, color: Colors.blue)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                enabled: isAuthenticated && !_isSubmitting,
                                textCapitalization: TextCapitalization.sentences,
                                maxLines: null,
                                decoration: InputDecoration(
                                  hintText: isAuthenticated
                                      ? strings.addComment
                                      : 'Log in to write a comment...',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_isSubmitting)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.send, color: Colors.blue),
                                onPressed: isAuthenticated ? _submitComment : null,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
