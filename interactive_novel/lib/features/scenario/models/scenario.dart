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

// Dữ liệu form để gửi lên POST /scenarios
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
  String cultivationNote; // chỉ dùng nếu có tiên hiệp
  List<Realm> realms; // chỉ dùng nếu có tiên hiệp

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
    this.cultivationNote = '',
    this.realms = const [],
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
    };
    // Chỉ thêm phần tiên hiệp nếu thể loại tiên hiệp được chọn (genre_id = 1)
    if (genreIds.contains(1)) {
      body['xh'] = {
        'cultivation_note': cultivationNote,
        'realms': realms.map((r) => r.toJson()).toList(),
      };
    }
    return body;
  }
}

// Model scenario tóm tắt (cho danh sách)
class ScenarioSummary {
  final String id;
  final String title;
  final String? description;
  final int playCount;
  final List<String> genres;

  ScenarioSummary({
    required this.id,
    required this.title,
    this.description,
    required this.playCount,
    required this.genres,
  });

  factory ScenarioSummary.fromJson(Map<String, dynamic> json) =>
      ScenarioSummary(
        id: json['id'].toString(),
        title: json['title'] as String,
        description: json['description'] as String?,
        playCount: (json['play_count'] ?? 0) as int,
        genres: (json['genres'] as List?)
                ?.where((g) => g != null)
                .map((g) => g.toString())
                .toList() ??
            [],
      );
}