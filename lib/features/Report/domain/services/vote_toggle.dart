import '../models/report_model.dart';

/// Mirrors the server's vote rules locally so every list can update optimistically
/// the same way: voting again clears the vote, voting the other way moves it.
///
/// This used to be copy-pasted into the feed and re-invented (incorrectly, as a
/// blind +1) in My Reports and Saved Posts.
class VoteToggle {
  VoteToggle._();

  static ReportModel apply(ReportModel report, String type) {
    final current = report.userVoteType;
    String? next;
    var up = 0;
    var down = 0;

    if (type == 'up') {
      if (current == 'up') {
        up = -1;
      } else {
        next = 'up';
        up = 1;
        if (current == 'down') down = -1;
      }
    } else {
      if (current == 'down') {
        down = -1;
      } else {
        next = 'down';
        down = 1;
        if (current == 'up') up = -1;
      }
    }

    return report.copyWith(
      userVoteType: next,
      clearUserVoteType: next == null,
      upvoteCount: (report.upvoteCount + up).clamp(0, 1 << 31),
      downvoteCount: (report.downvoteCount + down).clamp(0, 1 << 31),
    );
  }
}
