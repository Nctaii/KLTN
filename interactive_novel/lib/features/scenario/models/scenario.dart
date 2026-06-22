// Model cho scenario và các phần cấu hình con

class KeyCharacter {
  final String name;
  final String role;
  final String? description;
  KeyCharacter({required this.name, required this.role, this.description});

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role,
        if (description != null) 'description': description,
      };
}

class Realm {
  final String name;
  final int tier;
  final String? description;
  Realm({required this.name, required this.tier, this.description});

  Map<String, dynamic> toJson() => {
        'name': name,
        'tier': tier,
        if (description != null) 'description': description,
      };
}

// Tông môn (chính phái / tà phái)
class Sect {
  final String name;
  final String faction; // 'chinh' hoặc 'ta'
  final String? description;
  final String? standing;
  Sect({
    required this.name,
    this.faction = 'chinh',
    this.description,
    this.standing,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'faction': faction,
        if (description != null) 'description': description,
        if (standing != null) 'standing': standing,
      };
}

// Công pháp đặc trưng
class Technique {
  final String name;
  final String? description;
  final String? specialty;
  Technique({required this.name, this.description, this.specialty});

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        if (specialty != null) 'specialty': specialty,
      };
}

// Một lựa chọn tại nút thắt
class PlotChoice {
  final String label;
  final String? branchHint;
  PlotChoice({required this.label, this.branchHint});

  Map<String, dynamic> toJson() => {
        'label': label,
        if (branchHint != null) 'branch_hint': branchHint,
      };
}

// Nút thắt cốt truyện
class PlotPoint {
  final String title;
  final String? description;
  final int minChapters;
  final List<PlotChoice> choices;
  PlotPoint({
    required this.title,
    this.description,
    this.minChapters = 2,
    this.choices = const [],
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        if (description != null) 'description': description,
        'min_chapters': minChapters,
        'choices': choices.map((c) => c.toJson()).toList(),
      };
}

// Dữ liệu nút thắt dạng mutable, mang id (truyền giữa màn tạo/sửa và trang quản lý nút thắt)
class PlotPointData {
  int? id;
  String title;
  String description;
  int minChapters;
  List<PlotChoiceData> choices;
  PlotPointData({
    this.id,
    this.title = '',
    this.description = '',
    this.minChapters = 2,
    List<PlotChoiceData>? choices,
  }) : choices = choices ?? [];
}

class PlotChoiceData {
  int? id;
  String label;
  PlotChoiceData({this.id, this.label = ''});
}

class ScenarioInput {
  String title;
  String description;
  List<int> genreIds;
  String worldSetting;
  String protagonistRole;
  String defaultMcName;
  String enemyDescription;
  String finalGoal;
  List<KeyCharacter> keyCharacters;
  List<String> personalities; // tính cách cho người chơi chọn (mọi thể loại)
  String cultivationNote; // chỉ dùng nếu có tiên hiệp
  List<Realm> realms; // chỉ dùng nếu có tiên hiệp
  String mcSpiritRoot; // tiên hiệp: linh căn/thể chất NV chính
  List<Sect> sects; // tiên hiệp: tông môn chính phái + tà phái
  List<Technique> techniques; // tiên hiệp: công pháp đặc trưng
  String magicSystem; // Fantasy
  List<String> classes; // Fantasy: tên các lớp
  List<String> races; // Fantasy: tên các chủng tộc
  List<PlotPoint> plotPoints; // nút thắt cốt truyện (mọi thể loại)

  ScenarioInput({
    this.title = '',
    this.description = '',
    this.genreIds = const [],
    this.worldSetting = '',
    this.protagonistRole = '',
    this.defaultMcName = '',
    this.enemyDescription = '',
    this.finalGoal = '',
    this.keyCharacters = const [],
    this.personalities = const [],
    this.cultivationNote = '',
    this.realms = const [],
    this.mcSpiritRoot = '',
    this.sects = const [],
    this.techniques = const [],
    this.magicSystem = '',
    this.classes = const [],
    this.races = const [],
    this.plotPoints = const [],
  });

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'genre_ids': genreIds,
      'world': {
        'world_setting': worldSetting,
        'protagonist_role': protagonistRole,
        'default_mc_name': defaultMcName,
        'enemy_description': enemyDescription,
        'final_goal': finalGoal,
      },
      'key_characters': keyCharacters.map((c) => c.toJson()).toList(),
      // Tính cách: gửi danh sách {name} (bỏ tên rỗng)
      'personalities': personalities
          .where((p) => p.trim().isNotEmpty)
          .map((p) => {'name': p.trim()})
          .toList(),
      // Nút thắt cốt truyện (mọi thể loại)
      'plot_points': plotPoints.map((pp) => pp.toJson()).toList(),
    };

    // Phần Fantasy nếu chọn thể loại Fantasy (genre_id = 2)
    if (genreIds.contains(2)) {
      body['fnt'] = {
        'magic_system': magicSystem,
        'has_mana': true,
        'classes': classes.map((c) => {'name': c}).toList(),
        'races': races.map((r) => {'name': r}).toList(),
      };
    }

    if (genreIds.contains(1)) {
      body['xh'] = {
        'cultivation_note': cultivationNote,
        'mc_spirit_root': mcSpiritRoot,
        'realms': realms.map((r) => r.toJson()).toList(),
        'sects': sects.map((s) => s.toJson()).toList(),
        'techniques': techniques.map((t) => t.toJson()).toList(),
      };
    }
    return body;
  }
}

// Model scenario tóm tắt (cho danh sách)
// Model scenario tóm tắt (cho danh sách + card)
class ScenarioSummary {
  final String id;
  final String title;
  final String? description;
  final int playCount;
  final int likeCount;
  final int commentCount;
  final String? coverUrl;
  final List<String> genres;

  ScenarioSummary({
    required this.id,
    required this.title,
    this.description,
    required this.playCount,
    this.likeCount = 0,
    this.commentCount = 0,
    this.coverUrl,
    required this.genres,
  });

  factory ScenarioSummary.fromJson(Map<String, dynamic> json) =>
      ScenarioSummary(
        id: json['id'].toString(),
        title: json['title'] as String,
        description: json['description'] as String?,
        playCount: _toInt(json['play_count']),
        likeCount: _toInt(json['like_count']),
        commentCount: _toInt(json['comment_count']),
        coverUrl: json['cover_url'] as String?,
        genres: (json['genres'] as List?)
                ?.where((g) => g != null)
                .map((g) => g.toString())
                .toList() ??
            [],
      );
  // Chuyển giá trị JSON về int an toàn (chịu null, chuỗi, số)
  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}