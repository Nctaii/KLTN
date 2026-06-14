import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_service.dart';
import '../models/auth_user.dart';
import '../providers/auth_provider.dart';

// Màn hình nhập TOTP khi login — xuất hiện sau khi xác thực email/password thành công
// nhưng tài khoản đang bật 2FA
class TotpVerifyScreen extends ConsumerStatefulWidget {
  final String tempToken;
  final AuthUser user;

  const TotpVerifyScreen({
    super.key,
    required this.tempToken,
    required this.user,
  });

  @override
  ConsumerState<TotpVerifyScreen> createState() => _TotpVerifyScreenState();
}

class _TotpVerifyScreenState extends ConsumerState<TotpVerifyScreen> {
  final _codeCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Mã gồm 6 chữ số');
      return;
    }
    setState(() => _error = null);

    await ref
        .read(authNotifierProvider.notifier)
        .completeLogin2FA(widget.tempToken, code);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);

    // Khi login 2FA thành công, authState.valueOrNull != null → điều hướng về home
    // được xử lý bởi router ở màn hình cha, không cần push ở đây

    ref.listen(authNotifierProvider, (_, next) {
      if (next.hasError) {
        final err = next.error;
        setState(() {
          _error = err is AuthException ? err.message : err.toString();
        });
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Xác thực 2 bước')),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.security,
                size: 48,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Xác thực 2 bước',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhập mã 6 chữ số từ ứng dụng\nGoogle Authenticator',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textTheme.bodySmall?.color),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _codeCtrl,
              decoration: InputDecoration(
                labelText: 'Mã xác thực',
                prefixIcon: const Icon(Icons.pin_outlined),
                errorText: _error,
                counterText: '',
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: authState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Xác nhận'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
