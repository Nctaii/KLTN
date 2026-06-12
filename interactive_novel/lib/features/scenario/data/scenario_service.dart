import 'package:dio/dio.dart';
import '../models/scenario.dart';
import '../models/interaction.dart';

class ScenarioService {
  final Dio _dio;
  ScenarioService(this._dio);

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

  // Tạo scenario mới -> trả về id
  Future<String> create(ScenarioInput input) async {
    final res = await _dio.post('/scenarios', data: input.toJson());
    final data = _ok(res);
    return data['scenario']['id'].toString();
  }

  // Lấy danh sách scenario đã publish
  Future<List<ScenarioSummary>> listPublished() async {
    final res = await _dio.get('/scenarios');
    final data = _ok(res);
    final list = (data['scenarios'] as List?) ?? [];
    return list
        .map((e) => ScenarioSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Publish một scenario
  Future<void> publish(String storyId) async {
    final res = await _dio.post('/scenarios/$storyId/publish');
    _ok(res);
  }

  // Lấy scenario do chính user tạo
  Future<List<ScenarioSummary>> listMine() async {
    final res = await _dio.get('/scenarios/mine');
    final data = _ok(res);
    final list = (data['scenarios'] as List?) ?? [];
    return list
        .map((e) => ScenarioSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Lấy thông tin like (số like + mình đã like chưa)
  Future<LikeInfo> getLikeInfo(String storyId) async {
    final res = await _dio.get('/scenarios/$storyId/like');
    final data = _ok(res);
    return LikeInfo.fromJson(data);
  }

  // Bật/tắt like, trả về trạng thái mới
  Future<LikeInfo> toggleLike(String storyId) async {
    final res = await _dio.post('/scenarios/$storyId/like');
    final data = _ok(res);
    return LikeInfo(
      likeCount: (data['likeCount'] ?? 0) as int,
      likedByMe: (data['liked'] ?? false) as bool,
    );
  }

  // Danh sách comment
  Future<List<ScenarioComment>> listComments(String storyId) async {
    final res = await _dio.get('/scenarios/$storyId/comments');
    final data = _ok(res);
    final list = (data['comments'] as List?) ?? [];
    return list
        .map((e) => ScenarioComment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Thêm comment
  Future<void> addComment(String storyId, String content) async {
    final res = await _dio.post('/scenarios/$storyId/comments',
        data: {'content': content});
    _ok(res);
  }

  // Upload ảnh bìa cho scenario
  Future<void> uploadCover(String storyId, String filePath) async {
    final formData = FormData.fromMap({
      'cover': await MultipartFile.fromFile(filePath),
    });
    final res = await _dio.post('/scenarios/$storyId/cover', data: formData);
    _ok(res);
  }

  // Sửa tên/mô tả scenario
  Future<void> updateInfo(String storyId,
      {String? title, String? description}) async {
    final res = await _dio.patch('/scenarios/$storyId', data: {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
    });
    _ok(res);
  }

  // Xóa scenario của mình
  Future<void> deleteScenario(String storyId) async {
    final res = await _dio.delete('/scenarios/$storyId');
    _ok(res);
  }

  Future<Map<String, dynamic>> getScenarioFull(String storyId) async {
    final res = await _dio.get('/scenarios/$storyId');
    final data = _ok(res);
    // backend trả { scenario: {...} }
    return (data['scenario'] ?? data) as Map<String, dynamic>;
  }
}