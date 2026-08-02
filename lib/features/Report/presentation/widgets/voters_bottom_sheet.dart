import 'package:flutter/material.dart';
import 'package:ctrc/core/widgets/app_toast.dart';
import 'package:ctrc/features/Report/data/datasources/report_remote_datasource.dart';
import 'package:ctrc/features/Report/domain/models/voter_model.dart';

class VotersBottomSheet extends StatefulWidget {
  final int reportId;

  const VotersBottomSheet({
    super.key,
    required this.reportId,
  });

  @override
  State<VotersBottomSheet> createState() => _VotersBottomSheetState();
}

class _VotersBottomSheetState extends State<VotersBottomSheet> with SingleTickerProviderStateMixin {
  final ReportRemoteDataSource _remoteDataSource = ReportRemoteDataSourceImpl();
  TabController? _tabController;
  List<VoterModel> _voters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVoters();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchVoters() async {
    try {
      final voters = await _remoteDataSource.getVotes(widget.reportId);
      if (mounted) {
        setState(() {
          _voters = voters;
          _isLoading = false;
          _tabController = TabController(length: 3, vsync: this);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        AppToast.error(context, e, title: 'Could not load reactions');
      }
    }
  }

  List<VoterModel> get _upvoters => _voters.where((v) => v.voteType == 'up').toList();
  List<VoterModel> get _downvoters => _voters.where((v) => v.voteType == 'down').toList();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Handle bar
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
                // TabBar
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: Colors.blue,
                  tabs: [
                    Tab(text: 'All (${_voters.length})'),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_upward, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text('${_upvoters.length}'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_downward, size: 16, color: Colors.red),
                          const SizedBox(width: 4),
                          Text('${_downvoters.length}'),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 1),
                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildVotersList(_voters),
                      _buildVotersList(_upvoters),
                      _buildVotersList(_downvoters),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildVotersList(List<VoterModel> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No votes to show',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final voter = list[index];
        final hasAvatar = voter.userImageUrl != null && voter.userImageUrl!.isNotEmpty;
        final isUpvote = voter.voteType == 'up';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue[50],
                    backgroundImage: hasAvatar ? NetworkImage(voter.userImageUrl!) : null,
                    child: !hasAvatar
                        ? const Icon(Icons.person, size: 20, color: Colors.blue)
                        : null,
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        isUpvote ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 10,
                        color: isUpvote ? Colors.blue : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  voter.userName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                isUpvote ? Icons.arrow_upward : Icons.arrow_downward,
                color: isUpvote ? Colors.blue[100] : Colors.red[100],
              ),
            ],
          ),
        );
      },
    );
  }
}
