import 'dart:async';

import 'package:ctrc/core/l10n/app_strings.dart';
import 'package:ctrc/core/widgets/app_toast.dart';
import 'package:ctrc/core/widgets/sub_page_app_bar.dart';
import 'package:ctrc/features/Auth/presentation/providers/auth_provider.dart';
import 'package:ctrc/features/Report/data/datasources/report_local_cache.dart';
import 'package:ctrc/features/Report/data/datasources/report_remote_datasource.dart';
import 'package:ctrc/features/Report/domain/models/report_model.dart';
import 'package:ctrc/features/Report/domain/services/vote_toggle.dart';
import 'package:ctrc/features/Report/presentation/widgets/comments_bottom_sheet.dart';
import 'package:ctrc/features/Report/presentation/widgets/report_card_widget.dart';
import 'package:ctrc/features/Report/presentation/widgets/create_report_bottom_sheet.dart';
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
  final ReportLocalCache _cache = ReportLocalCache();
  List<ReportModel> _savedReports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // A bookmark list is something the user curated; it should be readable
    // without waiting on — or having — a connection.
    final cached = _cache.read(
      ReportLocalCache.savedBucket,
      userId: ref.read(authIdentityProvider),
    );
    if (cached != null) _savedReports = cached.reports;

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
      unawaited(_cache.write(
        ReportLocalCache.savedBucket,
        reports,
        userId: ref.read(authIdentityProvider),
      ));
      if (mounted) {
        setState(() {
          _savedReports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.error(context, e, title: 'Could not load saved reports');
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
      AppToast.error(context, e, title: 'Vote not saved');
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
      AppToast.show(
        context,
        'Removed from saved',
        // Long enough to notice the Undo and reach for it.
        duration: const Duration(seconds: 5),
        action: ToastAction(
          label: 'Undo',
          onPressed: () => _restore(report, index, userId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savedReports.insert(index, report));
      AppToast.error(context, e, title: 'Could not remove that');
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
      AppToast.error(context, e, title: 'Could not restore');
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

  Future<void> _handleEditReport(ReportModel report, int index) async {
    final location = report.location;
    final result = await showModalBottomSheet<CreateReportResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CreateReportBottomSheet(
        latitude: location?.latitude ?? 0,
        longitude: location?.longitude ?? 0,
        editReport: report,
        locationLabel: [location?.address, location?.city]
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .join(', '),
      ),
    );

    if (result == CreateReportResult.edited) {
      _fetchSavedReports();
    }
  }

  /// Nothing here survives a change of account — the whole list belonged to the
  /// previous one.
  void _onIdentityChanged() {
    if (!mounted) return;
    setState(() {
      _savedReports = [];
      _isLoading = true;
    });
    _fetchSavedReports();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(authIdentityProvider, (previous, next) {
      if (previous != next) _onIdentityChanged();
    });

    final isAuthenticated = ref.watch(isAuthenticatedProvider);
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
                            final user = ref.read(authProvider).user;
                            final currentUserId = user != null ? int.tryParse(user.user_id) : null;
                            final isOwner = currentUserId != null && report.userId == currentUserId;

                            return ReportCardWidget(
                              report: report,
                              onUpvote: () => _handleVote(report, 'up', index),
                              onDownvote: () =>
                                  _handleVote(report, 'down', index),
                              onComment: () => _openCommentSheet(report, index),
                              onSave: () => _handleUnsave(report, index),
                              onEdit: isOwner ? () => _handleEditReport(report, index) : null,
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
