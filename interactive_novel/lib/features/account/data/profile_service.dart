import 'package:dio/dio.dart';
import '../../auth/models/auth_user.dart';

class ProfileService {
  final Dio _dio;
  ProfileService(this._dio);

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

  Future<AuthUser> getProfile() async {
    final res = await _dio.get('/users/me');
    final data = _ok(res);
    return AuthUser.fromJson(data['profile']);
  }

  Future<AuthUser> updateProfile({String? displayName}) async {
    final res = await _dio.patch('/users/me', data: {
      if (displayName != null) 'display_name': displayName,
    });
    final data = _ok(res);
    return AuthUser.fromJson(data['profile']);
  }

  // Upload avatar từ đường dẫn file trên máy
  Future<AuthUser> uploadAvatar(String filePath) async {
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(filePath),
    });
    final res = await _dio.post('/users/me/avatar', data: formData);
    final data = _ok(res);
    return AuthUser.fromJson(data['profile']);
  }
}