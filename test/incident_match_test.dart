import 'package:ctrc/features/Report/domain/models/report_model.dart';
import 'package:ctrc/features/Report/domain/services/incident_match.dart';
import 'package:flutter_test/flutter_test.dart';

ReportModel _report({
  int id = 1,
  String title = 'Traffic jam',
  DateTime? createdAt,
}) {
  return ReportModel(
    reportId: id,
    userId: 1,
    locationId: 1,
    title: title,
    category: 'Traffic Jam',
    createdAt: (createdAt ?? DateTime.now().toUtc()).toIso8601String(),
  );
}

IncidentCandidate _candidate({
  int id = 1,
  String title = 'Traffic jam',
  required double meters,
  double titleScore = 0,
  DateTime? createdAt,
}) {
  return (
    report: _report(id: id, title: title, createdAt: createdAt),
    distanceMeters: meters,
    titleScore: titleScore,
  );
}

void main() {
  group('titleSimilarity', () {
    test('the same words score far higher than unrelated ones', () {
      final same = IncidentMatch.titleSimilarity(
        'Accident at Kanchpur Bridge',
        'Accident at Kanchpur Bridge',
      );
      final different = IncidentMatch.titleSimilarity(
        'Accident at Kanchpur Bridge',
        'Waterlogging in Mirpur 10',
      );

      expect(same, 1.0);
      expect(different, lessThan(IncidentMatch.strongTitleScore));
    });

    test('one title containing the other still reads as a strong match', () {
      final score = IncidentMatch.titleSimilarity(
        'Accident at Kanchpur Bridge',
        'Accident at Kanchpur Bridge, two lanes shut',
      );

      expect(score, greaterThanOrEqualTo(IncidentMatch.strongTitleScore));
    });

    test('shared filler words alone do not make a match', () {
      final score = IncidentMatch.titleSimilarity(
        'A fire in the market',
        'A protest on the highway',
      );

      expect(score, lessThan(IncidentMatch.strongTitleScore));
    });

    test('an empty title cannot match anything', () {
      expect(IncidentMatch.titleSimilarity('', 'Traffic jam'), 0);
    });
  });

  group('rank', () {
    test('distance outranks wording across bands', () {
      final ranked = IncidentMatch.rank([
        _candidate(id: 1, meters: 1500, titleScore: 1.0),
        _candidate(id: 2, meters: 100, titleScore: 0.0),
      ]);

      expect(ranked.first.report.reportId, 2);
    });

    test('wording decides inside one distance band', () {
      final ranked = IncidentMatch.rank([
        _candidate(id: 1, meters: 200, titleScore: 0.1),
        _candidate(id: 2, meters: 240, titleScore: 0.9),
      ]);

      expect(ranked.first.report.reportId, 2);
    });

    test('the newer report wins when distance and wording tie', () {
      final old = DateTime.now().toUtc().subtract(const Duration(days: 3));
      final fresh = DateTime.now().toUtc().subtract(const Duration(minutes: 5));

      final ranked = IncidentMatch.rank([
        _candidate(id: 1, meters: 100, titleScore: 0.5, createdAt: old),
        _candidate(id: 2, meters: 100, titleScore: 0.5, createdAt: fresh),
      ]);

      expect(ranked.first.report.reportId, 2);
    });

    test('leaves the caller\'s list alone', () {
      final input = [
        _candidate(id: 1, meters: 3000),
        _candidate(id: 2, meters: 50),
      ];

      IncidentMatch.rank(input);

      expect(input.first.report.reportId, 1);
    });
  });

  group('isRecentEnough', () {
    final now = DateTime.utc(2026, 8, 5, 12);

    test('accepts a report from inside the window', () {
      expect(
        IncidentMatch.isRecentEnough(
          now.subtract(const Duration(days: 14)),
          now: now,
        ),
        isTrue,
      );
    });

    test('rejects one past the window', () {
      expect(
        IncidentMatch.isRecentEnough(
          now.subtract(const Duration(days: 16)),
          now: now,
        ),
        isFalse,
      );
    });

    test('keeps a report whose date could not be read', () {
      expect(IncidentMatch.isRecentEnough(null, now: now), isTrue);
    });
  });
}
