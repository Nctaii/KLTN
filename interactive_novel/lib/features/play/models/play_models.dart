// Model cho chương truyện và lựa chọn

class ChapterOption {
  final String id;
  final String label;
  ChapterOption({required this.id, required this.label});

  factory ChapterOption.fromJson(Map<String, dynamic> j) => ChapterOption(
        id: j['id'].toString(),
        label: j['label'] as String,
      );
}

class Chapter {
  final String id;
  final int chapterNumber;
  final String content;
  final String? chosenDirection;
  final List<ChapterOption> options;

  Chapter({
    required this.id,
    required this.chapterNumber,
    required this.content,
    this.chosenDirection,
    required this.options,
  });

  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
        id: j['id'].toString(),
        chapterNumber: j['chapter_number'] as int,
        content: j['content'] as String,
        chosenDirection: j['chosen_direction'] as String?,
        options: ((j['options'] as List?) ?? [])
            .map((o) => ChapterOption.fromJson(o as Map<String, dynamic>))
            .toList(),
      );
}

// Tóm tắt một lượt chơi (cho danh sách "đang chơi dở")
class PlaySessionSummary {
  final String sessionId;
  final String storyId;
  final String storyTitle;
  final String? mcName;
  final int chapterCount;

  PlaySessionSummary({
    required this.sessionId,
    required this.storyId,
    required this.storyTitle,
    this.mcName,
    required this.chapterCount,
  });

  factory PlaySessionSummary.fromJson(Map<String, dynamic> j) =>
      PlaySessionSummary(
        sessionId: j['session_id'].toString(),
        storyId: j['story_id'].toString(),
        storyTitle: j['story_title'] as String,
        mcName: j['mc_name'] as String?,
        chapterCount: int.tryParse(j['chapter_count'].toString()) ?? 0,
      );
}