import 'package:flutter_test/flutter_test.dart';
import 'package:ctrc/features/Report/domain/models/report_model.dart';
import 'package:ctrc/features/Report/domain/models/sub_report_model.dart';

void main() {
  group('SubReportModel', () {
    test('parses the shape the backend sends', () {
      final update = SubReportModel.fromJson({
        'subReportId': 7,
        'userId': 2,
        'reportId': 1,
        'description': 'Water logging at the metro entrance.',
        'distFromParent': 242.35,
        'upvoteCount': 3,
        'downvoteCount': 1,
        'commentCount': 2,
        'createdAt': '2026-08-01T10:30:00',
        'authorName': 'Rahim',
        'location': {
          'locationId': 2,
          'longitude': 90.4,
          'latitude': 23.8,
          'address': 'Farmgate',
          'city': 'Dhaka',
        },
      });

      expect(update.subReportId, 7);
      expect(update.reportId, 1);
      expect(update.distFromParent, 242.35);
      expect(update.commentCount, 2);
      expect(update.authorName, 'Rahim');
      expect(update.location?.city, 'Dhaka');
      expect(update.createdAt, isNotNull);
    });

    test('tolerates snake_case and missing optional fields', () {
      final update = SubReportModel.fromJson({
        'sub_report_id': 9,
        'user_id': 4,
        'report_id': 1,
        'dist_from_parent': '180.5',
      });

      expect(update.subReportId, 9);
      expect(update.distFromParent, 180.5);
      expect(update.upvoteCount, 0);
      expect(update.description, isNull);
      expect(update.location, isNull);
    });
  });

  group('ReportModel incident group', () {
    ReportModel parse(Map<String, dynamic> extra) => ReportModel.fromJson({
          'reportId': 1,
          'userId': 2,
          'locationId': 3,
          'title': 'Waterlogging on Farmgate road',
          'category': 'Waterlogging',
          ...extra,
        });

    test('defaults to a lone report when the server sends no thread', () {
      final report = parse({});

      expect(report.subReportCount, 0);
      expect(report.subReports, isEmpty);
      expect(report.incidentSize, 1);
    });

    test('counts the reporter plus every linked update', () {
      final report = parse({
        'subReportCount': 2,
        'subReports': [
          {'subReportId': 7, 'userId': 3, 'reportId': 1},
          {'subReportId': 8, 'userId': 4, 'reportId': 1},
        ],
      });

      expect(report.subReports, hasLength(2));
      expect(report.incidentSize, 3);
    });

    test('falls back to the count when only the badge was returned', () {
      // List endpoints send the tally without the thread.
      final report = parse({'subReportCount': 4});

      expect(report.subReports, isEmpty);
      expect(report.incidentSize, 5);
    });

    test('copyWith keeps the thread unless it is replaced', () {
      final report = parse({
        'subReportCount': 1,
        'subReports': [
          {'subReportId': 7, 'userId': 3, 'reportId': 1},
        ],
      });

      final voted = report.copyWith(upvoteCount: 9);

      expect(voted.subReports, hasLength(1));
      expect(voted.subReportCount, 1);
    });
  });
}
