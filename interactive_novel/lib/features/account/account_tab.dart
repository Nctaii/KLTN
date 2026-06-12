import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_config.dart';
import '../auth/providers/auth_provider.dart';
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
          // Nhóm cài đặt
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
          _menuTile(
            theme,
            icon: Icons.logout,
            title: 'Đăng xuất',
            danger: true,
            onTap: () =>
                ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
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