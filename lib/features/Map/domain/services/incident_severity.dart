import '../../../Report/domain/models/report_model.dart';
import '../models/route_models.dart';

/// Maps an incident report onto a road-condition level.
///
/// Categories are matched loosely because reports come from several places in
/// the app (feed picker, create sheet, seeded data) with slightly different
/// wording.
class IncidentSeverity {
  IncidentSeverity._();

  static const _blocking = [
    'road block',
    'roadblock',
    'block',
    'closed',
    'closure',
    'riot',
    'protest',
    'fire',
    'accident',
    'crash',
    'collapse',
    'landslide',
  ];

  static const _slowing = [
    'traffic',
    'jam',
    'congest',
    'waterlog',
    'flood',
    'weather',
    'road condition',
    'road hazard',
    'pothole',
    'construction',
    'repair',
    'robbery',
    'theft',
    'crime',
  ];

  /// Net community confidence in the report.
  static int score(ReportModel report) =>
      report.upvoteCount - report.downvoteCount;

  static CongestionLevel of(ReportModel report) {
    final haystack =
        '${report.category} ${report.title}'.toLowerCase();

    var level = CongestionLevel.slow;
    if (_blocking.any(haystack.contains)) {
      level = CongestionLevel.blocked;
    } else if (_slowing.any(haystack.contains)) {
      level = CongestionLevel.slow;
    }

    final net = score(report);
    // Strongly disputed blockages soften to a caution; heavily confirmed
    // slowdowns harden into a blockage.
    if (level == CongestionLevel.blocked && net < 0) return CongestionLevel.slow;
    if (level == CongestionLevel.slow && net >= 20) {
      return CongestionLevel.blocked;
    }
    return level;
  }

  /// Reports whose `expiresAt` is in the past no longer affect the road.
  ///
  /// The backend sends a `LocalDateTime`, so the string carries no timezone.
  /// `DateTime.parse` would read that as the phone's own clock, which is six
  /// hours ahead of the server here — long enough that a report filed a minute
  /// ago looked expired and dropped straight off the map. The server runs on
  /// UTC, so a bare timestamp is read as UTC.
  static bool isActive(ReportModel report) {
    final raw = report.expiresAt;
    if (raw == null || raw.isEmpty) return true;
    final parsed = DateTime.tryParse(_asUtc(raw));
    if (parsed == null) return true;
    return parsed.isAfter(DateTime.now().toUtc());
  }

  static final _hasTimezone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

  static String _asUtc(String raw) =>
      _hasTimezone.hasMatch(raw) ? raw : '${raw}Z';
}
