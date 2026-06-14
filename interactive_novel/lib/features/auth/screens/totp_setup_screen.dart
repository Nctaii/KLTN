import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/auth_provider.dart';

class TotpSetupScreen extends ConsumerStatefulWidget {
  const TotpSetupScreen({super.key});

  @override
  ConsumerState<TotpSetupScreen> createState() => _TotpSetupScreenState();
}

class _TotpSetupScreenState extends ConsumerState<TotpSetupScreen> {
  final _codeCtrl = TextEditingController();

  String? _otpauthUrl;
  String? _secret;
  bool _loading = true;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQr();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQr() async {
    try {
      final result = await ref.read(authServiceProvider).setup2fa();
      setState(() {
        _otpauthUrl = result.otpauthUrl;
        _secret = result.secret;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Mã gồm 6 chữ số');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).verifySetup2fa(code);
      await ref.read(authNotifierProvider.notifier).reloadUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bật 2FA thành công!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt xác thực 2 bước')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Hiện lỗi load QR rõ ràng thay vì ẩn trong TextField
                if (_otpauthUrl == null && _error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.error_outline,
                              color: Colors.red.shade400, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: TextStyle(color: Colors.red.shade400)),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _loading = true;
                                _error = null;
                              });
                              _loadQr();
                            },
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Thử lại'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Bước 1: Quét mã QR',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mở Google Authenticator (hoặc Authy) và quét mã QR bên dưới.',
                ),
                const SizedBox(height: 20),
                if (_otpauthUrl != null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: _otpauthUrl!,
                        version: QrVersions.auto,
                        size: 200,
                      ),
                    ),
                  ),
                if (_secret != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Hoặc nhập thủ công:',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      _secret!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Text(
                  'Bước 2: Nhập mã xác nhận',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Nhập mã 6 chữ số từ ứng dụng để xác nhận cài đặt.'),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Mã xác thực',
                    prefixIcon: const Icon(Icons.security),
                    // chỉ hiện lỗi verify, không hiện lỗi load QR ở đây
                    errorText: _otpauthUrl != null ? _error : null,
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: _verifying
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _verify,
                          child: const Text('Xác nhận & Bật 2FA'),
                        ),
                ),
              ],
            ),
    );
  }
}
