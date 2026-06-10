import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

// Màn hình nhập mã OTP 6 số. Nhận email để biết xác minh cho ai.
class OtpScreen extends ConsumerStatefulWidget {
  final String email;
  const OtpScreen({super.key, required this.email});
  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpCtrl = TextEditingController();
  bool _resending = false;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // Xác minh thành công -> về đầu, AuthGate tự chuyển sang Home
    ref.listen(authNotifierProvider, (prev, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${next.error}'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
      if (next.hasValue && next.value != null) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Xác minh email')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mark_email_unread, size: 64, color: Colors.indigo),
            const SizedBox(height: 16),
            Text(
              'Mã xác minh đã được gửi tới\n${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _otpCtrl,
              decoration: const InputDecoration(
                labelText: 'Nhập mã 6 số',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: authState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: () {
                        ref.read(authNotifierProvider.notifier).verifyEmail(
                              widget.email,
                              _otpCtrl.text.trim(),
                            );
                      },
                      child: const Text('Xác minh'),
                    ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _resending
                  ? null
                  : () async {
                      setState(() => _resending = true);
                      try {
                        await ref
                            .read(authNotifierProvider.notifier)
                            .resendOtp(widget.email);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã gửi lại mã')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      } finally {
                        if (context.mounted) setState(() => _resending = false);
                      }
                    },
              child: const Text('Gửi lại mã'),
            ),
          ],
        ),
      ),
    );
  }
}
