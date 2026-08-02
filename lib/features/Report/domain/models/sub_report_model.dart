import 'comment_model.dart';
import 'report_model.dart';

/// An update filed against an existing incident.
///
/// This is the read side of the "link to an existing incident" flow: choosing
/// to link creates a `sub_report` row, and these are what the detail page
/// renders underneath the parent report.
///
/// Hand-written rather than generated for the same reason as [CommentModel] —
/// timestamps arrive as either epoch millis or an ISO string.
class SubReportModel {
  final int subReportId;
  final int userId;

  /// The incident this update belongs to.
  final int reportId;
  final String? description;

  /// How this reporter knew: `seen`, `heard` or `guessed`.
  final String evidenceType;

  /// What this reporter thinks the incident is. When somebody who actually
  /// saw it files an update, a database trigger copies this onto a parent
  /// still sitting at `Unknown`.
  final String? category;

  /// Photo attached to this update, hosted on Cloudinary.
  final String? imageUrl;

  /// Straight-line distance from the parent report, computed by MySQL with
  /// `ST_Distance_Sphere` when the row is inserted.
  final double? distFromParent;

  final int upvoteCount;
  final int downvoteCount;
  final int commentCount;
  final DateTime? createdAt;

  final String? authorName;
  final String? authorImageUrl;
  final LocationModel? location;

  const SubReportModel({
    required this.subReportId,
    required this.userId,
    required this.reportId,
    this.description,
    this.evidenceType = 'heard',
    this.category,
    this.imageUrl,
    this.distFromParent,
    this.upvoteCount = 0,
    this.downvoteCount = 0,
    this.commentCount = 0,
    this.createdAt,
    this.authorName,
    this.authorImageUrl,
    this.location,
  });

  factory SubReportModel.fromJson(Map<String, dynamic> json) {
    return SubReportModel(
      subReportId: _asInt(json['subReportId'] ?? json['sub_report_id']) ?? 0,
      userId: _asInt(json['userId'] ?? json['user_id']) ?? 0,
      reportId: _asInt(json['reportId'] ?? json['report_id']) ?? 0,
      description: json['description'] as String?,
      evidenceType:
          (json['evidenceType'] ?? json['evidence_type']) as String? ?? 'heard',
      category: json['category'] as String?,
      imageUrl: (json['imageUrl'] ?? json['image_url']) as String?,
      distFromParent:
          _asDouble(json['distFromParent'] ?? json['dist_from_parent']),
      upvoteCount: _asInt(json['upvoteCount'] ?? json['upvote_count']) ?? 0,
      downvoteCount:
          _asInt(json['downvoteCount'] ?? json['downvote_count']) ?? 0,
      commentCount: _asInt(json['commentCount'] ?? json['comment_count']) ?? 0,
      createdAt: CommentModel.parseTimestamp(
        json['createdAt'] ?? json['created_at'],
      ),
      authorName: (json['authorName'] ?? json['author_name']) as String?,
      authorImageUrl:
          (json['authorImageUrl'] ?? json['author_image_url']) as String?,
      location: json['location'] is Map
          ? LocationModel.fromJson(
              Map<String, dynamic>.from(json['location'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'subReportId': subReportId,
        'userId': userId,
        'reportId': reportId,
        'description': description,
        'evidenceType': evidenceType,
        'category': category,
        'imageUrl': imageUrl,
        'distFromParent': distFromParent,
        'upvoteCount': upvoteCount,
        'downvoteCount': downvoteCount,
        'commentCount': commentCount,
        'createdAt': createdAt?.toIso8601String(),
        'authorName': authorName,
        'authorImageUrl': authorImageUrl,
        'location': location?.toJson(),
      };

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }
}
