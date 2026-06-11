import 'package:dio/dio.dart';
import '../models/auth_user.dart';

// Kết quả đăng ký: chưa có token, chỉ báo đã gửi OTP
class RegisterResult {
  final AuthUser user;
  final String message;
  final bool requireVerification;
  RegisterResult(this.user, this.message, {this.requireVerification = true});
}

class AuthService {
  final Dio _dio;
  AuthService(this._dio);

  Map<String, dynamic> _ok(Response res) {
    final status = res.statusCode ?? 0;
    if (status >= 200 && status < 300) {
      return res.data as Map<String, dynamic>;
    }
    final data = res.data;
    final msg = (data is Map && data['error'] != null)
        ? data['error'].toString()
        : 'Có lỗi xảy ra (mã $status)';
    // Ném kèm status để UI phân biệt (vd 403 = chưa xác minh)
    final field = (data is Map && data['field'] != null)
        ? data['field'].toString()
        : null;
    throw AuthException(msg, status, field: field);
  }

  // Đăng ký -> backend gửi OTP, KHÔNG trả token
  Future<RegisterResult> register(
      String email, String username, String password) async {
    final res = await _dio.post('/auth/register', data: {
      'email': email,
      'username': username,
      'password': password,
    });
    final data = _ok(res);
    return RegisterResult(
      AuthUser.fromJson(data['user']),
      (data['message'] ?? 'Đã gửi mã xác minh') as String,
      requireVerification: (data['requireVerification'] ?? true) as bool,
    );
  }

  // Xác minh OTP -> trả token
  Future<({AuthUser user, String access, String refresh})> verifyEmail(
      String email, String otp) async {
    final res = await _dio.post('/auth/verify-email', data: {
      'email': email,
      'otp': otp,
    });
    final data = _ok(res);
    return (
      user: AuthUser.fromJson(data['user']),
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
    );
  }

  Future<void> resendOtp(String email) async {
    final res = await _dio.post('/auth/resend-otp', data: {'email': email});
    _ok(res);
  }

  Future<({AuthUser user, String access, String refresh})> login(
      String email, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = _ok(res);
    return (
      user: AuthUser.fromJson(data['user']),
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
    );
  }

  Future<AuthUser> fetchMe(String accessToken) async {
    final res = await _dio.get('/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}));
    final data = _ok(res);
    return AuthUser.fromJson(data['user']);
  }

  // Làm mới access token bằng refresh token
  Future<({String access, String refresh})> refresh(
      String refreshToken) async {
    final res = await _dio.post('/auth/refresh', data: {
      'refresh_token': refreshToken,
    });
    final data = _ok(res);
    return (
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
    );
  }

  // Gửi yêu cầu quên mật khẩu (server gửi OTP reset qua email)
  Future<String> forgotPassword(String email) async {
    final res = await _dio.post('/auth/forgot-password', data: {'email': email});
    final data = _ok(res);
    return (data['message'] ?? 'Đã gửi mã') as String;
  }

  // Đặt lại mật khẩu bằng OTP
  Future<String> resetPassword(
      String email, String otp, String newPassword) async {
    final res = await _dio.post('/auth/reset-password', data: {
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
    });
    final data = _ok(res);
    return (data['message'] ?? 'Thành công') as String;
  }
}



// Lỗi auth có kèm mã HTTP để UI xử lý khác nhau
class AuthException implements Exception {
  final String message;
  final int statusCode;
  final String? field; // 'email' | 'username' -> để hiện lỗi đúng ô
  AuthException(this.message, this.statusCode, {this.field});
  @override
  String toString() => message;
}
