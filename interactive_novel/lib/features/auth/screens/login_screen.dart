import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interactive_novel/features/auth/screens/forgot_password_screen.dart';
import '../data/auth_service.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';
import 'otp_screen.dart';

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

    await ref.read(authNotifierProvider.notifier).login(email, pass);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);

    ref.listen(authNotifierProvider, (prev, next) {
      if (next.hasError && !next.isLoading) {
        final err = next.error;
        if (err is AuthException && err.statusCode == 403) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tài khoản chưa xác minh, mời nhập mã')),
          );
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => OtpScreen(email: _emailCtrl.text.trim()),
          ));
        } else if (err is AuthException && err.statusCode == 401) {
          setState(() => _generalError = 'Email hoặc mật khẩu chưa đúng');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đăng nhập thất bại: $err')),
          );
        }
      }
    });

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          children: [
            const SizedBox(height: 60),
            // Logo / biểu tượng thương hiệu
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
            // Quên mật khẩu căn phải
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ForgotPasswordScreen(),
                  ));
                },
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
                      Icon(Icons.error_outline,
                          size: 18, color: Colors.red.shade400),
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
              child: authState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Đăng nhập'),
                    ),
            ),
            const SizedBox(height: 20),
            // Dòng phân cách
            Row(
              children: [
                Expanded(child: Divider(color: theme.dividerColor)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('hoặc',
                      style: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                          fontSize: 13)),
                ),
                Expanded(child: Divider(color: theme.dividerColor)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Chưa có tài khoản?',
                    style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const RegisterScreen(),
                    ));
                  },
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