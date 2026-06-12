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
    setState(() {
      _emailError = null;
      _userError = null;
      _passError = null;
    });

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
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => OtpScreen(email: email),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng ký thành công! Hãy đăng nhập.')),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      setState(() {
        if (e is AuthException && e.field == 'email') {
          _emailError = e.message;
        } else if (e is AuthException && e.field == 'username') {
          _userError = e.message;
        } else {
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.person_add_alt_1,
                    size: 36, color: theme.colorScheme.onPrimary),
              ),
            ),
            const SizedBox(height: 20),
            Text('Tạo tài khoản',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Bắt đầu hành trình sáng tạo của bạn',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textTheme.bodySmall?.color)),
            const SizedBox(height: 32),
            TextField(
              controller: _emailCtrl,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_outlined),
                errorText: _emailError,
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _userCtrl,
              decoration: InputDecoration(
                labelText: 'Tên đăng nhập',
                prefixIcon: const Icon(Icons.person_outline),
                errorText: _userError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              decoration: InputDecoration(
                labelText: 'Mật khẩu (tối thiểu 6 ký tự)',
                prefixIcon: const Icon(Icons.lock_outline),
                errorText: _passError,
              ),
              obscureText: true,
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: _submitting
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Đăng ký'),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Đã có tài khoản?',
                    style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đăng nhập'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}