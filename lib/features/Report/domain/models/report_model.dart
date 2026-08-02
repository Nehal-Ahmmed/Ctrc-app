import 'comment_model.dart';
import 'sub_report_model.dart';

/// A report as the feed and the detail page read it.
///
/// Hand-written rather than generated, for the same reason as [CommentModel]
/// and [SubReportModel]: the timestamps arrive as either epoch millis or an
/// ISO-8601 string depending on how the backend serialises them, and generated
/// code would cast them straight to `String` and throw on the numeric form.
class ReportModel {
  final int reportId;
  final int userId;
  final int locationId;
  final String title;
  final String? description;
  final String category;

  /// How the reporter knew about the incident: `seen`, `heard` or `guessed`.
  /// Weaker evidence needs more upvotes before the report counts as verified.
  final String evidenceType;

  /// `unverified`, `verified` or `disputed`. Worked out by a database trigger
  /// every time a vote lands, never set by the app.
  final String status;

  /// Photo of the incident, hosted on Cloudinary. Null when the reporter did
  /// not attach one.
  final String? imageUrl;

  final int upvoteCount;
  final int downvoteCount;
  final int commentCount;
  final String? expiresAt;
  final String? createdAt;

  /// Null until the author edits the report, which is what the "edited" mark
  /// on a card is reading.
  final String? updatedAt;

  final bool isSaved;
  final String? userVoteType;

  /// Reporter's display name / avatar, joined server side so a report can be
  /// rendered without a second lookup.
  final String? authorName;
  final String? authorImageUrl;
  final LocationModel? location;

  /// How many updates were linked to this incident. Returned by every list
  /// read so a card can show the badge without loading the thread.
  final int subReportCount;

  /// The updates themselves. Only the single-report endpoint fills this in;
  /// elsewhere it is empty and [subReportCount] is the thing to trust.
  final List<SubReportModel> subReports;

  ReportModel({
    required this.reportId,
    required this.userId,
    required this.locationId,
    required this.title,
    this.description,
    required this.category,
    this.evidenceType = 'seen',
    this.status = 'unverified',
    this.imageUrl,
    this.upvoteCount = 0,
    this.downvoteCount = 0,
    this.commentCount = 0,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
    this.isSaved = false,
    this.userVoteType,
    this.authorName,
    this.authorImageUrl,
    this.location,
    this.subReportCount = 0,
    this.subReports = const [],
  });

  /// Total voices on this incident: the original report plus every linked
  /// update. What the UI means by "3 people reported this".
  int get incidentSize => 1 + (subReports.isNotEmpty
      ? subReports.length
      : subReportCount);

  ReportModel copyWith({
    int? reportId,
    int? userId,
    int? locationId,
    String? title,
    String? description,
    String? category,
    String? evidenceType,
    String? status,
    String? imageUrl,
    int? upvoteCount,
    int? downvoteCount,
    int? commentCount,
    String? expiresAt,
    String? createdAt,
    String? updatedAt,
    bool? isSaved,
    String? userVoteType,
    // `userVoteType: null` cannot express "clear the vote" because null also
    // means "leave unchanged", so un-voting sets this flag instead.
    bool clearUserVoteType = false,
    String? authorName,
    String? authorImageUrl,
    LocationModel? location,
    int? subReportCount,
    List<SubReportModel>? subReports,
  }) {
    return ReportModel(
      reportId: reportId ?? this.reportId,
      userId: userId ?? this.userId,
      locationId: locationId ?? this.locationId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      evidenceType: evidenceType ?? this.evidenceType,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      downvoteCount: downvoteCount ?? this.downvoteCount,
      commentCount: commentCount ?? this.commentCount,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSaved: isSaved ?? this.isSaved,
      userVoteType:
          clearUserVoteType ? null : (userVoteType ?? this.userVoteType),
      authorName: authorName ?? this.authorName,
      authorImageUrl: authorImageUrl ?? this.authorImageUrl,
      location: location ?? this.location,
      subReportCount: subReportCount ?? this.subReportCount,
      subReports: subReports ?? this.subReports,
    );
  }

  /// The same incident with everything that belonged to the previous viewer
  /// stripped off.
  ///
  /// Saves and votes are per-account, so a cached card must forget them the
  /// moment the signed-in identity changes — otherwise one person's bookmark
  /// stays lit under the next person's session, or under no session at all.
  ReportModel withoutViewerState() =>
      copyWith(isSaved: false, clearUserVoteType: true);

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      reportId: _asInt(json['reportId'] ?? json['report_id']) ?? 0,
      userId: _asInt(json['userId'] ?? json['user_id']) ?? 0,
      locationId: _asInt(json['locationId'] ?? json['location_id']) ?? 0,
      title: (json['title'] as String?) ?? '',
      description: json['description'] as String?,
      category: (json['category'] as String?) ?? 'Unknown',
      evidenceType:
          (json['evidenceType'] ?? json['evidence_type']) as String? ?? 'seen',
      status: (json['status'] as String?) ?? 'unverified',
      imageUrl: (json['imageUrl'] ?? json['image_url']) as String?,
      upvoteCount: _asInt(json['upvoteCount'] ?? json['upvote_count']) ?? 0,
      downvoteCount:
          _asInt(json['downvoteCount'] ?? json['downvote_count']) ?? 0,
      commentCount: _asInt(json['commentCount'] ?? json['comment_count']) ?? 0,
      expiresAt: _asTimestamp(json['expiresAt'] ?? json['expires_at']),
      createdAt: _asTimestamp(json['createdAt'] ?? json['created_at']),
      updatedAt: _asTimestamp(json['updatedAt'] ?? json['updated_at']),
      isSaved: (json['isSaved'] ?? json['is_saved']) == true,
      userVoteType: (json['userVoteType'] ?? json['user_vote_type']) as String?,
      authorName: (json['authorName'] ?? json['author_name']) as String?,
      authorImageUrl:
          (json['authorImageUrl'] ?? json['author_image_url']) as String?,
      location: json['location'] is Map
          ? LocationModel.fromJson(
              Map<String, dynamic>.from(json['location'] as Map),
            )
          : null,
      subReportCount:
          _asInt(json['subReportCount'] ?? json['sub_report_count']) ?? 0,
      subReports: _asSubReports(json['subReports'] ?? json['sub_reports']),
    );
  }

  Map<String, dynamic> toJson() => {
        'reportId': reportId,
        'userId': userId,
        'locationId': locationId,
        'title': title,
        'description': description,
        'category': category,
        'evidenceType': evidenceType,
        'status': status,
        'imageUrl': imageUrl,
        'upvoteCount': upvoteCount,
        'downvoteCount': downvoteCount,
        'commentCount': commentCount,
        'expiresAt': expiresAt,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'isSaved': isSaved,
        'userVoteType': userVoteType,
        'authorName': authorName,
        'authorImageUrl': authorImageUrl,
        'location': location?.toJson(),
        'subReportCount': subReportCount,
        'subReports': subReports.map((sub) => sub.toJson()).toList(),
      };

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  /// Timestamps stay strings on this model, but everything downstream reads
  /// them with `DateTime.tryParse`, so an epoch number is normalised to ISO
  /// here instead of being stringified into something unparseable.
  ///
  /// The epoch form is written back out in UTC, so it carries a `Z`. That
  /// keeps one rule for every reader: a timestamp with no zone on it came
  /// straight from the backend's `LocalDateTime` and is therefore server time.
  static String? _asTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    return CommentModel.parseTimestamp(value)?.toUtc().toIso8601String();
  }

  static List<SubReportModel> _asSubReports(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((sub) =>
            SubReportModel.fromJson(Map<String, dynamic>.from(sub)))
        .toList();
  }
}

class LocationModel {
  final int locationId;
  final double longitude;
  final double latitude;
  final String? address;
  final String? city;

  LocationModel({
    required this.locationId,
    required this.longitude,
    required this.latitude,
    this.address,
    this.city,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      locationId:
          ReportModel._asInt(json['locationId'] ?? json['location_id']) ?? 0,
      longitude: _asDouble(json['longitude']) ?? 0,
      latitude: _asDouble(json['latitude']) ?? 0,
      address: json['address'] as String?,
      city: json['city'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'locationId': locationId,
        'longitude': longitude,
        'latitude': latitude,
        'address': address,
        'city': city,
      };

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }
}
