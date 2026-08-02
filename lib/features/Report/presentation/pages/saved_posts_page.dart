import 'package:ctrc/core/l10n/app_strings.dart';
import 'package:ctrc/core/widgets/sub_page_app_bar.dart';
import 'package:ctrc/features/Auth/presentation/providers/auth_provider.dart';
import 'package:ctrc/features/Report/data/datasources/report_remote_datasource.dart';
import 'package:ctrc/features/Report/domain/models/report_model.dart';
import 'package:ctrc/features/Report/domain/services/vote_toggle.dart';
import 'package:ctrc/features/Report/presentation/widgets/comments_bottom_sheet.dart';
import 'package:ctrc/features/Report/presentation/widgets/report_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SavedPostsPage extends ConsumerStatefulWidget {
  const SavedPostsPage({super.key});

  @override
  ConsumerState<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends ConsumerState<SavedPostsPage> {
  final ReportRemoteDataSource _remoteDataSource = ReportRemoteDataSourceImpl();
  List<ReportModel> _savedReports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSavedReports();
  }

  int? get _userId {
    final user = ref.read(authProvider).user;
    if (user == null) return null;
    return int.tryParse(user.user_id);
  }

  Future<void> _fetchSavedReports() async {
    final userId = _userId;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final reports = await _remoteDataSource.getSavedReports(userId);
      if (mounted) {
        setState(() {
          _savedReports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load saved reports: $e')),
        );
      }
    }
  }

  Future<void> _handleVote(ReportModel report, String type, int index) async {
    final userId = _userId;
    if (userId == null) return;

    setState(() => _savedReports[index] = VoteToggle.apply(report, type));

    try {
      await _remoteDataSource.voteReport(
        reportId: report.reportId,
        userId: userId,
        type: type,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savedReports[index] = report);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to vote: $e')));
    }
  }

  /// Unsaving here removes the card from the list, with an Undo so a mis-tap is
  /// recoverable.
  Future<void> _handleUnsave(ReportModel report, int index) async {
    final userId = _userId;
    if (userId == null) return;

    setState(() => _savedReports.removeAt(index));

    try {
      await _remoteDataSource.unsaveReport(report.reportId, userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Removed from saved'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => _restore(report, index, userId),
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savedReports.insert(index, report));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to unsave: $e')));
    }
  }

  Future<void> _restore(ReportModel report, int index, int userId) async {
    try {
      await _remoteDataSource.saveReport(report.reportId, userId);
      if (!mounted) return;
      setState(() {
        _savedReports.insert(
          index.clamp(0, _savedReports.length),
          report.copyWith(isSaved: true),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not restore: $e')));
    }
  }

  void _openCommentSheet(ReportModel report, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(
        reportId: report.reportId,
        onCommentAdded: () {
          if (!mounted || index >= _savedReports.length) return;
          setState(() {
            _savedReports[index] = _savedReports[index].copyWith(
              commentCount: _savedReports[index].commentCount + 1,
            );
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(authProvider).user != null;
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: SubPageAppBar(
        title: strings.savedPosts,
        menuItems: [
          SubPageMenuItem(
            label: strings.refresh,
            icon: Icons.refresh,
            onSelected: _fetchSavedReports,
          ),
        ],
      ),
      body: !isAuthenticated
          ? _buildSignedOut()
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetchSavedReports,
                  child: _savedReports.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          itemCount: _savedReports.length,
                          itemBuilder: (context, index) {
                            final report = _savedReports[index];
                            return ReportCardWidget(
                              report: report,
                              onUpvote: () => _handleVote(report, 'up', index),
                              onDownvote: () =>
                                  _handleVote(report, 'down', index),
                              onComment: () => _openCommentSheet(report, index),
                              onSave: () => _handleUnsave(report, index),
                            );
                          },
                        ),
                ),
    );
  }

  Widget _buildSignedOut() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'Log in to see the posts you have saved.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/sign-in'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(ref.watch(appStringsProvider).logIn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Icon(Icons.bookmark_border, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Center(
          child: Text(
            ref.watch(appStringsProvider).noSavedPosts,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }
}
