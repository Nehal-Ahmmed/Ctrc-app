import 'package:json_annotation/json_annotation.dart';

part 'report_model.g.dart';

@JsonSerializable(explicitToJson: true)
class ReportModel {
  final int reportId;
  final int userId;
  final int locationId;
  final String title;
  final String? description;
  final String category;
  final int upvoteCount;
  final int downvoteCount;
  final int commentCount;
  final String? expiresAt;
  final String? createdAt;
  final bool isSaved;
  final String? userVoteType;

  /// Reporter's display name / avatar, joined server side so a report can be
  /// rendered without a second lookup.
  final String? authorName;
  final String? authorImageUrl;
  final LocationModel? location;

  ReportModel({
    required this.reportId,
    required this.userId,
    required this.locationId,
    required this.title,
    this.description,
    required this.category,
    this.upvoteCount = 0,
    this.downvoteCount = 0,
    this.commentCount = 0,
    this.expiresAt,
    this.createdAt,
    this.isSaved = false,
    this.userVoteType,
    this.authorName,
    this.authorImageUrl,
    this.location,
  });

  ReportModel copyWith({
    int? reportId,
    int? userId,
    int? locationId,
    String? title,
    String? description,
    String? category,
    int? upvoteCount,
    int? downvoteCount,
    int? commentCount,
    String? expiresAt,
    String? createdAt,
    bool? isSaved,
    String? userVoteType,
    // `userVoteType: null` cannot express "clear the vote" because null also
    // means "leave unchanged", so un-voting sets this flag instead.
    bool clearUserVoteType = false,
    String? authorName,
    String? authorImageUrl,
    LocationModel? location,
  }) {
    return ReportModel(
      reportId: reportId ?? this.reportId,
      userId: userId ?? this.userId,
      locationId: locationId ?? this.locationId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      downvoteCount: downvoteCount ?? this.downvoteCount,
      commentCount: commentCount ?? this.commentCount,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      isSaved: isSaved ?? this.isSaved,
      userVoteType:
          clearUserVoteType ? null : (userVoteType ?? this.userVoteType),
      authorName: authorName ?? this.authorName,
      authorImageUrl: authorImageUrl ?? this.authorImageUrl,
      location: location ?? this.location,
    );
  }

  factory ReportModel.fromJson(Map<String, dynamic> json) => _$ReportModelFromJson(json);
  Map<String, dynamic> toJson() => _$ReportModelToJson(this);
}

@JsonSerializable()
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

  factory LocationModel.fromJson(Map<String, dynamic> json) => _$LocationModelFromJson(json);
  Map<String, dynamic> toJson() => _$LocationModelToJson(this);
}
