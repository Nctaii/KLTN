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

  // Bắt đầu chơi -> trả về (sessionId, chương 1)
  Future<({String sessionId, Chapter chapter})> start(
      String storyId, String? mcName) async {
    final res = await _dio.post('/play/start', data: {
      'story_id': storyId,
      if (mcName != null && mcName.isNotEmpty) 'mc_name': mcName,
    });
    final data = _ok(res);
    return (
      sessionId: data['session_id'].toString(),
      chapter: Chapter.fromJson(data['chapter']),
    );
  }

  // Chơi tiếp: chọn option hoặc tự viết hướng đi -> trả chương mới
  Future<Chapter> continuePlay(
      String sessionId, {String? optionId, String? customDirection}) async {
    final res = await _dio.post('/play/$sessionId/continue', data: {
      if (optionId != null) 'option_id': optionId,
      if (customDirection != null) 'custom_direction': customDirection,
    });
    final data = _ok(res);
    return Chapter.fromJson(data['chapter']);
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
  Future<List<Chapter>> getPlaythrough(String sessionId) async {
    final res = await _dio.get('/play/$sessionId');
    final data = _ok(res);
    final list = (data['chapters'] as List?) ?? [];
    return list
        .map((e) => Chapter.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}