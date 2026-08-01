import 'package:flutter_test/flutter_test.dart';
import 'package:ctrc/features/Report/domain/models/report_model.dart';
import 'package:ctrc/features/Report/domain/services/vote_toggle.dart';

ReportModel _report({String? vote, int up = 0, int down = 0}) {
  return ReportModel(
    reportId: 1,
    userId: 2,
    locationId: 3,
    title: 'Truck blocking the lane',
    category: 'Road block',
    upvoteCount: up,
    downvoteCount: down,
    userVoteType: vote,
  );
}

void main() {
  group('VoteToggle', () {
    test('adds an upvote when there was no vote', () {
      final result = VoteToggle.apply(_report(up: 4, down: 1), 'up');

      expect(result.userVoteType, 'up');
      expect(result.upvoteCount, 5);
      expect(result.downvoteCount, 1);
    });

    test('voting up twice clears the vote', () {
      final result = VoteToggle.apply(_report(vote: 'up', up: 5), 'up');

      expect(result.userVoteType, isNull);
      expect(result.upvoteCount, 4);
    });

    test('switching sides moves the vote across', () {
      final result = VoteToggle.apply(
        _report(vote: 'up', up: 5, down: 2),
        'down',
      );

      expect(result.userVoteType, 'down');
      expect(result.upvoteCount, 4);
      expect(result.downvoteCount, 3);
    });

    test('counts never go negative', () {
      final result = VoteToggle.apply(_report(vote: 'down'), 'down');

      expect(result.userVoteType, isNull);
      expect(result.downvoteCount, 0);
    });
  });
}
