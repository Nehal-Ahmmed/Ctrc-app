import 'package:ctrc/features/Auth/presentation/providers/auth_provider.dart';
import 'package:ctrc/features/Report/data/datasources/report_remote_datasource.dart';
import 'package:ctrc/features/Report/domain/models/report_model.dart';
import 'package:ctrc/features/Report/presentation/widgets/report_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> _fetchSavedReports() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final reports = await _remoteDataSource.getSavedReports(int.parse(user.user_id));
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

  void _handleVote(ReportModel report, String type, int index) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() {
      if (type == 'up') {
        _savedReports[index] = report.copyWith(upvoteCount: report.upvoteCount + 1);
      } else {
        _savedReports[index] = report.copyWith(downvoteCount: report.downvoteCount + 1);
      }
    });

    try {
      if (type == 'up') {
        await _remoteDataSource.voteReport(reportId: report.reportId, userId: int.parse(user.user_id), type: 'up');
      } else {
        await _remoteDataSource.voteReport(reportId: report.reportId, userId: int.parse(user.user_id), type: 'down');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _savedReports[index] = report;
        });
      }
    }
  }

  void _handleSave(ReportModel report, int index) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    // In saved page, unsaving removes it locally
    final isCurrentlySaved = report.isSaved;
    
    if (isCurrentlySaved) {
      setState(() {
        _savedReports.removeAt(index);
      });
      try {
        await _remoteDataSource.unsaveReport(report.reportId, int.parse(user.user_id));
      } catch (e) {
        if (mounted) {
          // Revert
          setState(() {
             _savedReports.insert(index, report);
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to unsave: $e')));
        }
      }
    }
  }

  void _openCommentDialog(ReportModel report, int index) {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final TextEditingController commentController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16, right: 16, top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Add Comment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    decoration: const InputDecoration(hintText: 'Write a comment...', border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        if (commentController.text.trim().isEmpty) return;
                        setModalState(() => isSubmitting = true);
                        try {
                          await _remoteDataSource.addComment(reportId: report.reportId, userId: int.parse(user.user_id), content: commentController.text.trim());
                          if (mounted) {
                            setState(() {
                              _savedReports[index] = report.copyWith(commentCount: report.commentCount + 1);
                            });
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (mounted) setModalState(() => isSubmitting = false);
                        }
                      },
                      child: isSubmitting 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator())
                          : const Text('Post Comment'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Saved Posts'),
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedReports.isEmpty
              ? const Center(child: Text('You have no saved posts.'))
              : RefreshIndicator(
                  onRefresh: _fetchSavedReports,
                  child: ListView.builder(
                    itemCount: _savedReports.length,
                    itemBuilder: (context, index) {
                      final report = _savedReports[index];
                      return ReportCardWidget(
                        report: report,
                        onUpvote: () => _handleVote(report, 'up', index),
                        onDownvote: () => _handleVote(report, 'down', index),
                        onComment: () => _openCommentDialog(report, index),
                        onSave: () => _handleSave(report, index),
                      );
                    },
                  ),
                ),
    );
  }
}
