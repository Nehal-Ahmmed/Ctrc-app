import '../../../Report/domain/models/report_category.dart';

/// An incident that showed up near the user and has not been acknowledged yet.
///
/// These are produced locally from the nearby-reports feed rather than pushed
/// from a server, so no FCM setup is required for them to work.
class AppNotification {
  final int reportId;
  final String title;
  final String category;
  final String? description;

  /// How far the incident was from the user when it was first seen.
  final double? distanceMeters;

  /// When the app noticed it (not when the report was filed).
  final DateTime receivedAt;
  final bool isRead;

  const AppNotification({
    required this.reportId,
    required this.title,
    required this.category,
    this.description,
    this.distanceMeters,
    required this.receivedAt,
    this.isRead = false,
  });

  ReportCategory get categoryInfo => ReportCategory.fromLabel(category);

  AppNotification copyWith({bool? isRead}) => AppNotification(
        reportId: reportId,
        title: title,
        category: category,
        description: description,
        distanceMeters: distanceMeters,
        receivedAt: receivedAt,
        isRead: isRead ?? this.isRead,
      );

  Map<String, dynamic> toJson() => {
        'reportId': reportId,
        'title': title,
        'category': category,
        'description': description,
        'distanceMeters': distanceMeters,
        'receivedAt': receivedAt.toIso8601String(),
        'isRead': isRead,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      reportId: (json['reportId'] as num).toInt(),
      title: json['title'] as String? ?? 'Incident nearby',
      category: json['category'] as String? ?? 'Other',
      description: json['description'] as String?,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      receivedAt:
          DateTime.tryParse(json['receivedAt'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}
