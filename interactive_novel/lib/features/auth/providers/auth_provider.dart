import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/api_config.dart';
import '../data/auth_service.dart';
import '../data/token_storage.dart';
import '../models/auth_user.dart';

part 'auth_provider.g.dart';

@riverpod
Dio dio(Ref ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 60),
    validateStatus: (s) => s != null && s < 500,
  ));

  dio.interceptors.add(InterceptorsWrapper(
    // Gắn access token vào mọi request
    onRequest: (options, handler) async {
      final token = await ref.read(tokenStorageProvider).getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },

    // Khi gặp 401 (token hết hạn) -> thử refresh rồi gửi lại request
    onResponse: (response, handler) async {
      final isUnauthorized = response.statusCode == 401;
      final isAuthCall =
          response.requestOptions.path.startsWith('/auth/');

      // Chỉ refresh khi: bị 401 VÀ không phải đang gọi chính API auth
      if (isUnauthorized && !isAuthCall) {
        final storage = ref.read(tokenStorageProvider);
        final refreshToken = await storage.getRefreshToken();

        if (refreshToken != null) {
          try {
            // Dùng một Dio "sạch" (không interceptor) để gọi refresh,
            // tránh vòng lặp vô hạn nếu refresh cũng lỗi
            final plainDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
            final r = await plainDio.post('/auth/refresh',
                data: {'refresh_token': refreshToken});
            final newAccess = r.data['access_token'] as String;
            final newRefresh = r.data['refresh_token'] as String;
            await storage.saveTokens(newAccess, newRefresh);

            // Gửi lại request cũ với token mới
            final opts = response.requestOptions;
            opts.headers['Authorization'] = 'Bearer $newAccess';
            final retry = await dio.fetch(opts);
            return handler.resolve(retry);
          } catch (_) {
            // Refresh thất bại (refresh token cũng hết hạn) -> xóa token
            await storage.clear();
          }
        }
      }
      handler.next(response);
    },
  ));

  return dio;
}

@riverpod
TokenStorage tokenStorage(Ref ref) => TokenStorage();

@riverpod
AuthService authService(Ref ref) => AuthService(ref.watch(dioProvider));

// Notifier giữ trạng thái phiên đăng nhập: AsyncValue<AuthUser?>
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<AuthUser?> build() async {
    final storage = ref.read(tokenStorageProvider);
    final token = await storage.getAccessToken();
    if (token == null) return null;
    try {
      return await ref.read(authServiceProvider).fetchMe(token);
    } catch (_) {
      await storage.clear();
      return null;
    }
  }

  // Đăng ký: KHÔNG đăng nhập ngay (chờ xác minh OTP).
  // Trả về message để màn hình hiển thị; ném lỗi nếu thất bại.
  Future<String> register(
      String email, String username, String password) async {
    final result =
        await ref.read(authServiceProvider).register(email, username, password);
    return result.message;
  }

  // Xác minh OTP -> đăng nhập luôn (cập nhật state thành user)
  Future<void> verifyEmail(String email, String otp) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final r = await ref.read(authServiceProvider).verifyEmail(email, otp);
      await ref.read(tokenStorageProvider).saveTokens(r.access, r.refresh);
      return r.user;
    });
  }

  Future<void> resendOtp(String email) async {
    await ref.read(authServiceProvider).resendOtp(email);
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final r = await ref.read(authServiceProvider).login(email, password);
      await ref.read(tokenStorageProvider).saveTokens(r.access, r.refresh);
      return await ref.read(authServiceProvider).fetchMe(r.access);
    });
  }

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AsyncData(null);
  }

  Future<String> forgotPassword(String email) async {
    return ref.read(authServiceProvider).forgotPassword(email);
  }

  Future<String> resetPassword(
      String email, String otp, String newPassword) async {
    return ref.read(authServiceProvider).resetPassword(email, otp, newPassword);
  }
}
