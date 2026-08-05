import '../../../../core/utils/app_time.dart';
import '../../../Report/domain/models/report_model.dart';
import '../models/route_models.dart';

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
    
    if (level == CongestionLevel.blocked && net < 0) return CongestionLevel.slow;
    if (level == CongestionLevel.slow && net >= 20) {
      return CongestionLevel.blocked;
    }
    return level;
  }

  static bool isActive(ReportModel report) {
    final raw = report.expiresAt;
    if (raw == null || raw.isEmpty) return true;
    final parsed = AppTime.parseTimestamp(raw);
    if (parsed == null) return true;
    return parsed.isAfter(DateTime.now().toUtc());
  }
}
