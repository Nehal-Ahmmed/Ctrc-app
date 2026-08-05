import '../../../../core/utils/app_time.dart';

class CommentModel {
  final int commentId;
  final int userId;
  final int? reportId;
  final int? subReportId;
  final String content;
  final DateTime? createdAt;
  final String? userName;
  final String? userImageUrl;

  final int upvoteCount;
  final int downvoteCount;

  final String? userVoteType;

  const CommentModel({
    required this.commentId,
    required this.userId,
    this.reportId,
    this.subReportId,
    required this.content,
    this.createdAt,
    this.userName,
    this.userImageUrl,
    this.upvoteCount = 0,
    this.downvoteCount = 0,
    this.userVoteType,
  });

  int get score => upvoteCount - downvoteCount;

  CommentModel copyWith({
    int? upvoteCount,
    int? downvoteCount,
    String? userVoteType,
    
    bool clearUserVoteType = false,
  }) {
    return CommentModel(
      commentId: commentId,
      userId: userId,
      reportId: reportId,
      subReportId: subReportId,
      content: content,
      createdAt: createdAt,
      userName: userName,
      userImageUrl: userImageUrl,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      downvoteCount: downvoteCount ?? this.downvoteCount,
      userVoteType:
          clearUserVoteType ? null : (userVoteType ?? this.userVoteType),
    );
  }

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      commentId: _asInt(json['commentId'] ?? json['comment_id']) ?? 0,
      userId: _asInt(json['userId'] ?? json['user_id']) ?? 0,
      reportId: _asInt(json['reportId'] ?? json['report_id']),
      subReportId: _asInt(json['subReportId'] ?? json['sub_report_id']),
      content: (json['content'] as String?) ?? '',
      createdAt: AppTime.parseTimestamp(json['createdAt'] ?? json['created_at']),
      userName: (json['userName'] ?? json['user_name']) as String?,
      userImageUrl: (json['userImageUrl'] ?? json['user_image_url']) as String?,
      upvoteCount: _asInt(json['upvoteCount'] ?? json['upvote_count']) ?? 0,
      downvoteCount:
          _asInt(json['downvoteCount'] ?? json['downvote_count']) ?? 0,
      userVoteType: (json['userVoteType'] ?? json['user_vote_type']) as String?,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}
