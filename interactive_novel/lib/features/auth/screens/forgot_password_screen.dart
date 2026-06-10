import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _otpSent = false; // đã gửi mã chưa -> chuyển sang bước 2
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // Bước 1: gửi mã
  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Hãy nhập email');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).forgotPassword(email);
      setState(() {
        _otpSent = true;
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi mã tới email (kiểm tra cả Spam)')),
        );
      }
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  // Bước 2: đặt lại mật khẩu
  Future<void> _reset() async {
    final email = _emailCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    final pass = _passCtrl.text;
    if (otp.isEmpty) {
      setState(() => _error = 'Hãy nhập mã OTP');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Mật khẩu mới tối thiểu 6 ký tự');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .resetPassword(email, otp, pass);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đặt lại mật khẩu thành công!')),
        );
        Navigator.of(context).pop(); // quay về màn đăng nhập
      }
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          // Ô email: chỉ sửa được ở bước 1
          TextField(
            controller: _emailCtrl,
            enabled: !_otpSent,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          // Bước 2: hiện ô OTP và mật khẩu mới
          if (_otpSent) ...[
            TextField(
              controller: _otpCtrl,
              decoration: const InputDecoration(
                labelText: 'Mã OTP (6 số)',
                counterText: '',
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
          ],

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade400),
              ),
            ),

          SizedBox(
            height: 48,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _otpSent ? _reset : _sendCode,
                    child: Text(_otpSent ? 'Đặt lại mật khẩu' : 'Gửi mã'),
                  ),
          ),

          if (_otpSent)
            TextButton(
              onPressed: _loading ? null : _sendCode,
              child: const Text('Gửi lại mã'),
            ),
        ],
      ),
    );
  }
}