import 'package:dio/dio.dart';
import '../models/play_models.dart';

class PlayService {
  final Dio _dio;
  PlayService(this._dio);

  Map<String, dynamic> _ok(Response res) {
    final status = res.statusCode ?? 0;
    if (status >= 200 && status < 300) {
      return res.data as Map<String, dynamic>;
    }
    final data = res.data;
    final msg = (data is Map && data['error'] != null)
        ? data['error'].toString()
        : 'Có lỗi xảy ra (mã $status)';
    throw Exception(msg);
  }

  // Bắt đầu chơi -> trả về (sessionId, kết quả chương kèm trạng thái chiến đấu)
  Future<({String sessionId, ChapterResult result})> start(
      String storyId, String? mcName, [String? personality]) async {
    final res = await _dio.post('/play/start', data: {
      'story_id': storyId,
      if (mcName != null && mcName.isNotEmpty) 'mc_name': mcName,
      if (personality != null && personality.isNotEmpty)
        'personality': personality,
    });
    final data = _ok(res);
    return (
      sessionId: data['session_id'].toString(),
      result: _parseResult(data),
    );
  }

  // Chơi tiếp: chọn option, tự viết hướng đi, hoặc chọn chiêu (khi chiến đấu)
  Future<ChapterResult> continuePlay(
      String sessionId,
      {String? optionId, String? customDirection, String? skillName, String? plotChoiceId}) async {
    final res = await _dio.post('/play/$sessionId/continue', data: {
      if (optionId != null) 'option_id': optionId,
      if (customDirection != null) 'custom_direction': customDirection,
      if (skillName != null) 'skill_name': skillName,
      if (plotChoiceId != null) 'plot_choice_id': plotChoiceId,
    });
    final data = _ok(res);
    return _parseResult(data);
  }

  // Bóc tách kết quả chung (chương + mode + combat_info + skills + nút thắt)
  ChapterResult _parseResult(Map<String, dynamic> data) {
    return ChapterResult(
      chapter: Chapter.fromJson(data['chapter']),
      mode: (data['mode'] as String?) ?? 'normal',
      combatInfo: (data['combat_info'] as String?) ?? '',
      skills: ((data['skills'] as List?) ?? [])
          .map((s) => Skill.fromJson(s as Map<String, dynamic>))
          .toList(),
      atPlotPoint: data['at_plot_point'] == true,
      plotPoint: data['plot_point'] != null
          ? PlotPointLive.fromJson(data['plot_point'] as Map<String, dynamic>)
          : null,
    );
  }

  // Lấy danh sách lượt chơi của tôi
  Future<List<PlaySessionSummary>> listMySessions() async {
    final res = await _dio.get('/play');
    final data = _ok(res);
    final list = (data['sessions'] as List?) ?? [];
    return list
        .map((e) => PlaySessionSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Đọc lại toàn bộ chương của một lượt chơi (để chơi tiếp)
  Future<({List<Chapter> chapters, List<Skill> skills})> getPlaythrough(
      String sessionId) async {
    final res = await _dio.get('/play/$sessionId');
    final data = _ok(res);
    final list = (data['chapters'] as List?) ?? [];
    final chapters =
        list.map((e) => Chapter.fromJson(e as Map<String, dynamic>)).toList();
    final skills = ((data['skills'] as List?) ?? [])
        .map((s) => Skill.fromJson(s as Map<String, dynamic>))
        .toList();
    return (chapters: chapters, skills: skills);
  }

  // Xóa các lượt chơi của scenario này
  Future<void> deleteByStory(String storyId) async {
    final res = await _dio.delete('/play/by-story/$storyId');
    _ok(res);
  }
}