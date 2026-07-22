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
    this.expiresAt,
    this.createdAt,
    this.location,
  });

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
