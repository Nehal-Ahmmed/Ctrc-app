// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReportModel _$ReportModelFromJson(Map<String, dynamic> json) => ReportModel(
  reportId: (json['reportId'] as num).toInt(),
  userId: (json['userId'] as num).toInt(),
  locationId: (json['locationId'] as num).toInt(),
  title: json['title'] as String,
  description: json['description'] as String?,
  category: json['category'] as String,
  upvoteCount: (json['upvoteCount'] as num?)?.toInt() ?? 0,
  downvoteCount: (json['downvoteCount'] as num?)?.toInt() ?? 0,
  commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
  expiresAt: json['expiresAt'] as String?,
  createdAt: json['createdAt'] as String?,
  isSaved: json['isSaved'] as bool? ?? false,
  userVoteType: json['userVoteType'] as String?,
  authorName: json['authorName'] as String?,
  authorImageUrl: json['authorImageUrl'] as String?,
  location: json['location'] == null
      ? null
      : LocationModel.fromJson(json['location'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ReportModelToJson(ReportModel instance) =>
    <String, dynamic>{
      'reportId': instance.reportId,
      'userId': instance.userId,
      'locationId': instance.locationId,
      'title': instance.title,
      'description': instance.description,
      'category': instance.category,
      'upvoteCount': instance.upvoteCount,
      'downvoteCount': instance.downvoteCount,
      'commentCount': instance.commentCount,
      'expiresAt': instance.expiresAt,
      'createdAt': instance.createdAt,
      'isSaved': instance.isSaved,
      'userVoteType': instance.userVoteType,
      'authorName': instance.authorName,
      'authorImageUrl': instance.authorImageUrl,
      'location': instance.location?.toJson(),
    };

LocationModel _$LocationModelFromJson(Map<String, dynamic> json) =>
    LocationModel(
      locationId: (json['locationId'] as num).toInt(),
      longitude: (json['longitude'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      address: json['address'] as String?,
      city: json['city'] as String?,
    );

Map<String, dynamic> _$LocationModelToJson(LocationModel instance) =>
    <String, dynamic>{
      'locationId': instance.locationId,
      'longitude': instance.longitude,
      'latitude': instance.latitude,
      'address': instance.address,
      'city': instance.city,
    };
