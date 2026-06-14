import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interactive_novel/features/auth/screens/forgot_password_screen.dart';
import '../data/auth_service.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';
import 'otp_screen.dart';
import 'totp_verify_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  String? _emailError;
  String? _passError;
  String? _generalError;
  bool _loading = false;
  bool _googleLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[\w.\-]+@[\w\-]+\.[\w\-.]+$');
    return regex.hasMatch(email);
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    setState(() {
      _emailError = null;
      _passError = null;
      _generalError = null;
    });

    bool hasError = false;
    if (email.isEmpty) {
      _emailError = 'Hãy điền email';
      hasError = true;
    } else if (!_isValidEmail(email)) {
      _emailError = 'Email không đúng định dạng';
      hasError = true;
    }
    if (pass.isEmpty) {
      _passError = 'Hãy nhập mật khẩu';
      hasError = true;
    }
    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _loading = true);
    try {
      final pending = await ref
          .read(authNotifierProvider.notifier)
          .login(email, pass);

      if (!mounted) return;
      if (pending != null) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TotpVerifyScreen(
            tempToken: pending.tempToken,
            user: pending.user,
          ),
        ));
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tài khoản chưa xác minh, mời nhập mã')),
        );
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OtpScreen(email: email),
        ));
      } else if (e.statusCode == 401) {
        setState(() => _generalError = 'Email hoặc mật khẩu chưa đúng');
      } else {
        setState(() => _generalError = 'Lỗi: ${e.message}');
      }
    } catch (e) {
      if (mounted) setState(() => _generalError = 'Lỗi kết nối: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _generalError = null;
    });
    try {
      final pending = await ref
          .read(authNotifierProvider.notifier)
          .loginWithGoogle();

      if (pending != null && mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TotpVerifyScreen(
            tempToken: pending.tempToken,
            user: pending.user,
          ),
        ));
      }
    } on AuthException catch (e) {
      if (e.statusCode != 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      // statusCode == 0 nghĩa là user tự hủy → không cần thông báo
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi Google đăng nhập: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authNotifierProvider); // watch để rebuild khi login thành công
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          children: [
            const SizedBox(height: 60),
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.auto_stories,
                    size: 44, color: theme.colorScheme.onPrimary),
              ),
            ),
            const SizedBox(height: 24),
            Text('Chào mừng trở lại',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Đăng nhập để tiếp tục cuộc phiêu lưu',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textTheme.bodySmall?.color)),
            const SizedBox(height: 36),
            TextField(
              controller: _emailCtrl,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_outlined),
                errorText: _emailError,
              ),
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) {
                if (_emailError != null) setState(() => _emailError = null);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                prefixIcon: const Icon(Icons.lock_outline),
                errorText: _passError,
              ),
              obscureText: true,
              onChanged: (_) {
                if (_passError != null) setState(() => _passError = null);
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ForgotPasswordScreen(),
                )),
                child: const Text('Quên mật khẩu?'),
              ),
            ),
            if (_generalError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 18, color: Colors.red.shade400),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_generalError!,
                            style: TextStyle(
                                color: Colors.red.shade400,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Đăng nhập'),
                    ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Divider(color: theme.dividerColor)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('hoặc',
                      style: TextStyle(
                          color: theme.textTheme.bodySmall?.color, fontSize: 13)),
                ),
                Expanded(child: Divider(color: theme.dividerColor)),
              ],
            ),
            const SizedBox(height: 20),
            // Nút đăng nhập Google
            SizedBox(
              height: 52,
              child: _googleLoading
                  ? const Center(child: CircularProgressIndicator())
                  : OutlinedButton.icon(
                      onPressed: _loginWithGoogle,
                      icon: Image.network(
                        'https://www.google.com/favicon.ico',
                        width: 20,
                        height: 20,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.g_mobiledata, size: 22),
                      ),
                      label: const Text('Đăng nhập với Google'),
                    ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Chưa có tài khoản?',
                    style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RegisterScreen(),
                  )),
                  child: const Text('Đăng ký ngay'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
