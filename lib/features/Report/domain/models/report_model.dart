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
