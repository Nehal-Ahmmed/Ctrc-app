/// A comment on a report.
///
/// Written by hand rather than generated because the backend serialises
/// `created_at` as a `java.sql.Timestamp`, which Jackson may emit either as
/// epoch millis or as an ISO string depending on configuration.
class CommentModel {
  final int commentId;
  final int userId;
  final int? reportId;
  final int? subReportId;
  final String content;
  final DateTime? createdAt;
  final String? userName;
  final String? userImageUrl;

  const CommentModel({
    required this.commentId,
    required this.userId,
    this.reportId,
    this.subReportId,
    required this.content,
    this.createdAt,
    this.userName,
    this.userImageUrl,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      commentId: _asInt(json['commentId'] ?? json['comment_id']) ?? 0,
      userId: _asInt(json['userId'] ?? json['user_id']) ?? 0,
      reportId: _asInt(json['reportId'] ?? json['report_id']),
      subReportId: _asInt(json['subReportId'] ?? json['sub_report_id']),
      content: (json['content'] as String?) ?? '',
      createdAt: parseTimestamp(json['createdAt'] ?? json['created_at']),
      userName: (json['userName'] ?? json['user_name']) as String?,
      userImageUrl: (json['userImageUrl'] ?? json['user_image_url']) as String?,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  /// Accepts epoch millis, epoch seconds or an ISO-8601 string.
  static DateTime? parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      final asInt = value.toInt();
      // Anything below this is far more likely to be seconds than millis.
      return asInt < 100000000000
          ? DateTime.fromMillisecondsSinceEpoch(asInt * 1000)
          : DateTime.fromMillisecondsSinceEpoch(asInt);
    }
    return DateTime.tryParse('$value');
  }
}

/// "just now" / "5 m ago" / "3 d ago" style formatting used by the report UI.
String formatRelativeTime(DateTime? time) {
  if (time == null) return '';
  final diff = DateTime.now().difference(time);
  if (diff.isNegative) return 'just now';
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 30) return '${diff.inDays} d ago';
  return '${time.day}/${time.month}/${time.year}';
}
