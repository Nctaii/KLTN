import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_config.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/totp_setup_screen.dart';
import '../theme/theme_screen.dart';
import 'screens/edit_profile_screen.dart';

class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull;
    final theme = Theme.of(context);

    final avatarUrl = user?.avatarUrl;
    final fullAvatarUrl = (avatarUrl != null && avatarUrl.isNotEmpty)
        ? ApiConfig.imageUrl(avatarUrl)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          // Thẻ hồ sơ với gradient
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.25),
                  theme.colorScheme.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: theme.colorScheme.primary, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.2),
                    backgroundImage: fullAvatarUrl != null
                        ? NetworkImage(fullAvatarUrl)
                        : null,
                    child: fullAvatarUrl == null
                        ? Icon(Icons.person,
                            size: 46, color: theme.colorScheme.primary)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.displayName ?? user?.username ?? '...',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: TextStyle(color: theme.textTheme.bodySmall?.color),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _menuTile(
            theme,
            icon: Icons.edit_outlined,
            title: 'Chỉnh sửa hồ sơ',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const EditProfileScreen(),
            )),
          ),
          const SizedBox(height: 10),
          _menuTile(
            theme,
            icon: Icons.palette_outlined,
            title: 'Đổi giao diện',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ThemeScreen(),
            )),
          ),
          const SizedBox(height: 10),
          // Tile 2FA: hiện trạng thái bật/tắt và điều hướng setup
          _twoFaTile(context, ref, theme, user?.totpEnabled ?? false),
          const SizedBox(height: 10),
          _menuTile(
            theme,
            icon: Icons.logout,
            title: 'Đăng xuất',
            danger: true,
            onTap: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }

  Widget _twoFaTile(
      BuildContext context, WidgetRef ref, ThemeData theme, bool totpEnabled) {
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _handle2FaTap(context, ref, totpEnabled),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.security,
                    size: 20, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Xác thực 2 bước (2FA)',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      totpEnabled ? 'Đang bật' : 'Chưa bật',
                      style: TextStyle(
                        fontSize: 12,
                        color: totpEnabled
                            ? Colors.green.shade600
                            : theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              if (totpEnabled)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('BẬT',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade600)),
                )
              else
                Icon(Icons.chevron_right,
                    color: theme.textTheme.bodySmall?.color),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handle2FaTap(
      BuildContext context, WidgetRef ref, bool totpEnabled) async {
    if (totpEnabled) {
      // 2FA đang bật → hỏi xem có muốn tắt không
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tắt xác thực 2 bước?'),
          content: const Text(
              'Nhập mã từ Google Authenticator để xác nhận tắt 2FA.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Huỷ')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Tiếp tục')),
          ],
        ),
      );
      if (confirm == true && context.mounted) {
        _showDisable2FADialog(context, ref);
      }
    } else {
      // 2FA chưa bật → đi tới màn hình setup
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const TotpSetupScreen(),
      ));
    }
  }

  void _showDisable2FADialog(BuildContext context, WidgetRef ref) {
    final codeCtrl = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nhập mã xác thực'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: InputDecoration(
                  labelText: 'Mã 6 chữ số',
                  errorText: error,
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Huỷ')),
            TextButton(
              onPressed: () async {
                final code = codeCtrl.text.trim();
                if (code.length != 6) {
                  setState(() => error = 'Mã gồm 6 chữ số');
                  return;
                }
                try {
                  await ref.read(authServiceProvider).disable2fa(code);
                  await ref.read(authNotifierProvider.notifier).reloadUser();
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Đã tắt 2FA')),
                    );
                  }
                } catch (e) {
                  setState(() => error = e.toString());
                }
              },
              child: const Text('Xác nhận tắt'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? Colors.red.shade400 : theme.colorScheme.primary;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: danger ? Colors.red.shade400 : null,
                    )),
              ),
              if (!danger)
                Icon(Icons.chevron_right,
                    color: theme.textTheme.bodySmall?.color),
            ],
          ),
        ),
      ),
    );
  }
}
