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
  final String mode;

  Chapter({
    required this.id,
    required this.chapterNumber,
    required this.content,
    this.chosenDirection,
    required this.options,
    this.mode = 'normal',
  });

  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
        id: j['id'].toString(),
        chapterNumber: j['chapter_number'] as int,
        content: j['content'] as String,
        chosenDirection: j['chosen_direction'] as String?,
        options: ((j['options'] as List?) ?? [])
            .map((o) => ChapterOption.fromJson(o as Map<String, dynamic>))
            .toList(),
        mode: (j['mode'] as String?) ?? 'normal',
      );
}

// Một chiêu thức trong kho của nhân vật
class Skill {
  final String id;
  final String name;
  final String? description;
  final String source; // 'initial' | 'learned'
  Skill({
    required this.id,
    required this.name,
    this.description,
    this.source = 'initial',
  });

  factory Skill.fromJson(Map<String, dynamic> j) => Skill(
        id: j['id'].toString(),
        name: j['name'] as String,
        description: j['description'] as String?,
        source: (j['source'] as String?) ?? 'initial',
      );
}

// Một lựa chọn tại nút thắt (khi chơi)
class PlotChoiceLive {
  final String id;
  final String label;
  PlotChoiceLive({required this.id, required this.label});
  factory PlotChoiceLive.fromJson(Map<String, dynamic> j) => PlotChoiceLive(
        id: j['id'].toString(),
        label: (j['label'] ?? '').toString(),
      );
}

// Nút thắt đang diễn ra (khi chơi tới)
class PlotPointLive {
  final String id;
  final String title;
  final String? description;
  final List<PlotChoiceLive> choices;
  PlotPointLive({
    required this.id,
    required this.title,
    this.description,
    this.choices = const [],
  });
  factory PlotPointLive.fromJson(Map<String, dynamic> j) => PlotPointLive(
        id: j['id'].toString(),
        title: (j['title'] ?? '').toString(),
        description: j['description'] as String?,
        choices: ((j['choices'] as List?) ?? [])
            .map((c) => PlotChoiceLive.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

// Kết quả trả về sau mỗi lần sinh chương (chương + trạng thái chiến đấu + kho chiêu + nút thắt)
class ChapterResult {
  final Chapter chapter;
  final String mode; // 'normal' | 'combat'
  final String combatInfo;
  final List<Skill> skills;
  final bool atPlotPoint;
  final PlotPointLive? plotPoint;

  ChapterResult({
    required this.chapter,
    this.mode = 'normal',
    this.combatInfo = '',
    this.skills = const [],
    this.atPlotPoint = false,
    this.plotPoint,
  });

  bool get isCombat => mode == 'combat';
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