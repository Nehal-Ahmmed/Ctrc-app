import '../models/comment_model.dart';
import '../models/report_model.dart';

typedef VoteChange = ({String? next, int upDelta, int downDelta});

class VoteToggle {
  VoteToggle._();

  static VoteChange resolve(String? current, String type) {
    if (type == 'up') {
      if (current == 'up') return (next: null, upDelta: -1, downDelta: 0);
      return (next: 'up', upDelta: 1, downDelta: current == 'down' ? -1 : 0);
    }
    if (current == 'down') return (next: null, upDelta: 0, downDelta: -1);
    return (next: 'down', upDelta: current == 'up' ? -1 : 0, downDelta: 1);
  }

  static ReportModel apply(ReportModel report, String type) {
    final change = resolve(report.userVoteType, type);

    return report.copyWith(
      userVoteType: change.next,
      clearUserVoteType: change.next == null,
      upvoteCount: _clamp(report.upvoteCount + change.upDelta),
      downvoteCount: _clamp(report.downvoteCount + change.downDelta),
    );
  }

  static CommentModel applyToComment(CommentModel comment, String type) {
    final change = resolve(comment.userVoteType, type);

    return comment.copyWith(
      userVoteType: change.next,
      clearUserVoteType: change.next == null,
      upvoteCount: _clamp(comment.upvoteCount + change.upDelta),
      downvoteCount: _clamp(comment.downvoteCount + change.downDelta),
    );
  }

  static CommentModel withVote(CommentModel comment, String? vote) {
    final was = comment.userVoteType;
    if (was == vote) return comment;

    var up = comment.upvoteCount;
    var down = comment.downvoteCount;

    if (was == 'up') up--;
    if (was == 'down') down--;
    if (vote == 'up') up++;
    if (vote == 'down') down++;

    return comment.copyWith(
      userVoteType: vote,
      clearUserVoteType: vote == null,
      upvoteCount: _clamp(up),
      downvoteCount: _clamp(down),
    );
  }

  static int _clamp(int value) => value.clamp(0, 1 << 31);
}
