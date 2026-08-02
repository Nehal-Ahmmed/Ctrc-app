import 'package:flutter_test/flutter_test.dart';
import 'package:ctrc/features/Map/domain/services/incident_severity.dart';
import 'package:ctrc/features/Report/domain/models/comment_model.dart';
import 'package:ctrc/features/Report/domain/models/report_model.dart';

/// [ReportModel] keeps its timestamps as strings, but every screen reads them
/// back with `DateTime.tryParse`. These cover the shapes the backend can send
/// so a numeric timestamp cannot quietly become an unparseable string.
void main() {
  ReportModel parse(Map<String, dynamic> extra) => ReportModel.fromJson({
        'reportId': 1,
        'userId': 2,
        'locationId': 3,
        'title': 'Waterlogging on Farmgate road',
        'category': 'Waterlogging',
        ...extra,
      });

  group('ReportModel timestamps', () {
    test('keeps an iso string as it arrived', () {
      final report = parse({'createdAt': '2026-08-01T10:30:00'});

      expect(report.createdAt, '2026-08-01T10:30:00');
      expect(CommentModel.parseTimestamp(report.createdAt), isNotNull);
    });

    test('normalises epoch millis into something parseable', () {
      // Jackson emits a java.sql.Timestamp as a number under some configs.
      final millis = DateTime.utc(2026, 8, 1, 10, 30).millisecondsSinceEpoch;
      final report = parse({'createdAt': millis});

      expect(report.createdAt, isNotNull);
      final parsed = CommentModel.parseTimestamp(report.createdAt);
      expect(parsed, isNotNull);
      expect(parsed!.toUtc(), DateTime.utc(2026, 8, 1, 10, 30));
    });

    test('a numeric expiresAt still decides whether the report is live', () {
      final expired = parse({
        'expiresAt': DateTime.now()
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch,
      });
      final live = parse({
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 2))
            .millisecondsSinceEpoch,
      });

      expect(IncidentSeverity.isActive(expired), isFalse);
      expect(IncidentSeverity.isActive(live), isTrue);
    });

    test('an absent or empty timestamp stays null', () {
      expect(parse({}).createdAt, isNull);
      expect(parse({'createdAt': ''}).createdAt, isNull);
    });

    test('updatedAt is what marks a report as edited', () {
      expect(parse({}).updatedAt, isNull);
      expect(parse({'updatedAt': '2026-08-02T09:00:00'}).updatedAt, isNotNull);
    });
  });

  group('ReportModel field mapping', () {
    test('reads the camelCase shape the backend sends', () {
      final report = parse({
        'evidenceType': 'heard',
        'status': 'verified',
        'imageUrl': 'https://example.test/a.jpg',
        'upvoteCount': 5,
        'downvoteCount': 1,
        'commentCount': 3,
        'isSaved': true,
        'userVoteType': 'up',
        'authorName': 'Rahim',
        'location': {
          'locationId': 3,
          'longitude': 90.4,
          'latitude': 23.8,
          'city': 'Dhaka',
        },
      });

      expect(report.evidenceType, 'heard');
      expect(report.status, 'verified');
      expect(report.imageUrl, 'https://example.test/a.jpg');
      expect(report.commentCount, 3);
      expect(report.isSaved, isTrue);
      expect(report.userVoteType, 'up');
      expect(report.location?.city, 'Dhaka');
    });

    test('tolerates snake_case and falls back to defaults', () {
      final report = ReportModel.fromJson({
        'report_id': 11,
        'user_id': 2,
        'location_id': 3,
        'title': 'Broken road',
        'category': 'Road Damage',
        'evidence_type': 'guessed',
        'image_url': 'https://example.test/b.jpg',
        'upvote_count': '4',
        'is_saved': true,
        'user_vote_type': 'down',
      });

      expect(report.reportId, 11);
      expect(report.evidenceType, 'guessed');
      expect(report.imageUrl, 'https://example.test/b.jpg');
      expect(report.upvoteCount, 4);
      expect(report.isSaved, isTrue);
      expect(report.userVoteType, 'down');
      // Not sent, so the safe defaults apply.
      expect(report.status, 'unverified');
      expect(report.downvoteCount, 0);
      expect(report.location, isNull);
    });

    test('survives a location that came back without coordinates', () {
      final report = parse({'location': <String, dynamic>{}});

      expect(report.location, isNotNull);
      expect(report.location!.latitude, 0);
      expect(report.location!.longitude, 0);
    });

    test('round-trips through toJson', () {
      final report = parse({
        'status': 'disputed',
        'commentCount': 2,
        'createdAt': '2026-08-01T10:30:00',
        'subReportCount': 3,
      });

      final again = ReportModel.fromJson(report.toJson());

      expect(again.reportId, report.reportId);
      expect(again.status, 'disputed');
      expect(again.commentCount, 2);
      expect(again.createdAt, '2026-08-01T10:30:00');
      expect(again.subReportCount, 3);
    });
  });
}
