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
    onRequest: (options, handler) async {
      final token = await ref.read(tokenStorageProvider).getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },

    onResponse: (response, handler) async {
      final isUnauthorized = response.statusCode == 401;
      final isAuthCall = response.requestOptions.path.startsWith('/auth/');

      if (isUnauthorized && !isAuthCall) {
        final storage = ref.read(tokenStorageProvider);
        final refreshToken = await storage.getRefreshToken();

        if (refreshToken != null) {
          try {
            final plainDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
            final r = await plainDio.post('/auth/refresh',
                data: {'refresh_token': refreshToken});
            final newAccess = r.data['access_token'] as String;
            final newRefresh = r.data['refresh_token'] as String;
            await storage.saveTokens(newAccess, newRefresh);

            final opts = response.requestOptions;
            opts.headers['Authorization'] = 'Bearer $newAccess';
            final retry = await dio.fetch(opts);
            return handler.resolve(retry);
          } catch (_) {
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

  Future<RegisterResult> register(String email, String username, String password) async {
    return ref.read(authServiceProvider).register(email, username, password);
  }

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

  // Trả về LoginRequires2FA nếu 2FA bật, null nếu login thành công, throw nếu lỗi
  Future<LoginRequires2FA?> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final result = await ref.read(authServiceProvider).login(email, password);
      if (result is LoginRequires2FA) {
        state = const AsyncData(null); // chưa đăng nhập, chờ 2FA
        return result;
      }
      final s = result as LoginSuccess;
      await ref.read(tokenStorageProvider).saveTokens(s.access, s.refresh);
      state = AsyncData(await ref.read(authServiceProvider).fetchMe(s.access));
      return null;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  // Google OAuth — cùng pattern với login()
  Future<LoginRequires2FA?> loginWithGoogle() async {
    state = const AsyncLoading();
    try {
      final result = await ref.read(authServiceProvider).loginWithGoogle();
      if (result is LoginRequires2FA) {
        state = const AsyncData(null);
        return result;
      }
      final s = result as LoginSuccess;
      await ref.read(tokenStorageProvider).saveTokens(s.access, s.refresh);
      state = AsyncData(await ref.read(authServiceProvider).fetchMe(s.access));
      return null;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  // Hoàn thành login bước 2 (TOTP)
  Future<void> completeLogin2FA(String tempToken, String code) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final r = await ref.read(authServiceProvider).verify2fa(tempToken, code);
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

  Future<String> resetPassword(String email, String otp, String newPassword) async {
    return ref.read(authServiceProvider).resetPassword(email, otp, newPassword);
  }

  // Sau khi bật/tắt 2FA, reload user để cập nhật totpEnabled
  Future<void> reloadUser() async {
    final storage = ref.read(tokenStorageProvider);
    final token = await storage.getAccessToken();
    if (token == null) return;
    state = AsyncData(await ref.read(authServiceProvider).fetchMe(token));
  }
}
