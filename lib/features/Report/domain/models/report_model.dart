import 'comment_model.dart';
import '../../../../core/utils/app_time.dart';
import 'sub_report_model.dart';

class ReportModel {
  final int reportId;
  final int userId;
  final int locationId;
  final String title;
  final String? description;
  final String category;

  final String evidenceType;

  final String status;

  final String? imageUrl;

  final int upvoteCount;
  final int downvoteCount;
  final int commentCount;
  final String? expiresAt;
  final String? createdAt;

  final String? updatedAt;

  final bool isSaved;
  final String? userVoteType;

  final String? authorName;
  final String? authorImageUrl;
  final LocationModel? location;

  final int subReportCount;

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

  static String? _asTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isEmpty) return null;
    return AppTime.parseTimestamp(value)?.toIso8601String();
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
