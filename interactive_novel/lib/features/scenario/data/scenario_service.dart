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

  // Nhờ AI gợi ý các lựa chọn cho một nút thắt (trợ lý sáng tác)
  // Trả về list PlotChoice
  // Nhờ AI sinh cả một bộ nút thắt (count nút) cho kịch bản
  Future<List<PlotPoint>> suggestPlotPoints({
    required int count,
    String? title,
    Map<String, dynamic>? world,
    Map<String, dynamic>? xh,
    Map<String, dynamic>? fnt,
    List<int>? genreIds,
  }) async {
    final res = await _dio.post('/scenarios/suggest-plot-points', data: {
      'count': count,
      if (title != null) 'title': title,
      if (world != null) 'world': world,
      if (xh != null) 'xh': xh,
      if (fnt != null) 'fnt': fnt,
      if (genreIds != null) 'genre_ids': genreIds,
    });
    final data = _ok(res);
    final list = (data['plot_points'] as List?) ?? [];
    return list.map((pp) {
      final choices = ((pp['choices'] as List?) ?? [])
          .map((c) => PlotChoice(
                label: (c['label'] ?? '').toString(),
                branchHint: c['branch_hint'] as String?,
              ))
          .toList();
      return PlotPoint(
        title: (pp['title'] ?? '').toString(),
        description: (pp['description'] ?? '').toString(),
        choices: choices,
      );
    }).toList();
  }

  Future<List<PlotChoice>> suggestPlotChoices({
    required String plotTitle,
    String? plotDescription,
    Map<String, dynamic>? world,
    Map<String, dynamic>? xh,
    Map<String, dynamic>? fnt,
    List<int>? genreIds,
  }) async {
    final res = await _dio.post('/scenarios/suggest-plot-choices', data: {
      'plot_title': plotTitle,
      if (plotDescription != null) 'plot_description': plotDescription,
      if (world != null) 'world': world,
      if (xh != null) 'xh': xh,
      if (fnt != null) 'fnt': fnt,
      if (genreIds != null) 'genre_ids': genreIds,
    });
    final data = _ok(res);
    final list = (data['choices'] as List?) ?? [];
    return list
        .map((c) => PlotChoice(
              label: (c['label'] ?? '').toString(),
              branchHint: c['branch_hint'] as String?,
            ))
        .toList();
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

  // Cập nhật toàn bộ cấu hình scenario (đồng bộ thêm/sửa/xóa, giữ id)
  Future<void> updateFull(String storyId, Map<String, dynamic> body) async {
    final res = await _dio.put('/scenarios/$storyId/full', data: body);
    _ok(res);
  }
}