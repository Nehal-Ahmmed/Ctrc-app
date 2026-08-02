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

class MyReportsPage extends ConsumerStatefulWidget {
  const MyReportsPage({super.key});

  @override
  ConsumerState<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends ConsumerState<MyReportsPage> {
  final ReportRemoteDataSource _remoteDataSource = ReportRemoteDataSourceImpl();
  List<ReportModel> _myReports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyReports();
  }

  int? get _userId {
    final user = ref.read(authProvider).user;
    if (user == null) return null;
    return int.tryParse(user.user_id);
  }

  Future<void> _fetchMyReports() async {
    final userId = _userId;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final reports = await _remoteDataSource.getMyReports(userId);
      if (mounted) {
        setState(() {
          _myReports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load your reports: $e')),
        );
      }
    }
  }

  Future<void> _handleVote(ReportModel report, String type, int index) async {
    final userId = _userId;
    if (userId == null) return;

    setState(() => _myReports[index] = VoteToggle.apply(report, type));

    try {
      await _remoteDataSource.voteReport(
        reportId: report.reportId,
        userId: userId,
        type: type,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _myReports[index] = report);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to vote: $e')));
    }
  }

  Future<void> _handleSave(ReportModel report, int index) async {
    final userId = _userId;
    if (userId == null) return;

    final wasSaved = report.isSaved;
    setState(() => _myReports[index] = report.copyWith(isSaved: !wasSaved));

    try {
      if (wasSaved) {
        await _remoteDataSource.unsaveReport(report.reportId, userId);
      } else {
        await _remoteDataSource.saveReport(report.reportId, userId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _myReports[index] = report);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to update save: $e')));
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
          if (!mounted) return;
          setState(() {
            _myReports[index] = _myReports[index]
                .copyWith(commentCount: _myReports[index].commentCount + 1);
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
        title: strings.myReports,
        menuItems: [
          SubPageMenuItem(
            label: strings.refresh,
            icon: Icons.refresh,
            onSelected: _fetchMyReports,
          ),
        ],
      ),
      body: !isAuthenticated
          ? _buildSignedOut()
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetchMyReports,
                  child: _myReports.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          itemCount: _myReports.length,
                          itemBuilder: (context, index) {
                            final report = _myReports[index];
                            return ReportCardWidget(
                              report: report,
                              onUpvote: () => _handleVote(report, 'up', index),
                              onDownvote: () =>
                                  _handleVote(report, 'down', index),
                              onComment: () => _openCommentSheet(report, index),
                              onSave: () => _handleSave(report, index),
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
              'Log in to see the reports you have filed.',
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
    // Kept scrollable so pull-to-refresh still works on an empty list.
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Icon(Icons.article_outlined, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Center(
          child: Text(
            ref.watch(appStringsProvider).noReportsYet,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }
}
