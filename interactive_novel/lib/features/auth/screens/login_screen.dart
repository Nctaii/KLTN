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

  // Lỗi
  String? _emailError;
  String? _passError;
  String? _generalError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // Kiểm tra định dạng email cơ bản
  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[\w.\-]+@[\w\-]+\.[\w\-.]+$');
    return regex.hasMatch(email);
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    // Xóa lỗi cũ, kiểm tra phía client
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

    // Gọi đăng nhập
    await ref.read(authNotifierProvider.notifier).login(email, pass);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // Lắng nghe kết quả đăng nhập để xử lý lỗi từ server
    ref.listen(authNotifierProvider, (prev, next) {
      if (next.hasError && !next.isLoading) {
        final err = next.error;
        // 403 = tài khoản chưa xác minh -> sang màn OTP
        if (err is AuthException && err.statusCode == 403) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tài khoản chưa xác minh, mời nhập mã')),
          );
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => OtpScreen(email: _emailCtrl.text.trim()),
          ));
        } else if (err is AuthException && err.statusCode == 401) {
          // Sai email hoặc mật khẩu -> hiện dòng lỗi chung ở giữa
          setState(() => _generalError = 'Email hoặc mật khẩu chưa đúng');
        } else {
          // Lỗi khác (mạng, server)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đăng nhập thất bại: $err')),
          );
        }
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          TextField(
            controller: _emailCtrl,
            decoration: InputDecoration(
              labelText: 'Email',
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
              errorText: _passError,
            ),
            obscureText: true,
            onChanged: (_) {
              if (_passError != null) setState(() => _passError = null);
            },
          ),
          const SizedBox(height: 16),
          if (_generalError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _generalError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          SizedBox(
            height: 48,
            child: authState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Đăng nhập'),
                  ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const RegisterScreen(),
              ));
            },
            child: const Text('Chưa có tài khoản? Đăng ký'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ForgotPasswordScreen(),
              ));
            },
            child: const Text('Quên mật khẩu?'),
          ),
        ],
      ),
    );
  }
}