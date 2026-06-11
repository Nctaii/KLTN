// Model cho comment và thông tin like
class ScenarioComment {
  final String id;
  final String content;
  final String authorName;
  final String? authorAvatar;
  final DateTime createdAt;

  ScenarioComment({
    required this.id,
    required this.content,
    required this.authorName,
    this.authorAvatar,
    required this.createdAt,
  });

  factory ScenarioComment.fromJson(Map<String, dynamic> j) => ScenarioComment(
        id: j['id'].toString(),
        content: j['content'] as String,
        authorName: (j['author_name'] ?? 'Ẩn danh') as String,
        authorAvatar: j['author_avatar'] as String?,
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class LikeInfo {
  final int likeCount;
  final bool likedByMe;
  LikeInfo({required this.likeCount, required this.likedByMe});

  factory LikeInfo.fromJson(Map<String, dynamic> j) => LikeInfo(
        likeCount: (j['likeCount'] ?? 0) as int,
        likedByMe: (j['likedByMe'] ?? false) as bool,
      );
}