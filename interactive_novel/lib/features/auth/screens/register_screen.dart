import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_service.dart';
import '../providers/auth_provider.dart';
import 'otp_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _submitting = false;

  // Lỗi riêng cho từng ô
  String? _emailError;
  String? _userError;
  String? _passError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    print('>>> ĐÃ BẤM ĐĂNG KÝ, chuẩn bị gọi API');
    // Xóa lỗi cũ
    setState(() {
      _emailError = null;
      _userError = null;
      _passError = null;
    });

    // Kiểm tra cơ bản phía client trước khi gọi server
    final email = _emailCtrl.text.trim();
    final username = _userCtrl.text.trim();
    final pass = _passCtrl.text;
    bool hasError = false;
    if (email.isEmpty) {
      _emailError = 'Vui lòng nhập email';
      hasError = true;
    }
    if (username.isEmpty) {
      _userError = 'Vui lòng nhập tên đăng nhập';
      hasError = true;
    }
    if (pass.length < 6) {
      _passError = 'Mật khẩu tối thiểu 6 ký tự';
      hasError = true;
    }
    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(authNotifierProvider.notifier)
          .register(email, username, pass);
      if (mounted) {
        if (result.requireVerification) {
          // Còn yêu cầu xác minh -> sang màn OTP
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => OtpScreen(email: email),
          ));
        } else {
          // Không cần xác minh -> báo thành công, quay về đăng nhập
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng ký thành công! Hãy đăng nhập.')),
          );
          Navigator.of(context).pop(); // về màn đăng nhập
        }
      }
    } catch (e) {
      // Đặt lỗi vào đúng ô dựa trên field backend trả về
      setState(() {
        if (e is AuthException && e.field == 'email') {
          _emailError = e.message;
        } else if (e is AuthException && e.field == 'username') {
          _userError = e.message;
        } else {
          // Lỗi không rõ trường -> hiện chung
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đăng ký thất bại: $e')),
          );
        }
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          TextField(
            controller: _emailCtrl,
            decoration: InputDecoration(
              labelText: 'Email (phải có thật để nhận mã)',
              errorText: _emailError, // lỗi hiện ngay dưới ô email
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _userCtrl,
            decoration: InputDecoration(
              labelText: 'Tên đăng nhập',
              errorText: _userError,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passCtrl,
            decoration: InputDecoration(
              labelText: 'Mật khẩu (tối thiểu 6 ký tự)',
              errorText: _passError,
            ),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: _submitting
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Đăng ký'),
                  ),
          ),
        ],
      ),
    );
  }
}