import 'package:ctrc/features/Report/domain/models/comment_model.dart';
import 'package:ctrc/features/Report/domain/services/vote_toggle.dart';
import 'package:flutter_test/flutter_test.dart';

CommentModel _comment({
  int up = 0,
  int down = 0,
  String? vote,
}) {
  return CommentModel(
    commentId: 1,
    userId: 7,
    content: 'Still blocked as of five minutes ago.',
    upvoteCount: up,
    downvoteCount: down,
    userVoteType: vote,
  );
}

void main() {
  group('applyToComment', () {
    test('a first upvote counts and sticks', () {
      final voted = VoteToggle.applyToComment(_comment(), 'up');

      expect(voted.userVoteType, 'up');
      expect(voted.upvoteCount, 1);
      expect(voted.downvoteCount, 0);
    });

    test('voting the same way again takes the vote back', () {
      final voted =
          VoteToggle.applyToComment(_comment(up: 1, vote: 'up'), 'up');

      expect(voted.userVoteType, isNull);
      expect(voted.upvoteCount, 0);
    });

    test('voting the other way moves the vote rather than adding one', () {
      final voted =
          VoteToggle.applyToComment(_comment(up: 1, vote: 'up'), 'down');

      expect(voted.userVoteType, 'down');
      expect(voted.upvoteCount, 0);
      expect(voted.downvoteCount, 1);
    });

    test('a tally never goes below zero', () {
      final voted = VoteToggle.applyToComment(_comment(vote: 'up'), 'up');

      expect(voted.upvoteCount, 0);
    });
  });

  group('withVote', () {
    test('settles on what the server says, from the pre-tap copy', () {
      final before = _comment(up: 3, vote: null);

      final settled = VoteToggle.withVote(before, 'up');

      expect(settled.userVoteType, 'up');
      expect(settled.upvoteCount, 4);
    });

    test('is idempotent, so a replay cannot double-count', () {
      final before = _comment(up: 3);
      final once = VoteToggle.withVote(before, 'up');
      final twice = VoteToggle.withVote(once, 'up');

      expect(twice.upvoteCount, 4);
      expect(twice.userVoteType, 'up');
    });

    test('a null answer means the vote was taken back', () {
      final before = _comment(up: 2, vote: 'up');
      final settled = VoteToggle.withVote(before, null);

      expect(settled.userVoteType, isNull);
      expect(settled.upvoteCount, 1);
    });

    test('moves the tally across when the server says the other way', () {
      final before = _comment(up: 2, down: 1, vote: 'up');
      final settled = VoteToggle.withVote(before, 'down');

      expect(settled.upvoteCount, 1);
      expect(settled.downvoteCount, 2);
    });
  });

  test('a comment parses its tallies and the reader\'s own vote', () {
    final comment = CommentModel.fromJson({
      'commentId': 5,
      'userId': 9,
      'content': 'Cleared now.',
      'upvoteCount': 4,
      'downvoteCount': 1,
      'userVoteType': 'up',
    });

    expect(comment.upvoteCount, 4);
    expect(comment.downvoteCount, 1);
    expect(comment.userVoteType, 'up');
    expect(comment.score, 3);
  });

  test('a comment from a server without vote columns reads as unvoted', () {
    final comment = CommentModel.fromJson({
      'commentId': 5,
      'userId': 9,
      'content': 'Cleared now.',
    });

    expect(comment.upvoteCount, 0);
    expect(comment.userVoteType, isNull);
  });
}
