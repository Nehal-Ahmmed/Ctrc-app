class VoterModel {
  final int userId;
  final String userName;
  final String? userImageUrl;
  final String voteType; // 'up' or 'down'

  const VoterModel({
    required this.userId,
    required this.userName,
    this.userImageUrl,
    required this.voteType,
  });

  factory VoterModel.fromJson(Map<String, dynamic> json) {
    return VoterModel(
      userId: _asInt(json['userId'] ?? json['user_id']) ?? 0,
      userName: (json['userName'] ?? json['user_name'] ?? 'User') as String,
      userImageUrl: json['userImageUrl'] ?? json['user_image_url'] as String?,
      voteType: (json['voteType'] ?? json['vote_type'] ?? 'up') as String,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}
