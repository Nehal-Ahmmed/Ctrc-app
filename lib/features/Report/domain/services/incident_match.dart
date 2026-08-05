library;

import '../../../../core/utils/app_time.dart';
import '../models/report_model.dart';

const Duration kLinkMaxAge = Duration(days: 15);

int get kLinkMaxAgeHours => kLinkMaxAge.inHours;

typedef IncidentCandidate = ({
  ReportModel report,
  double distanceMeters,

  double titleScore,
});

class IncidentMatch {
  IncidentMatch._();

  static const List<double> _bandEdges = [250, 750, 2000];

  static const double strongTitleScore = 0.45;

  static int bandOf(double meters) {
    for (var i = 0; i < _bandEdges.length; i++) {
      if (meters <= _bandEdges[i]) return i;
    }
    return _bandEdges.length;
  }

  static const Set<String> _stopWords = {
    'a', 'an', 'and', 'are', 'as', 'at', 'be', 'been', 'by', 'for', 'from',
    'has', 'have', 'in', 'is', 'it', 'its', 'near', 'of', 'on', 'onto', 'or',
    'that', 'the', 'there', 'this', 'to', 'was', 'were', 'with',
  };

  static double titleSimilarity(String a, String b) {
    final left = _tokenise(a);
    final right = _tokenise(b);
    if (left.isEmpty || right.isEmpty) return 0;

    final shared = left.intersection(right).length;
    final dice = (2 * shared) / (left.length + right.length);

    final normalisedA = _normalise(a);
    final normalisedB = _normalise(b);
    final contained = normalisedA.isNotEmpty &&
        normalisedB.isNotEmpty &&
        (normalisedA.contains(normalisedB) || normalisedB.contains(normalisedA));

    return contained ? ((dice + 1) / 2).clamp(0.0, 1.0) : dice;
  }

  static String _normalise(String raw) => raw
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static Set<String> _tokenise(String raw) => _normalise(raw)
      .split(' ')
      .where((word) => word.length > 1 && !_stopWords.contains(word))
      .toSet();

  static bool isRecentEnough(DateTime? createdAt, {DateTime? now}) {
    if (createdAt == null) return true;
    final reference = (now ?? DateTime.now()).toUtc();
    return reference.difference(createdAt.toUtc()) <= kLinkMaxAge;
  }

  static List<IncidentCandidate> rank(List<IncidentCandidate> candidates) {
    final ranked = [...candidates];

    ranked.sort((a, b) {
      final band = bandOf(a.distanceMeters).compareTo(bandOf(b.distanceMeters));
      if (band != 0) return band;

      final title = b.titleScore.compareTo(a.titleScore);
      if (title != 0) return title;

      final newest = _createdAt(b.report).compareTo(_createdAt(a.report));
      if (newest != 0) return newest;

      return a.distanceMeters.compareTo(b.distanceMeters);
    });

    return ranked;
  }

  static DateTime _createdAt(ReportModel report) {
    return AppTime.parseTimestamp(report.createdAt) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
