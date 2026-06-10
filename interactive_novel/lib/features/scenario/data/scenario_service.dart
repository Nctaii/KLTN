import 'package:dio/dio.dart';
import '../models/scenario.dart';

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
}