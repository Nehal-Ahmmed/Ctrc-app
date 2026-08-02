import 'package:json_annotation/json_annotation.dart';

import 'sub_report_model.dart';

part 'report_model.g.dart';

@JsonSerializable(explicitToJson: true)
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
      subReportCount: subReportCount ?? this.subReportCount,
      subReports: subReports ?? this.subReports,
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
