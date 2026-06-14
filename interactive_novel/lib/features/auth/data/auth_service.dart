import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/auth_user.dart';

// Kết quả đăng ký
class RegisterResult {
  final AuthUser user;
  final String message;
  final bool requireVerification;
  RegisterResult(this.user, this.message, {this.requireVerification = true});
}

// Kết quả login: thành công hoặc cần 2FA
sealed class LoginResult {}

class LoginSuccess extends LoginResult {
  final AuthUser user;
  final String access;
  final String refresh;
  LoginSuccess({required this.user, required this.access, required this.refresh});
}

class LoginRequires2FA extends LoginResult {
  final AuthUser user;
  final String tempToken;
  LoginRequires2FA({required this.user, required this.tempToken});
}

// Lỗi auth có kèm mã HTTP
class AuthException implements Exception {
  final String message;
  final int statusCode;
  final String? field;
  AuthException(this.message, this.statusCode, {this.field});
  @override
  String toString() => message;
}

final _googleSignIn = GoogleSignIn(
  // serverClientId là Web OAuth Client ID từ Google Cloud Console
  // Phải khớp với GOOGLE_CLIENT_ID ở backend
  serverClientId: '690559386948-6nj5k1lbmun8t736hc2cu5ipr1h32mtt.apps.googleusercontent.com',
);

class AuthService {
  final Dio _dio;
  AuthService(this._dio);

  Map<String, dynamic> _ok(Response res) {
    final status = res.statusCode ?? 0;
    if (status >= 200 && status < 300) return res.data as Map<String, dynamic>;
    final data = res.data;
    final msg = (data is Map && data['error'] != null)
        ? data['error'].toString()
        : 'Có lỗi xảy ra (mã $status)';
    final field = (data is Map && data['field'] != null)
        ? data['field'].toString()
        : null;
    throw AuthException(msg, status, field: field);
  }

  Future<RegisterResult> register(String email, String username, String password) async {
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

  Future<({AuthUser user, String access, String refresh})> verifyEmail(
      String email, String otp) async {
    final res = await _dio.post('/auth/verify-email', data: {'email': email, 'otp': otp});
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

  Future<LoginResult> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = _ok(res);
    if (data['requires_2fa'] == true) {
      return LoginRequires2FA(
        user: AuthUser.fromJson(data['user']),
        tempToken: data['temp_token'] as String,
      );
    }
    return LoginSuccess(
      user: AuthUser.fromJson(data['user']),
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
    );
  }

  Future<LoginResult> loginWithGoogle() async {
    // Đăng xuất phiên Google cũ để luôn hiện picker chọn tài khoản
    await _googleSignIn.signOut();
    final account = await _googleSignIn.signIn();
    if (account == null) throw AuthException('Đã hủy đăng nhập Google', 0);

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) throw AuthException('Không lấy được idToken từ Google', 0);

    final res = await _dio.post('/auth/google', data: {'idToken': idToken});
    final data = _ok(res);

    if (data['requires_2fa'] == true) {
      return LoginRequires2FA(
        user: AuthUser.fromJson(data['user']),
        tempToken: data['temp_token'] as String,
      );
    }
    return LoginSuccess(
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

  Future<({String access, String refresh})> refresh(String refreshToken) async {
    final res = await _dio.post('/auth/refresh', data: {'refresh_token': refreshToken});
    final data = _ok(res);
    return (
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
    );
  }

  Future<String> forgotPassword(String email) async {
    final res = await _dio.post('/auth/forgot-password', data: {'email': email});
    final data = _ok(res);
    return (data['message'] ?? 'Đã gửi mã') as String;
  }

  Future<String> resetPassword(String email, String otp, String newPassword) async {
    final res = await _dio.post('/auth/reset-password', data: {
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
    });
    final data = _ok(res);
    return (data['message'] ?? 'Thành công') as String;
  }

  // ── TOTP 2FA ──────────────────────────────────────────────────────────────

  Future<({String otpauthUrl, String secret})> setup2fa() async {
    final res = await _dio.post('/auth/2fa/setup');
    final data = _ok(res);
    return (
      otpauthUrl: data['otpauthUrl'] as String,
      secret: data['secret'] as String,
    );
  }

  Future<void> verifySetup2fa(String code) async {
    final res = await _dio.post('/auth/2fa/verify-setup', data: {'code': code});
    _ok(res);
  }

  Future<({AuthUser user, String access, String refresh})> verify2fa(
      String tempToken, String code) async {
    final res = await _dio.post('/auth/2fa/verify', data: {
      'tempToken': tempToken,
      'code': code,
    });
    final data = _ok(res);
    return (
      user: AuthUser.fromJson(data['user']),
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
    );
  }

  Future<void> disable2fa(String code) async {
    final res = await _dio.post('/auth/2fa/disable', data: {'code': code});
    _ok(res);
  }
}
