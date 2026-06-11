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

    final avatarUrl = user?.avatarUrl;
    final fullAvatarUrl = (avatarUrl != null && avatarUrl.isNotEmpty)
        ? '${ApiConfig.baseUrl}$avatarUrl'
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          // Avatar + tên
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundImage:
                  fullAvatarUrl != null ? NetworkImage(fullAvatarUrl) : null,
              child: fullAvatarUrl == null
                  ? const Icon(Icons.person, size: 48)
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              user?.displayName ?? user?.username ?? '...',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Text(
              user?.email ?? '',
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Chỉnh sửa hồ sơ'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const EditProfileScreen(),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Đổi giao diện'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ThemeScreen(),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Đăng xuất'),
            onTap: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}